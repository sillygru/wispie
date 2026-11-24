import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'wispie_core.dart';

/// SQLite, through the native core.
///
/// This is the seam the app's database code is written against: the same
/// executor surface sqflite offered (`query`, `insert`, `transaction`, `batch`,
/// ...), with the engine and the schema now living in `rust/wispie_core/src/db.rs`.
/// Bundled SQLite in the core means one engine on all six platforms instead of
/// a platform plugin plus an ffi fallback.

/// How a constraint violation is handled, matching sqflite's enum.
enum ConflictAlgorithm { rollback, abort, fail, ignore, replace }

/// Which database file is being opened, so the core knows which schema to
/// create or upgrade. A plain [openDatabase] leaves it null.
enum DatabaseSchema { stats, userData }

const Map<DatabaseSchema, String> _schemaNames = {
  DatabaseSchema.stats: 'stats',
  DatabaseSchema.userData: 'userdata',
};

/// A statement or open that the engine rejected.
class DatabaseException implements Exception {
  DatabaseException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseException: $message';
}

/// The statement surface shared by [Database] and [Transaction].
abstract class DatabaseExecutor {
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  });

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]);

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  });

  Future<int> rawInsert(String sql, [List<Object?>? arguments]);

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  });

  Future<int> rawUpdate(String sql, [List<Object?>? arguments]);

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<int> rawDelete(String sql, [List<Object?>? arguments]);

  Future<void> execute(String sql, [List<Object?>? arguments]);

  Batch batch();

  /// Recomputes the deterministic ids for play events that lack one.
  Future<void> backfillPlayEventUids();
}

/// An open database file.
class Database implements DatabaseExecutor {
  Database._(this.path, this._id);

  /// Path of the file this connection has open.
  final String path;

  final int _id;
  bool _closed = false;
  final Object _transactionZoneKey = Object();

  /// Serializes statements the way sqflite did: one at a time, in call order.
  Future<void> _tail = Future.value();

  /// Opens [path], creating or upgrading the schema when [schema] is given.
  static Future<Database> open(
    String path, {
    DatabaseSchema? schema,
    int? hlc,
    bool readOnly = false,
  }) async {
    final reply = await _call({
      'action': 'open',
      'path': path,
      if (schema != null) 'schema': _schemaNames[schema],
      if (hlc != null) 'hlc': hlc,
      if (readOnly) 'read_only': true,
    });
    return Database._(path, (reply['id'] as num).toInt());
  }

