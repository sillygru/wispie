import '../../domain/services/native_accel.dart';

/// Every song name a sync payload carries.
///
/// Where each entity names a song, how tombstones pack one into their key and
/// how the queue snapshots hold theirs are contract rules; they live in the
/// native core (`rust/wispie_core/src/sync.rs`).
Set<String> collectSongNames(Map records) => (NativeAccel.sync({
      'action': 'refs_collect',
      'records': records,
    })['names'] as List<dynamic>)
        .cast<String>()
        .toSet();

/// Rewrites every song name in [records] to its local filename.
///
/// A name missing from [mapping] keeps its identity; a null value drops the
/// record, except a merge group's priority name, whose row survives without it.
Map<String, dynamic> remapSongNames(
  Map records,
  Map<String, String?> mapping,
) =>
    NativeAccel.sync({
      'action': 'refs_remap',
      'records': records,
      'mapping': mapping,
    })['records'] as Map<String, dynamic>;
