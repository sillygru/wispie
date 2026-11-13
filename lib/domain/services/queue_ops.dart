import '../../models/queue_item.dart';
import 'native_accel.dart';

/// Pure queue list-planning logic.
///
/// Everything here is a plain function over lists: no player, no database, no
/// I/O. `AudioPlayerManager` decides *when* to call these and performs the
/// resulting player operations; the rules for *what* the queue should look like
/// afterwards live here so they can be unit tested directly.

/// A single planned change to the queue.
///
/// [from] is null for a plain insertion; when it is set the entry already
/// existed at that index and is being moved rather than duplicated.
class QueuePlan {
  /// Index the entry currently sits at, or null when inserting a new entry.
  final int? from;

  /// Index the entry should end up at, once [from] has been removed.
  final int to;

  /// The entry to place at [to]. For a move this is the existing item; for a
  /// copy or an insertion it is a fresh [QueueItem].
  final QueueItem item;

  const QueuePlan({
    required this.to,
    required this.item,
    this.from,
  });

  bool get isMove => from != null;

  @override
  String toString() => 'QueuePlan(from: $from, to: $to, ${item.song.filename})';
}

/// Finds [filename] in [queue], falling back to any of its [mergedSiblings].
///
/// Merged songs map several filenames onto one logical track, so a queue that
/// already holds a sibling counts as already holding the song.
int findInQueue(
  List<QueueItem> queue,
  String filename, {
  List<String> mergedSiblings = const [],
}) {
  return NativeAccel.findQueueSong(
    [for (final item in queue) item.song.filename],
    filename,
    mergedSiblings: mergedSiblings,
  );
}

/// Updates the RAM-based top order queue.
///
/// When [isOverride] is true, [queueId] moves to the front so it plays next.
/// Otherwise, [queueId] is appended to the end of the top order list.
List<String> updateSessionTopOrder(
  List<String> currentOrder,
  String queueId, {
  required bool isOverride,
}) {
  return NativeAccel.updateSessionTopOrder(
    currentOrder,
    queueId,
    isOverride: isOverride,
  );
}

/// Prunes entries that are no longer upcoming in [queue] (either already played,
/// currently playing, or removed).
List<String> pruneSessionTopOrder(
  List<QueueItem> queue,
  int currentIndex,
  List<String> sessionTopOrder,
) {
  return NativeAccel.pruneSessionTopOrder(
    [
      for (final item in queue) {'queueId': item.queueId}
    ],
    currentIndex,
    sessionTopOrder,
  );
}

/// Plans moving an already-queued upcoming entry to the top section.
///
/// If [queueId] is already present in [sessionTopOrder], this is an override
/// request and it moves immediately after [currentIndex]. Otherwise, it stacks
/// after the last active top entry in [sessionTopOrder] (or right after
/// [currentIndex] if none are present).
QueuePlan? planMoveUpcomingToTop(
  List<QueueItem> queue,
  int currentIndex,
  String queueId, {
  List<String> sessionTopOrder = const [],
}) {
  final plan = NativeAccel.planQueueMoveUpcomingToTop(
    queueIds: [for (final item in queue) item.queueId],
    currentIndex: currentIndex,
    queueId: queueId,
    sessionTopOrder: sessionTopOrder,
  );
  if (plan['valid'] != true) return null;
  final sourceIndex = plan['from'] as int;
  return QueuePlan(
    from: sourceIndex,
    to: plan['to'] as int,
    item: queue[sourceIndex],
  );
}

/// Plans "play this next": the entry lands after existing top-order entries,
/// or immediately after the current item when there are none.
///
/// An entry still upcoming is *moved* there, so it exists once. One that has
/// already played, or is not queued at all, is inserted as a fresh copy.
///
/// Only the exact filename triggers a move. A merged sibling is left for the
/// caller (AudioPlayerManager) to swap for the requested file, so "Play Next"
/// never silently moves the wrong file.
QueuePlan planPlayNext(
  List<QueueItem> queue,
  int currentIndex,
  QueueItem candidate, {
  List<String> sessionTopOrder = const [],
}) {
  final plan = NativeAccel.planQueuePlayNext(
    queueIds: [for (final item in queue) item.queueId],
    filenames: [for (final item in queue) item.song.filename],
    currentIndex: currentIndex,
    candidateFilename: candidate.song.filename,
    sessionTopOrder: sessionTopOrder,
  );
  final source = plan['source'] as int?;
  return QueuePlan(
    from: plan['from'] as int?,
    to: plan['to'] as int,
    item: source == null ? candidate : queue[source],
  );
}