  bool get isOpen => !_closed;

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return previous.then((_) => action()).whenComplete(gate.complete);
  }

  /// Runs one core request without touching the queue. Only callers already
  /// holding the queue (a transaction body) use this.
  Future<Map<String, Object?>> _dispatch(Map<String, Object?> request) {
    if (_closed) throw StateError('database $path is closed');
    return _call({...request, 'id': _id});
  }

  void _checkTransactionScope() {
    if (Zone.current[_transactionZoneKey] == true) {
      throw DatabaseException(
          'database $path is in a transaction; pass the transaction handle');
    }
  }

  Future<T> _run<T>(Map<String, Object?> request) {
    _checkTransactionScope();
    return _serialized(() async => await _dispatch(request) as T);
  }

  /// Holds the connection queue until the body commits or rolls back.
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) {
    _checkTransactionScope();
    return _serialized(() async {
      await _dispatch({'action': 'begin'});
      final txn = Transaction._(this);
      try {
        final result = await runZoned(
          () => action(txn),
          zoneValues: {_transactionZoneKey: true},
        );
        txn._active = false;
        await _dispatch({'action': 'commit'});
        return result;
      } catch (_) {
        txn._active = false;
        try {
          await _dispatch({'action': 'rollback'});
        } catch (_) {
          // Preserve the original failure.
        }
        rethrow;
      }
    });
  }

  /// Runs one core command against this connection, in the same statement
  /// queue, so a command that owns a compound write cannot interleave with a
  /// statement from another caller.
  Future<Map<String, Object?>> coreCommand(
    String action,
    Map<String, Object?> fields,
  ) {
    _checkTransactionScope();
    return _serialized(
        () async => await _dispatch({'action': action, ...fields}));
  }

  Future<void> close() async {
    _checkTransactionScope();
    await _serialized(() async {
      if (_closed) return;
      await _dispatch({'action': 'close'});
      _closed = true;
    });
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      rawQuery(
        _selectSql(
          table,
          distinct: distinct ?? false,
          columns: columns,
          where: where,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        ),
        whereArgs,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final reply = await _run({
      'action': 'query',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    final rows = reply['rows'] as List<Object?>? ?? const [];
    return [
      for (final row in rows) _decodeRow(row as Map<String, Object?>),
    ];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      rawInsert(_insertSql(table, values, nullColumnHack, conflictAlgorithm),
          values.values.toList());

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final reply = await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    final changes = (reply['changes'] as num?)?.toInt() ?? 0;
    return changes == 0 ? 0 : (reply['id'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      rawUpdate(
        _updateSql(table, values, where, conflictAlgorithm),
        [...values.values, ...?whereArgs],
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final reply = await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    return (reply['changes'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) =>
      rawDelete(_deleteSql(table, where), whereArgs);

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final reply = await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    return (reply['changes'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
  }

  @override
  Batch batch() => Batch._(this);

  @override
  Future<void> backfillPlayEventUids() async {
    await _run({'action': 'backfill_uids'});
  }

  Future<List<Object?>> _commitBatch(Batch batch) async {
    final request = {
      'action': 'batch',
      'ops': batch._operations,
      'noResult': !batch._wantsResults,
      'continueOnError': batch._continueOnError,
    };
    final transaction = batch._transaction;
    final reply = transaction == null
        ? await _run<Map<String, Object?>>(request)
        : await transaction._dispatch(request);
    final error = reply['error'] as String?;
    if (error != null && !batch._continueOnError) throw StateError(error);
    final results = reply['results'] as List<Object?>? ?? const [];
    return [for (final result in results) _batchResult(result)];
  }
}

/// Statements that run as one transaction when committed.
class Batch {
  Batch._(this._database, {Transaction? transaction})
      : _transaction = transaction;

  final Transaction? _transaction;

  final Database _database;
  final List<Map<String, Object?>> _operations = [];
  bool _wantsResults = true;
  bool _continueOnError = false;

  int get length => _operations.length;

  void _add(String sql, [List<Object?>? arguments]) {
    _operations.add({
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
  }

  void rawInsert(String sql, [List<Object?>? arguments]) =>
      _add(sql, arguments);

  void rawUpdate(String sql, [List<Object?>? arguments]) =>
      _add(sql, arguments);

  void rawDelete(String sql, [List<Object?>? arguments]) =>
      _add(sql, arguments);

  void execute(String sql, [List<Object?>? arguments]) => _add(sql, arguments);

  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _add(
        _insertSql(table, values, nullColumnHack, conflictAlgorithm),
        values.values.toList(),
      );

  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _add(
        _updateSql(table, values, where, conflictAlgorithm),
        [...values.values, ...?whereArgs],
      );

  void delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _add(_deleteSql(table, where), whereArgs);

  Future<List<Object?>> commit({
    bool? noResult,
    bool continueOnError = false,
  }) {
    _wantsResults = !(noResult ?? false);
    _continueOnError = continueOnError;
    return _database._commitBatch(this);
  }
}

/// A statement scope inside a transaction. Shares the connection, so it never
/// queues behind the transaction that owns it.
class Transaction implements DatabaseExecutor {
  Transaction._(this._database);

  final Database _database;

  bool _active = true;

  Future<Map<String, Object?>> _dispatch(Map<String, Object?> request) {
    if (!_active) throw DatabaseException('transaction has finished');
    return _database._dispatch(request);
  }

  Future<T> _run<T>(Map<String, Object?> request) async =>
      await _dispatch(request) as T;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      rawQuery(
        _selectSql(
          table,
          distinct: distinct ?? false,
          columns: columns,
          where: where,
          groupBy: groupBy,
          having: having,
          orderBy: orderBy,
          limit: limit,
          offset: offset,
        ),
        whereArgs,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final reply = await _run({
      'action': 'query',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    final rows = reply['rows'] as List<Object?>? ?? const [];
    return [
      for (final row in rows) _decodeRow(row as Map<String, Object?>),
    ];
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      rawInsert(_insertSql(table, values, nullColumnHack, conflictAlgorithm),
          values.values.toList());

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final reply = await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    final changes = (reply['changes'] as num?)?.toInt() ?? 0;
    return changes == 0 ? 0 : (reply['id'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      rawUpdate(
        _updateSql(table, values, where, conflictAlgorithm),
        [...values.values, ...?whereArgs],
      );

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final reply = await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    return (reply['changes'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) =>
      rawDelete(_deleteSql(table, where), whereArgs);

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final reply = await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
    return (reply['changes'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _run({
      'action': 'execute',
      'sql': sql,
      'args': [
        for (final arg in arguments ?? const <Object?>[]) _encodeArg(arg)
      ]
    });
  }

  @override
  Batch batch() => Batch._(_database, transaction: this);

  @override
  Future<void> backfillPlayEventUids() async {
    await _run({'action': 'backfill_uids'});
  }
}

/// Opens [path] through the core.
///
/// [schema] is what asks for creation or an upgrade; a database opened without
/// one (an integrity check, a backup read) is opened as it stands. [readOnly]
/// opens without read-write access, for looking at a file the app must not
/// touch. Every call opens its own connection, so [singleInstance] is accepted
/// for call-site compatibility but changes nothing.
Future<Database> openDatabase(
  String path, {
  DatabaseSchema? schema,
  int? hlc,
  bool readOnly = false,
  bool singleInstance = true,
}) =>
    Database.open(path, schema: schema, hlc: hlc, readOnly: readOnly);

/// The first column of the first row as an int, or null when there is no row.
int? firstIntValue(List<Map<String, Object?>> rows) {
  if (rows.isEmpty) return null;
  return (rows.first.values.first as num?)?.toInt();
}

// Keep FFI and JSON work off Flutter's isolate without spawning per statement.
final Future<SendPort> _databaseWorker = _startDatabaseWorker();

Future<SendPort> _startDatabaseWorker() async {
  final ready = ReceivePort();
  try {
    await Isolate.spawn(_serveDatabaseRequests, ready.sendPort,
        debugName: 'wispie-sqlite');
    return await ready.first as SendPort;
  } finally {
    ready.close();
  }
}

void _serveDatabaseRequests(SendPort ready) {
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  requests.listen((message) {
    final (request, reply) = message as (Map<String, Object?>, SendPort);
    try {
      reply.send((_callCore(request), null));
    } catch (error, stack) {
      reply.send((
        null,
        (
          error is DatabaseException
              ? error
              : DatabaseException(error.toString()),
          stack
        )
      ));
    }
  });
}

Future<Map<String, Object?>> _call(Map<String, Object?> request) async {
  final worker = await _databaseWorker;
  final response = ReceivePort();
  try {
    worker.send((request, response.sendPort));
    final (reply, failure) = await response.first as (
      Map<String, Object?>?,
      (DatabaseException, StackTrace)?
    );
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
    return reply!;
  } finally {
    response.close();
  }
}

Map<String, Object?> _callCore(Map<String, Object?> request) {
  Map<String, Object?>? reply;
  String? error;
  final code = WispieCore.run(
    {'command': 'db', ...request},
    onEvent: (kind, payload) {
      if (kind == WispieCore.eventError) {
        error =
            (jsonDecode(payload) as Map<String, dynamic>)['message'] as String?;
      } else if (kind == WispieCore.eventItems) {
        // A one-shot command's reply arrives as the items event.
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, Object?>) reply = decoded;
      }
    },
  );
  if (code != 0 || reply == null) {
    throw DatabaseException(error ?? 'database request failed ($code)');
  }
  return reply!;
}

String _selectSql(
  String table, {
  required bool distinct,
  List<String>? columns,
  String? where,
  String? groupBy,
  String? having,
  String? orderBy,
  int? limit,
  int? offset,
}) {
  final buffer = StringBuffer('SELECT ');
  if (distinct) buffer.write('DISTINCT ');
  buffer.write(columns == null || columns.isEmpty ? '*' : columns.join(', '));
  buffer
    ..write(' FROM ')
    ..write(table);
  if (where != null && where.isNotEmpty) {
    buffer
      ..write(' WHERE ')
      ..write(where);
  }
  if (groupBy != null && groupBy.isNotEmpty) {
    buffer
      ..write(' GROUP BY ')
      ..write(groupBy);
  }
  if (having != null && having.isNotEmpty) {
    buffer
      ..write(' HAVING ')
      ..write(having);
  }
  if (orderBy != null && orderBy.isNotEmpty) {
    buffer
      ..write(' ORDER BY ')
      ..write(orderBy);
  }
  if (limit != null) {
    buffer
      ..write(' LIMIT ')
      ..write(limit);
    if (offset != null) {
      buffer
        ..write(' OFFSET ')
        ..write(offset);
    }
  }
  return buffer.toString();
}

String _insertSql(
  String table,
  Map<String, Object?> values,
  String? nullColumnHack,
  ConflictAlgorithm? conflictAlgorithm,
) {
  final verb = switch (conflictAlgorithm) {
    ConflictAlgorithm.replace => 'INSERT OR REPLACE',
    ConflictAlgorithm.ignore => 'INSERT OR IGNORE',
    ConflictAlgorithm.abort => 'INSERT OR ABORT',
    ConflictAlgorithm.fail => 'INSERT OR FAIL',
    ConflictAlgorithm.rollback => 'INSERT OR ROLLBACK',
    null => 'INSERT',
  };
  if (values.isEmpty) {
    return '$verb INTO $table (${nullColumnHack ?? 'rowid'}) VALUES (NULL)';
  }
  final columns = values.keys.join(', ');
  final placeholders = List.filled(values.length, '?').join(', ');
  return '$verb INTO $table ($columns) VALUES ($placeholders)';
}

String _updateSql(
  String table,
  Map<String, Object?> values,
  String? where,
  ConflictAlgorithm? conflictAlgorithm,
) {
  final verb = switch (conflictAlgorithm) {
    ConflictAlgorithm.replace => 'UPDATE OR REPLACE',
    ConflictAlgorithm.ignore => 'UPDATE OR IGNORE',
    ConflictAlgorithm.abort => 'UPDATE OR ABORT',
    ConflictAlgorithm.fail => 'UPDATE OR FAIL',
    ConflictAlgorithm.rollback => 'UPDATE OR ROLLBACK',
    null => 'UPDATE',
  };
  final assignments = values.keys.map((column) => '$column = ?').join(', ');
  final buffer = StringBuffer('$verb $table SET $assignments');
  if (where != null && where.isNotEmpty) {
    buffer
      ..write(' WHERE ')
      ..write(where);
  }
  return buffer.toString();
}

String _deleteSql(String table, String? where) {
  final buffer = StringBuffer('DELETE FROM $table');
  if (where != null && where.isNotEmpty) {
    buffer
      ..write(' WHERE ')
      ..write(where);
  }
  return buffer.toString();
}

/// Values the core cannot take as plain JSON: bytes and dates.
Object? _encodeArg(Object? value) {
  if (value is Uint8List) return {r'$blob': base64Encode(value)};
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is bool) return value ? 1 : 0;
  return value;
}

Map<String, Object?> _decodeRow(Map<String, Object?> row) {
  for (final entry in row.entries) {
    final value = entry.value;
    if (value is Map && value.length == 1 && value.containsKey(r'$blob')) {
      row[entry.key] = base64Decode(value[r'$blob'] as String);
    }
  }
  return row;
}

Object? _batchResult(Object? result) {
  if (result is Map) {
    final changes = (result['changes'] as num?)?.toInt() ?? 0;
    if (changes == 0) return 0;
    return (result['id'] as num?)?.toInt() ?? 0;
  }
  return result;
}
