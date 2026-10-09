import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/shuffle_migration.dart';
import 'package:wispie/models/shuffle_config.dart';

const _version = '1.4.4+100';

void main() {
  group('migrateShuffleState', () {
    test('no saved state lands on smart', () {
      final state = migrateShuffleState(null, _version);

      expect(state.config.personality, ShufflePersonality.smart);
      expect(state.savedAppVersion, _version);
    });

    test('legacy state without a version is moved to smart once', () {
      final state = migrateShuffleState({
        'config': {'enabled': true, 'personality': 'default'},
      }, _version);

      expect(state.config.personality, ShufflePersonality.smart);
      expect(state.config.enabled, isTrue);
      expect(state.savedAppVersion, _version);
    });

    test('a migrated state keeps the legacy mode the user picked', () {
      final json = {
        'config': {'personality': 'explorer'},
        'savedAppVersion': '1.4.3+99',
      };

      final first = migrateShuffleState(json, _version);
      final second = migrateShuffleState(first.toJson(), _version);

      expect(first.config.personality, ShufflePersonality.explorer);
      expect(second.config.personality, ShufflePersonality.explorer);
    });

    test('custom slider values survive the move to smart', () {
      final state = migrateShuffleState({
        'config': {
          'personality': 'custom',
          'most_played_weight': 40,
          'favorites_weight': 70,
        },
      }, _version);

      expect(state.config.personality, ShufflePersonality.smart);
      expect(state.config.mostPlayedWeight, 40);
      expect(state.config.favoritesWeight, 70);
    });

    test('a user-picked custom mode keeps its slider values', () {
      final state = migrateShuffleState({
        'config': {
          'personality': 'custom',
          'most_played_weight': 40,
          'favorites_weight': 70,
        },
        'savedAppVersion': '1.4.3+99',
      }, _version);

      expect(state.config.personality, ShufflePersonality.custom);
      expect(state.config.mostPlayedWeight, 40);
      expect(state.config.favoritesWeight, 70);
    });

    test('round trip keeps discoveryLevel and savedAppVersion', () {
      final original = ShuffleState(
        config: const ShuffleConfig(discoveryLevel: 0.8),
        savedAppVersion: _version,
      );

      final restored = ShuffleState.fromJson(original.toJson());

      expect(restored, original);
      expect(restored.config.discoveryLevel, 0.8);
      expect(restored.savedAppVersion, _version);
    });
  });

  group('ShuffleConfig parsing', () {
    test('a missing personality is smart', () {
      expect(ShuffleConfig.fromJson({}).personality, ShufflePersonality.smart);
    });

    test('an unknown personality is smart', () {
      expect(ShuffleConfig.fromJson({'personality': 'bogus'}).personality,
          ShufflePersonality.smart);
    });

    test('the stored legacy default string still means defaultMode', () {
      expect(ShuffleConfig.fromJson({'personality': 'default'}).personality,
          ShufflePersonality.defaultMode);
    });

    test('smart round-trips through JSON', () {
      final json = const ShuffleConfig().toJson();

      expect(json['personality'], 'smart');
      expect(
          ShuffleConfig.fromJson(json).personality, ShufflePersonality.smart);
    });

    test('isLegacy is false only for smart', () {
      for (final p in ShufflePersonality.values) {
        expect(ShuffleConfig(personality: p).isLegacy,
            p != ShufflePersonality.smart);
      }
    });

    test('discoveryLevel is clamped and falls back on bad input', () {
      expect(
          ShuffleConfig.fromJson({'discovery_level': 4}).discoveryLevel, 1.0);
      expect(
          ShuffleConfig.fromJson({'discovery_level': -2}).discoveryLevel, 0.0);
      expect(ShuffleConfig.fromJson({'discovery_level': 'high'}).discoveryLevel,
          0.35);
      expect(ShuffleConfig.fromJson({}).discoveryLevel, 0.35);
    });
  });
}