/// Plans a tap on a queue row: play that entry now.
///
/// An entry that is still upcoming is *moved* to just after the current track,
/// so it exists once. An entry that has already played is *copied* there
/// instead, leaving the played section intact. Either way nothing at or before
/// the current track is disturbed. Returns null when there is nothing to do.
QueuePlan? planJumpTo(List<QueueItem> queue, int currentIndex, String queueId) {
  final plan = NativeAccel.planQueueJump(
    [for (final item in queue) item.queueId],
    currentIndex,
    queueId,
  );
  if (plan['valid'] != true) return null;
  final source = plan['source'] as int;
  return QueuePlan(
    from: plan['from'] as int?,
    to: plan['to'] as int,
    item: plan['from'] == null
        ? QueueItem(song: queue[source].song)
        : queue[source],
  );
}

/// Plans a drag-reorder. [newIndex] follows the insertion-slot convention:
/// the slot the entry is dropped into, before its own removal is accounted for.
/// Returns null when the move is a no-op or out of range.
QueuePlan? planReorder(List<QueueItem> queue, int oldIndex, int newIndex) {
  final plan = NativeAccel.planQueueReorder(
    queue.length,
    oldIndex,
    newIndex,
  );
  if (plan['valid'] != true) return null;
  return QueuePlan(
    from: plan['from'] as int,
    to: plan['to'] as int,
    item: queue[oldIndex],
  );
}

/// Applies a plan to a copy of [queue].
List<QueueItem> applyPlan(List<QueueItem> queue, QueuePlan plan) {
  final result = NativeAccel.applyQueuePlan(
    length: queue.length,
    from: plan.from,
    to: plan.to,
  );
  if (result['valid'] != true) {
    throw RangeError.index(plan.from ?? -1, queue);
  }
  final order = (result['order'] as List<dynamic>).cast<int>();
  return [
    for (final index in order) index == queue.length ? plan.item : queue[index]
  ];
}

/// Sorts [upcoming] back into [originalQueue] order, resuming from where
/// [current] sits in that order and wrapping around to the start — so turning
/// shuffle off continues the album or playlist from the right place rather than
/// jumping back to track one.
List<QueueItem> inOriginalOrder(
  List<QueueItem> upcoming,
  QueueItem current,
  List<QueueItem> originalQueue,
) {
  final order = NativeAccel.originalQueueOrder(
    upcomingIds: [for (final item in upcoming) item.queueId],
    upcomingFilenames: [for (final item in upcoming) item.song.filename],
    currentId: current.queueId,
    currentFilename: current.song.filename,
    originalIds: [for (final item in originalQueue) item.queueId],
    originalFilenames: [for (final item in originalQueue) item.song.filename],
  );
  return [for (final index in order) upcoming[index]];
}

/// One entry of the player's audio source sequence, reduced to what
/// reconciliation needs.
typedef SequenceEntry = ({String filename, String? queueId});

/// Rebuilds the effective queue from the player's own sequence.
///
/// Used to pick up changes made outside the app (notification or headset
/// actions). Entries are matched by queueId first and by filename second, so
/// deliberate duplicates keep their identity instead of collapsing together.
/// [resolveSong] supplies the current library row for a filename; entries it
/// cannot resolve and that are not already queued are dropped.
List<QueueItem> reconcileWithSequence(
  List<QueueItem> effective,
  List<SequenceEntry> sequence,
  QueueItem? Function(String filename) resolveItem,
) {
  final libraryItems = [
    for (final entry in sequence) resolveItem(entry.filename)
  ];
  final actions = NativeAccel.reconcileQueueSequence(
    effective: [
      for (final item in effective)
        {'queueId': item.queueId, 'filename': item.song.filename},
    ],
    sequence: [
      for (final entry in sequence)
        {'filename': entry.filename, 'queueId': entry.queueId},
    ],
    libraryFound: [for (final item in libraryItems) item != null],
  );
  final rebuilt = <QueueItem>[];
  for (final action in actions) {
    final sequenceIndex = action['sequenceIndex'] as int;
    final effectiveIndex = action['effectiveIndex'] as int?;
    final entry = sequence[sequenceIndex];
    final fromLibrary = libraryItems[sequenceIndex];
    if (effectiveIndex == null) {
      rebuilt.add(
        QueueItem(song: fromLibrary!.song, queueId: entry.queueId),
      );
    } else {
      final resolved = effective[effectiveIndex];
      rebuilt.add(
        resolved.copyWith(
          song: fromLibrary?.song ?? resolved.song,
          queueId: entry.queueId ?? resolved.queueId,
        ),
      );
    }
  }

  return rebuilt;
}
