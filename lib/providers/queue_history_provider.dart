import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/queue_snapshot.dart';
import '../models/song.dart';
import '../services/database_service.dart';
import 'providers.dart';

class QueueHistoryNotifier extends AsyncNotifier<List<QueueSnapshot>> {
  @override
  Future<List<QueueSnapshot>> build() async {
    return _loadSnapshots();
  }

  Future<List<QueueSnapshot>> _loadSnapshots() async {
    return DatabaseService.instance.getQueueHistorySnapshots();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadSnapshots);
  }

  Future<void> deleteSnapshot(String id) async {
    await DatabaseService.instance.deleteQueueSnapshot(id);
    await refresh();
  }

  Future<void> clearAll() async {
    await DatabaseService.instance.clearQueueHistory();
    state = const AsyncData([]);
  }
}

final queueHistoryProvider =
    AsyncNotifierProvider<QueueHistoryNotifier, List<QueueSnapshot>>(
  QueueHistoryNotifier.new,
);

/// Resolves song filenames for a snapshot to actual Song objects.
///
/// Streamed tracks are resolved too: a queue that mixed an imported playlist
/// with local music has to come back whole, and they live in their own table.
final queueSnapshotSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, snapshotId) async {
  final filenames =
      await DatabaseService.instance.getQueueSnapshotSongs(snapshotId);
  final byFilename = ref.watch(songsByFilenameProvider);
  return [
    for (final filename in filenames)
      if (byFilename[filename] case final song?) song,
  ];
});

/// One listen inside a queue: the track, and when it was heard.
class QueueListen {
  final Song song;
  final DateTime playedAt;

  const QueueListen({required this.song, required this.playedAt});
}

/// Listens recorded in [queueId], earliest first, one entry per listen.
///
/// Read from the play events that carry that queue id, not from an index into
/// the live queue: a restored or reordered queue would otherwise label songs
/// the user skipped past as played, and miss the ones that were. A track heard
/// twice is two entries, so the time is what tells them apart.
final queueListensProvider =
    FutureProvider.family<List<QueueListen>, String>((ref, queueId) async {
  final listens = await DatabaseService.instance.getQueueListens(queueId);
  if (listens.isEmpty) return const [];
  final byFilename = ref.watch(songsByFilenameProvider);
  return [
    for (final listen in listens)
      if (byFilename[listen.filename] case final song?)
        QueueListen(
          song: song,
          playedAt: DateTime.fromMillisecondsSinceEpoch(
            (listen.timestamp * 1000).round(),
          ),
        ),
  ];
});
