/// One-time move of saved shuffle state onto the smart default.
///
/// A state with no `savedAppVersion` predates smart shuffle, so its personality
/// is replaced with smart once. Any state that already carries the field is a
/// migrated state, and whatever personality the user picked there is kept.
library;

import '../../models/shuffle_config.dart';

ShuffleState migrateShuffleState(
  Map<String, dynamic>? json,
  String currentVersion,
) {
  if (json == null) {
    return ShuffleState(savedAppVersion: currentVersion);
  }

  final parsed = ShuffleState.fromJson(json);
  if (parsed.savedAppVersion == null) {
    return parsed.copyWith(
      config: parsed.config.copyWith(personality: ShufflePersonality.smart),
      savedAppVersion: currentVersion,
    );
  }

  return parsed.copyWith(savedAppVersion: currentVersion);
}
