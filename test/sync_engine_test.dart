import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wispie/data/migrations.dart';
import 'package:wispie/services/sync/api_client.dart';
import 'package:wispie/services/sync/changeset.dart';
import 'package:wispie/services/sync/crypto.dart';
import 'package:wispie/services/sync/hlc.dart';
import 'package:wispie/services/sync/sync_engine.dart';

const _acct = '00112233445566778899aabbccddeeff';

/// In-memory single-account implementation of the sync endpoints of API v1.
class FakeSyncServer {
  late HttpServer http;
  String get url => 'http://127.0.0.1:${http.port}';
  int epoch = 0;
  final deltas = <int, Uint8List>{};
  int head = 0;
  Uint8List? snapshot;
  int snapshotBase = 0;
  final uploads = <String, BytesBuilder>{};
  final uploadKinds = <String, String>{};
  bool goneOnce = false;
  Future<void> Function()? beforeNextPush;

  Future<void> start() async {
    http = await HttpServer.bind('127.0.0.1', 0);
    http.listen((r) async {
      try {
        await _handle(r);
      } catch (e) {
        r.response.statusCode = 500;
        r.response.write('$e');
        await r.response.close();
      }
    });
  }

  Future<void> stop() => http.close(force: true);

  Future<void> _json(HttpRequest r, int s, Object b) async {
    r.response
      ..statusCode = s
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(b));
    await r.response.close();
  }

  Future<void> _err(HttpRequest r, int s, String c,
          [Map<String, dynamic>? x]) =>
      _json(r, s, {'error': c, 'message': c, ...?x});

  Map<String, dynamic> _state() => {
        'epoch': epoch,
        'head_seq': head,
        'snapshot': snapshot == null
            ? null
            : {
                'id': 's$epoch-$snapshotBase',
                'base_seq': snapshotBase,
                'size': snapshot!.length
              },
        'deltas_since_snapshot': head - snapshotBase,
        'bytes_since_snapshot': 0,
        'compaction_recommended': false,
        'usage_bytes': 0,
        'quota_bytes': 1 << 30,
      };

  Future<void> _handle(HttpRequest r) async {
    final path = r.uri.path.replaceFirst('/v1', '');
    final body = BytesBuilder();
    await for (final c in r) {
      body.add(c);
    }
    final bytes = body.takeBytes();
    Map<String, dynamic> j() => bytes.isEmpty
        ? {}
        : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

    if (path == '/sync/state') return _json(r, 200, _state());
    if (path == '/sync/deltas' && r.method == 'GET') {
      if (goneOnce) {
        goneOnce = false;
        return _err(r, 410, 'gone');
      }
      final after = int.parse(r.uri.queryParameters['after']!);
      final out = BytesBuilder();
      for (final e in deltas.entries.where((e) => e.key > after)) {
        final h = ByteData(12)
          ..setUint64(0, e.key)
          ..setUint32(8, e.value.length);
        out
          ..add(h.buffer.asUint8List())
          ..add(e.value);
      }
      r.response.headers
        ..set('X-Wispie-Head', '$head')
        ..set('X-Wispie-More', '0');
      r.response.add(out.takeBytes());
      return r.response.close();
    }
    if (path == '/sync/deltas' && r.method == 'POST') {
      final hook = beforeNextPush;
      if (hook != null) {
        beforeNextPush = null;
        await hook();
      }
      if (int.parse(r.headers.value('x-wispie-epoch')!) != epoch) {
        return _err(r, 412, 'epoch_changed', {'epoch': epoch});
      }
      if (int.parse(r.headers.value('x-wispie-expect-head')!) != head) {
        return _err(r, 409, 'head_moved', {'head': head});
      }
      head++;
      deltas[head] = bytes;
      return _json(r, 200, {'seq': head});
    }
    if (path == '/sync/snapshot') {
      r.response.headers
        ..set('X-Wispie-Snapshot-Id', 's$epoch-$snapshotBase')
        ..set('X-Wispie-Base-Seq', '$snapshotBase')
        ..set('X-Wispie-Epoch', '$epoch');
      r.response.add(snapshot!);
      return r.response.close();
    }
    if (path == '/sync/uploads' && r.method == 'POST') {
      final id = 'u${uploads.length}';
      uploads[id] = BytesBuilder();
      uploadKinds[id] = j()['kind'] as String;
      return _json(r, 200, {'upload_id': id, 'chunk_bytes': 1 << 20});
    }
    if (path.startsWith('/sync/uploads/')) {
      final id = path.split('/')[3];
      final u = uploads[id]!;
      if (path.endsWith('/commit')) {
        snapshot = u.takeBytes();
        if (uploadKinds[id] == 'reset') {
          epoch++;
          deltas.clear();
          head = 0;
          snapshotBase = 0;
        }
        return _json(r, 200, _state());
      }
      u.add(bytes);
      return _json(r, 200, {'received': u.length});
    }
    return _err(r, 404, 'not_found');
  }
}

