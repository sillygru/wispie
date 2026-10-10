import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wispie/services/database_optimizer_service.dart';
import 'package:wispie/services/database_service.dart';

import 'test_helpers.dart';

/// Phase 3: local change tracking. User actions stamp hlc/dirty and explicit
/// removals write tombstones; maintenance (rename, library cleanup) does not.
void main() {
  late TestEnvironment testEnv;

  setUpAll(() {
    testEnv = TestEnvironment();
    testEnv.setUp();
  });

  tearDownAll(() {
    testEnv.tearDown();
  });

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await DatabaseService.instance.init();
    final data = DatabaseService.instance.getUserDataDatabase()!;
    final stats = DatabaseService.instance.getStatsDatabase()!;
    for (final t in const [
      'favorite',
      'suggestless',
      'hidden',
      'playlist',
      'playlist_song',
      'merged_song',
      'merged_song_group',
      'sync_tombstone'
    ]) {
      await data.delete(t);
    }
    for (final t in const ['playevent', 'playsession', 'sync_tombstone']) {
      await stats.delete(t);
    }
  });

  Future<List<Map<String, Object?>>> tombstones(
      {required bool stats, String? entity}) async {
    final db = stats
        ? DatabaseService.instance.getStatsDatabase()!
        : DatabaseService.instance.getUserDataDatabase()!;
    return db.query('sync_tombstone',
        where: entity == null ? null : 'entity = ?',
        whereArgs: entity == null ? null : [entity]);
  }

  test('addFavorite stamps dirty + hlc, removeFavorite tombstones', () async {
    final db = DatabaseService.instance;
    await db.addFavorite('a.mp3');
    final data = db.getUserDataDatabase()!;
    final row = (await data.query('favorite')).single;
    expect(row['dirty'], 1);
    expect(row['hlc'], isNotNull);

    await db.removeFavorite('a.mp3');
    expect(await data.query('favorite'), isEmpty);
    final tombs = await tombstones(stats: false, entity: 'favorites');
    expect(tombs.single['key'], 'a.mp3');
    expect(tombs.single['dirty'], 1);
  });

  test('re-adding a favorite clears its tombstone', () async {
    final db = DatabaseService.instance;
    await db.addFavorite('a.mp3');
    await db.removeFavorite('a.mp3');
    await db.addFavorite('a.mp3');
    expect(await tombstones(stats: false, entity: 'favorites'), isEmpty);
    expect(
        (await db.getUserDataDatabase()!.query('favorite')).single['dirty'], 1);
  });

  test('renameFile moves rows dirty without tombstones (maintenance)',
      () async {
    final db = DatabaseService.instance;
    await db.addFavorite('old.mp3');
    // Clear the tombstone bookkeeping from the add so we only observe rename.
    await db.getUserDataDatabase()!.delete('sync_tombstone');

    await db.renameFile('old.mp3', 'new.mp3');
    final rows = await db.getUserDataDatabase()!.query('favorite');
    expect(rows.single['filename'], 'new.mp3');
    expect(rows.single['dirty'], 1);
    expect(await tombstones(stats: false), isEmpty);
  });

  test('deleteFile is maintenance: no tombstones', () async {
    final db = DatabaseService.instance;
    await db.addFavorite('gone.mp3');
    await db.getUserDataDatabase()!.delete('sync_tombstone');

    await db.deleteFile('gone.mp3');
    expect(await db.getUserDataDatabase()!.query('favorite'), isEmpty);
    expect(await tombstones(stats: false), isEmpty);
  });

  test('play events get a uid and are dirty', () async {
    final db = DatabaseService.instance;
    await db.insertPlayEvent({
      'session_id': 's1',
      'song_filename': 'a.mp3',
      'timestamp': 100.0,
      'duration_played': 10.0,
      'total_length': 200.0,
      'play_ratio': 0.05,
    });
    final row = (await db.getStatsDatabase()!.query('playevent')).single;
    expect(row['uid'], isNotNull);
    expect(row['dirty'], 1);
    expect(row['hlc'], isNotNull);
  });

  test('optimizer deletion tombstones play events and sessions', () async {
    final db = DatabaseService.instance;
    final stats = db.getStatsDatabase()!;
    // A short (<60s) session with one event: the optimizer should delete and
    // tombstone it so it does not resurrect from another device.
    await stats.insert('playsession', {
      'id': 'short',
      'start_time': 0.0,
      'end_time': 5.0,
      'platform': 'test',
      'hlc': 1,
      'dirty': 1,
    });
    await stats.insert('playevent', {
      'uid': 'u-short-1',
      'session_id': 'short',
      'song_filename': 'a.mp3',
      'timestamp': 1.0,
      'duration_played': 5.0,
      'total_length': 200.0,
      'play_ratio': 0.02,
      'hlc': 1,
      'dirty': 1,
    });

    final result =
        await DatabaseOptimizerService().deleteShortSessionsForTest(stats);
    expect(result['deletedSessions'], 1);

    final eventTombs = await tombstones(stats: true, entity: 'play_events');
    final sessionTombs = await tombstones(stats: true, entity: 'play_sessions');
    expect(eventTombs.map((t) => t['key']), contains('u-short-1'));
    expect(sessionTombs.map((t) => t['key']), contains('short'));
  });
}
