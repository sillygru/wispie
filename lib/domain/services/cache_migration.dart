// SPDX-License-Identifier: GPL-3.0-only
import 'dart:isolate';

import '../../data/rust/native_command.dart';

/// What a migration pass found and did.
class CacheMigrationResult {
  const CacheMigrationResult({
    this.moved = 0,
    this.dropped = 0,
    this.failed = 0,
    this.legacyFound = false,
  });

  final int moved;

  /// Files deliberately not carried over: scratch, retired formats, cache
  /// leftovers no bucket owns.
  final int dropped;

  /// Files that should have moved and did not. Any of them keeps the tree and
  /// the layout marker so the next launch retries.
  final int failed;

  final bool legacyFound;

  bool get migratedAnything => moved > 0 || dropped > 0 || legacyFound;

  /// True when nothing was left behind.
  bool get complete => failed == 0;

  @override
  String toString() => 'moved $moved, dropped $dropped, failed $failed'
      '${legacyFound ? '' : ' (no legacy layout)'}';
}

/// Bumped whenever the layout or what counts as legacy changes, so a migrated
/// install pays one preference read per launch instead of a filesystem sweep.
const int cacheLayoutVersion = 3;

/// True when [storedVersion] predates the current layout. A missing marker means
/// this install has never migrated.
bool needsCacheLayoutMigration(int? storedVersion) =>
    (storedVersion ?? 0) < cacheLayoutVersion;

Future<CacheMigrationResult> migrateLegacyCacheLayout({
  required String supportPath,
  required String cacheRootPath,
  List<String> orphanDirs = const [],
}) async {
  final request = <String, Object?>{
    'op': 'migrate',
    'support': supportPath,
    'root': cacheRootPath,
    'orphan_dirs': orphanDirs,
  };
  final reply =
      await Isolate.run(() => runCoreCommand('cache_layout', request));
  return CacheMigrationResult(
    moved: reply['moved'] as int,
    dropped: reply['dropped'] as int,
    failed: reply['failed'] as int,
    legacyFound: reply['legacy_found'] as bool,
  );
}
