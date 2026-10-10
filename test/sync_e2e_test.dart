// Runs against a real server: `server/scripts/e2e.sh` or set WISPIE_E2E_URL.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wispie/data/migrations.dart';
import 'package:wispie/services/sync/account_service.dart';
import 'package:wispie/services/sync/api_client.dart';
import 'package:wispie/services/sync/changeset.dart';
import 'package:wispie/services/sync/crypto.dart';
import 'package:wispie/services/sync/hlc.dart';
import 'package:wispie/services/sync/sync_engine.dart';

final _url = Platform.environment['WISPIE_E2E_URL'];

class _Settings implements SettingsAccess {
  final values = <String, Object?>{};
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object value) async => values[key] = value;
}

class _Dev {
  _Dev(this.account, this.user, this.engine);
  final AccountService account;
  final Database user;
  final SyncEngine engine;

  Future<void> fav(String f) => user.insert('favorite',
      {'filename': f, 'added_at': 1.0, 'hlc': Hlc.instance.now(), 'dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<String>> favs() async =>
      (await user.query('favorite', orderBy: 'filename'))
          .map((r) => r['filename'] as String)
          .toList();
}

void main() {
  setUpAll(() => sqfliteFfiInit());

  late Directory tmp;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Hlc.instance.resetForTest();
    tmp = await Directory.systemTemp.createTemp('wispie_e2e');
  });
  tearDown(() => tmp.delete(recursive: true));

  // Small Argon2 keeps the run fast; the server accepts m >= 32 MiB.
  const kdf = KdfParams(memoryKib: 32 * 1024, iterations: 2);

  Future<_Dev> device(String id, AccountService acct) async {
    final stats = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    final user = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await createStatsSchema(stats);
    await createUserDataSchema(user);
    final session = acct.session!;
    final engine = SyncEngine(
      client: acct.client,
      dataKey: await acct.dataKey(),
      accountId: session.accountId,
      changeset: Changeset(
          stats: stats, userData: user, deviceId: id, settings: _Settings()),
      kv: MemorySyncKv(),
      tmpDir: Directory('${tmp.path}/$id'),
      stampSetting: (key) async => user.insert('sync_setting_meta',
          {'key': key, 'hlc': Hlc.instance.now(), 'dirty': 1},
          conflictAlgorithm: ConflictAlgorithm.replace),
    );
    return _Dev(acct, user, engine);
  }

  test('register, merge, converge, overwrite, epoch, delete', () async {
    final name = 'e2e${DateTime.now().microsecondsSinceEpoch}';
    const pw = 'correct horse battery staple 42';

    final accA = AccountService(secrets: MemorySecretStore(), kdf: kdf);
    final reg =
        await accA.register(serverUrl: _url!, username: name, password: pw);
    expect(reg.recoveryKey, isNotEmpty);
    final a = await device('a', accA);
    await a.fav('one.mp3');
    await a.engine.overwriteCloud();

    final accB = AccountService(secrets: MemorySecretStore(), kdf: kdf);
    await accB.login(serverUrl: _url!, username: name, password: pw);
    final b = await device('b', accB);
    await b.engine.setUpAsNewDevice();
    expect(await b.favs(), ['one.mp3']);

    await a.fav('from_a.mp3');
    await b.fav('from_b.mp3');
    await a.engine.sync();
    await b.engine.sync();
    await a.engine.sync();
    const all = ['from_a.mp3', 'from_b.mp3', 'one.mp3'];
    expect(await a.favs(), all);
    expect(await b.favs(), all);

    await a.user
        .delete('favorite', where: 'filename = ?', whereArgs: ['one.mp3']);
    await a.engine.overwriteCloud();
    await expectLater(
        b.engine.sync(), throwsA(isA<SyncEpochChangedException>()));
    await b.engine.setUpAsNewDevice();
    expect(await b.favs(), ['from_a.mp3', 'from_b.mp3']);

    await accB.deleteAccount(pw);
    final accC = AccountService(secrets: MemorySecretStore(), kdf: kdf);
    await expectLater(
        accC.login(serverUrl: _url!, username: name, password: pw),
        throwsA(isA<SyncApiException>()));
  },
      skip: _url == null
          ? 'set WISPIE_E2E_URL (see server/scripts/e2e.sh)'
          : null,
      timeout: const Timeout(Duration(minutes: 3)));

  test('load: 100k play events first sync', () async {
    final name = 'load${DateTime.now().microsecondsSinceEpoch}';
    const pw = 'correct horse battery staple 42';
    final accA = AccountService(secrets: MemorySecretStore(), kdf: kdf);
    await accA.register(serverUrl: _url!, username: name, password: pw);
    final a = await device('a', accA);
    final stats = a.engine.changeset.stats;
    await stats.insert('playsession', {
      'id': 's1',
      'start_time': 1.0,
      'end_time': 2.0,
      'platform': 'test',
      'device_id': 'a',
      'hlc': Hlc.instance.now(),
      'dirty': 1,
    });
    final batch = stats.batch();
    for (var i = 0; i < 100000; i++) {
      batch.insert('playevent', {
        'uid': 'u$i',
        'session_id': 's1',
        'song_filename': 'song${i % 2000}.mp3',
        'timestamp': 1000.0 + i,
        'duration_played': 100.0,
        'total_length': 200.0,
        'play_ratio': 0.5,
        'foreground_duration': 100.0,
        'background_duration': 0.0,
        'hlc': Hlc.instance.now(),
        'dirty': 1,
      });
    }
    await batch.commit(noResult: true);
    final sw = Stopwatch()..start();
    await a.engine.overwriteCloud();
    final up = sw.elapsedMilliseconds;
    final accB = AccountService(secrets: MemorySecretStore(), kdf: kdf);
    await accB.login(serverUrl: _url!, username: name, password: pw);
    final b = await device('b', accB);
    sw.reset();
    await b.engine.setUpAsNewDevice();
    // ignore: avoid_print
    print(
        '100k events: initial upload ${up}ms, new-device pull ${sw.elapsedMilliseconds}ms');
    final n = await b.engine.changeset.stats
        .rawQuery('SELECT COUNT(*) c FROM playevent');
    expect(n.first['c'], 100000);
    await accA.deleteAccount(pw);
  },
      skip: _url == null ? 'set WISPIE_E2E_URL' : null,
      timeout: const Timeout(Duration(minutes: 5)));
}