class _MemSettings implements SettingsAccess {
  final Map<String, Object?> values = {};
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object value) async => values[key] = value;
}

class _Dev {
  final Database stats, user;
  final _MemSettings settings;
  final MemorySyncKv kv;
  final SyncEngine engine;
  _Dev(this.stats, this.user, this.settings, this.kv, this.engine);

  Future<void> fav(String f, {int? hlc}) => user.insert(
      'favorite',
      {
        'filename': f,
        'added_at': 1.0,
        'hlc': hlc ?? Hlc.instance.now(),
        'dirty': 1
      },
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<String>> favs() async =>
      (await user.query('favorite', orderBy: 'filename'))
          .map((r) => r['filename'] as String)
          .toList();
}

void main() {
  late FakeSyncServer server;
  late Directory tmp;
  late Uint8List dataKey;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Hlc.instance.resetForTest();
    server = FakeSyncServer();
    await server.start();
    tmp = await Directory.systemTemp.createTemp('wispie_engine');
    dataKey = await SyncCrypto.dataKey(SyncCrypto.randomBytes(32));
  });
  tearDown(() async {
    await server.stop();
    await tmp.delete(recursive: true);
  });

  Future<_Dev> device(String id) async {
    final stats = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    final user = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await createStatsSchema(stats);
    await createUserDataSchema(user);
    final s = _MemSettings();
    final kv = MemorySyncKv();
    final engine = SyncEngine(
      client: SyncApiClient(
          baseUrl: server.url, tokens: const SyncTokens('a', 'r')),
      dataKey: dataKey,
      accountId: _acct,
      changeset:
          Changeset(stats: stats, userData: user, deviceId: id, settings: s),
      kv: kv,
      tmpDir: Directory('${tmp.path}/$id'),
      stampSetting: (key) async => user.insert('sync_setting_meta',
          {'key': key, 'hlc': Hlc.instance.now(), 'dirty': 1},
          conflictAlgorithm: ConflictAlgorithm.replace),
    );
    return _Dev(stats, user, s, kv, engine);
  }

  test('sync before initial upload is refused', () async {
    final a = await device('a');
    expect(a.engine.sync(), throwsA(isA<SyncNotReadyException>()));
  });

  test('two devices converge', () async {
    final a = await device('a');
    await a.fav('one.mp3');
    await a.settings.write('theme_mode', 'dark');
    await a.engine.overwriteCloud();
    expect(server.epoch, 1);

    final b = await device('b');
    await b.engine.setUpAsNewDevice();
    expect(await b.favs(), ['one.mp3']);
    expect(b.settings.values['theme_mode'], 'dark');
    expect(await b.user.query('favorite', where: 'dirty = 1'), isEmpty);

    await b.fav('two.mp3');
    await b.engine.sync();
    await a.engine.sync();
    expect(await a.favs(), ['one.mp3', 'two.mp3']);

    // No echo: nothing left to push, no new deltas.
    final head = server.head;
    await a.engine.sync();
    await b.engine.sync();
    expect(server.head, head);

    // Local settings edits are detected without a hook.
    b.settings.values['theme_mode'] = 'light';
    await b.engine.sync();
    await a.engine.sync();
    expect(a.settings.values['theme_mode'], 'light');
  });

  test('head_moved triggers pull and retry', () async {
    final a = await device('a');
    await a.fav('a.mp3');
    await a.engine.overwriteCloud();
    final b = await device('b');
    await b.engine.setUpAsNewDevice();

    await a.fav('a2.mp3');
    await b.fav('b.mp3');
    server.beforeNextPush = () => a.engine.sync();
    await b.engine.sync();
    expect(await b.favs(), ['a.mp3', 'a2.mp3', 'b.mp3']);
    await a.engine.sync();
    expect(await a.favs(), ['a.mp3', 'a2.mp3', 'b.mp3']);
  });

  test('410 falls back to the snapshot', () async {
    final a = await device('a');
    await a.fav('a.mp3');
    await a.engine.overwriteCloud();
    final b = await device('b');
    await b.engine.setUpAsNewDevice();
    await a.fav('late.mp3');
    await a.engine.sync();
    server.goneOnce = true;
    await b.engine.sync();
    expect(await b.favs(), contains('a.mp3'));
    expect(await b.favs(), contains('late.mp3'));
  });

  test('device behind a newer snapshot downloads it', () async {
    final a = await device('a');
    await a.fav('a.mp3');
    await a.engine.overwriteCloud();
    final b = await device('b');
    await b.engine.setUpAsNewDevice();
    await a.fav('x.mp3');
    await a.engine.sync();
    final snap = await a.engine.changeset.buildSnapshot();
    server.snapshot = await a.engine.testEncodeSnapshot(snap);
    server.snapshotBase = server.head;
    await b.engine.sync();
    expect(await b.favs(), ['a.mp3', 'x.mp3']);
    expect(b.kv.get(SyncEngine.kCursor), server.head);
  });

  test('epoch change pauses until resolved', () async {
    final a = await device('a');
    await a.fav('a.mp3');
    await a.engine.overwriteCloud();
    final b = await device('b');
    await b.engine.setUpAsNewDevice();

    await a.fav('only_a.mp3');
    await a.engine.overwriteCloud();
    expect(server.epoch, 2);

    await expectLater(
        b.engine.sync(), throwsA(isA<SyncEpochChangedException>()));
    expect(b.engine.pausedForEpoch, 2);
    await expectLater(
        b.engine.sync(), throwsA(isA<SyncEpochChangedException>()));

    await b.fav('b_extra.mp3');
    await b.engine.mergeWithCloud();
    expect(b.engine.pausedForEpoch, isNull);
    await a.engine.sync();
    expect(await a.favs(), ['a.mp3', 'b_extra.mp3', 'only_a.mp3']);
  });

  test('rollback of server state is detected', () async {
    final a = await device('a');
    await a.fav('a.mp3');
    await a.engine.overwriteCloud();
    await a.fav('b.mp3');
    await a.engine.sync();
    expect(server.head, 1);
    server.deltas.clear();
    server.head = 0;
    await a.fav('c.mp3');
    // Engine state says head 1 was seen; server now reports 0.
    await expectLater(a.engine.sync(), throwsA(isA<SyncRollbackException>()));
  });

  test('push clears only rows whose hlc did not change meanwhile', () async {
    final a = await device('a');
    await a.engine.overwriteCloud();
    await a.fav('x.mp3');
    await a.fav('y.mp3');
    server.beforeNextPush = () async {
      await a.fav('x.mp3');
    };
    await a.engine.sync();
    final dirty = await a.user.query('favorite', where: 'dirty = 1');
    expect(dirty.map((r) => r['filename']), ['x.mp3']);
  });

  test('category switched on gets one full pull', () async {
    final a = await device('a');
    await a.fav('a.mp3');
    await a.engine.overwriteCloud();
    final b = await device('b');
    var cats = SyncCategory.all.toSet()..remove(SyncCategory.favorites);
    final b2 = SyncEngine(
      client: b.engine.client,
      dataKey: dataKey,
      accountId: _acct,
      changeset: b.engine.changeset,
      kv: b.kv,
      tmpDir: b.engine.tmpDir,
      stampSetting: b.engine.stampSetting,
      categories: () => cats,
    );
    await b2.setUpAsNewDevice();
    expect(await b.favs(), isEmpty);
    cats = SyncCategory.all.toSet();
    await b2.queueCategoryPull({SyncCategory.favorites});
    await b2.sync();
    expect(await b.favs(), ['a.mp3']);
  });
}
