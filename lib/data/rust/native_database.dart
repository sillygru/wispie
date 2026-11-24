import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'wispie_core.dart';

/// Which database file is being opened, so the core knows which schema to
/// create or upgrade. A plain [openDatabase] leaves it null.
enum DatabaseSchema { stats, userData, searchIndex }

const Map<DatabaseSchema, String> _schemaNames = {
  DatabaseSchema.stats: 'stats',
  DatabaseSchema.userData: 'userdata',
  DatabaseSchema.searchIndex: 'search_index',
};

/// A statement or open that the engine rejected.
class DatabaseException implements Exception {
  DatabaseException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseException: $message';
}

/// An open database file.
class Database {
  Database._(this.path, this._id);

  /// Path of the file this connection has open.
  final String path;

  final int _id;
  bool _closed = false;

  /// Keeps commands and close in call order for each connection.
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

  Future<Map<String, Object?>> _dispatch(Map<String, Object?> request) {
    if (_closed) throw StateError('database $path is closed');
    return _call({...request, 'id': _id});
  }

  /// Runs one core command against this connection, in the same statement
  /// queue, so a command that owns a compound write cannot interleave with a
  /// statement from another caller.
  Future<Map<String, Object?>> coreCommand(
    String action,
    Map<String, Object?> fields,
  ) {
    return _serialized(
        () async => await _dispatch({'action': action, ...fields}));
  }

  Future<void> close() async {
    await _serialized(() async {
      if (_closed) return;
      await _dispatch({'action': 'close'});
      _closed = true;
    });
  }
}

/// Opens [path] through the core.
///
/// [schema] is what asks for creation or an upgrade; a database opened without
/// one (an integrity check, a backup read) is opened as it stands. [readOnly]
/// opens without read-write access, for looking at a file the app must not
/// touch. Every call opens its own connection.
Future<Database> openDatabase(
  String path, {
  DatabaseSchema? schema,
  int? hlc,
  bool readOnly = false,
}) =>
    Database.open(path, schema: schema, hlc: hlc, readOnly: readOnly);

Future<Map<String, Object?>> databaseFileCommand(
  String op,
  String path, {
  String? destination,
}) =>
    _call({
      'action': 'file',
      'op': op,
      'path': path,
      if (destination != null) 'destination': destination,
    });

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
