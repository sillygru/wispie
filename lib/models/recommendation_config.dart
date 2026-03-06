import 'dart:convert';

enum RecommendationType {
  quickPicks,
  topHits,
  freshFinds,
  forgottenFavorites,
  quickRefresh,
  artistMix,
}

class RecommendationConfig {
  final Map<RecommendationType, bool> enabledTypes;
  final Map<RecommendationType, int> priorities;

  const RecommendationConfig({
    this.enabledTypes = const {},
    this.priorities = const {},
  });

  static RecommendationConfig get defaults {
    return RecommendationConfig(
      enabledTypes: {
        for (final type in RecommendationType.values) type: true,
      },
      priorities: {
        for (final type in RecommendationType.values) type: 1,
      },
    );
  }

  bool isEnabled(RecommendationType type) {
    return enabledTypes[type] ?? true;
  }

  int priority(RecommendationType type) {
    return priorities[type] ?? 1;
  }

  RecommendationConfig copyWith({
    Map<RecommendationType, bool>? enabledTypes,
    Map<RecommendationType, int>? priorities,
  }) {
    return RecommendationConfig(
      enabledTypes: enabledTypes ?? this.enabledTypes,
      priorities: priorities ?? this.priorities,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabledTypes': enabledTypes
            .map((k, v) => MapEntry(k.index.toString(), v)),
        'priorities': priorities
            .map((k, v) => MapEntry(k.index.toString(), v)),
      };

  factory RecommendationConfig.fromJson(Map<String, dynamic> json) {
    final enabledTypes = <RecommendationType, bool>{};
    final priorities = <RecommendationType, int>{};

    if (json['enabledTypes'] is Map) {
      for (final entry in (json['enabledTypes'] as Map).entries) {
        final idx = int.tryParse(entry.key.toString());
        if (idx != null && idx < RecommendationType.values.length) {
          enabledTypes[RecommendationType.values[idx]] = entry.value as bool;
        }
      }
    }

    if (json['priorities'] is Map) {
      for (final entry in (json['priorities'] as Map).entries) {
        final idx = int.tryParse(entry.key.toString());
        if (idx != null && idx < RecommendationType.values.length) {
          priorities[RecommendationType.values[idx]] = entry.value as int;
        }
      }
    }

    return RecommendationConfig(
      enabledTypes: enabledTypes,
      priorities: priorities,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory RecommendationConfig.fromJsonString(String jsonString) {
    try {
      return RecommendationConfig.fromJson(jsonDecode(jsonString));
    } catch (_) {
      return defaults;
    }
  }

  static String typeToId(RecommendationType type) {
    switch (type) {
      case RecommendationType.quickPicks:
        return 'quick_picks';
      case RecommendationType.topHits:
        return 'top_hits';
      case RecommendationType.freshFinds:
        return 'fresh_finds';
      case RecommendationType.forgottenFavorites:
        return 'forgotten_favorites';
      case RecommendationType.quickRefresh:
        return 'quick_refresh';
      case RecommendationType.artistMix:
        return 'artist_mix';
    }
  }

  static RecommendationType? idToType(String id) {
    switch (id) {
      case 'quick_picks':
        return RecommendationType.quickPicks;
      case 'top_hits':
        return RecommendationType.topHits;
      case 'fresh_finds':
        return RecommendationType.freshFinds;
      case 'forgotten_favorites':
        return RecommendationType.forgottenFavorites;
      case 'quick_refresh':
        return RecommendationType.quickRefresh;
      case 'artist_mix':
        return RecommendationType.artistMix;
      default:
        return null;
    }
  }

  static String typeDisplayName(RecommendationType type) {
    switch (type) {
      case RecommendationType.quickPicks:
        return 'Quick Picks';
      case RecommendationType.topHits:
        return 'Top Hits';
      case RecommendationType.freshFinds:
        return 'Fresh Finds';
      case RecommendationType.forgottenFavorites:
        return 'Forgotten Favorites';
      case RecommendationType.quickRefresh:
        return 'Quick Refresh';
      case RecommendationType.artistMix:
        return 'Artist Mix';
    }
  }

  static String typeDescription(RecommendationType type) {
    switch (type) {
      case RecommendationType.quickPicks:
        return 'Personalized song suggestions';
      case RecommendationType.topHits:
        return 'Your most played tracks';
      case RecommendationType.freshFinds:
        return 'Newly added to your library';
      case RecommendationType.forgottenFavorites:
        return 'Songs you haven\'t heard in a while';
      case RecommendationType.quickRefresh:
        return 'Rarely played tracks';
      case RecommendationType.artistMix:
        return 'Tracks from your favorite artist';
    }
  }
}
