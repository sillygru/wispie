import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/version_tracker.dart';

/// Result of comparing the stored last-opened version with the running one.
/// Overridden in `main()`; a "what's new" screen can read `previous` / `current`
/// from here when `isUpgrade` is true.
final versionChangeProvider = Provider<VersionChange>(
  (ref) => throw UnimplementedError('versionChangeProvider not overridden'),
);
