import 'package:equatable/equatable.dart';

class ShuffleConfig extends Equatable {
  final bool enabled;
  final bool antiRepeatEnabled;
  final bool streakBreakerEnabled;
  final double favoriteMultiplier;
  final double suggestLessMultiplier;
  final int historyLimit;

  /// 0 favours familiar songs, 1 favours discovery.
  final double discoveryLevel;

  const ShuffleConfig({
    this.enabled = false,
    this.antiRepeatEnabled = true,
    this.streakBreakerEnabled = true,
    this.favoriteMultiplier = 1.2,
    this.suggestLessMultiplier = 0.2,
    this.historyLimit = 200,
    this.discoveryLevel = 0.35,
  });

  factory ShuffleConfig.fromJson(Map<String, dynamic> json) {
    return ShuffleConfig(
      enabled: (json['enabled'] as bool?) ?? false,
      antiRepeatEnabled: (json['anti_repeat_enabled'] as bool?) ?? true,
      streakBreakerEnabled: (json['streak_breaker_enabled'] as bool?) ?? true,
      favoriteMultiplier:
          ((json['favorite_multiplier'] as num?) ?? 1.2).toDouble(),
      suggestLessMultiplier:
          ((json['suggest_less_multiplier'] as num?) ?? 0.2).toDouble(),
      historyLimit: (json['history_limit'] as int?) ?? 200,
      discoveryLevel: _parseDiscoveryLevel(json['discovery_level']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'anti_repeat_enabled': antiRepeatEnabled,
      'streak_breaker_enabled': streakBreakerEnabled,
      'favorite_multiplier': favoriteMultiplier,
      'suggest_less_multiplier': suggestLessMultiplier,
      'history_limit': historyLimit,
      'discovery_level': discoveryLevel,
    };
  }

  static double _parseDiscoveryLevel(Object? val) {
    if (val is! num || !val.isFinite) return 0.35;
    return val.toDouble().clamp(0.0, 1.0).toDouble();
  }

  ShuffleConfig copyWith({
    bool? enabled,
    bool? antiRepeatEnabled,
    bool? streakBreakerEnabled,
    double? favoriteMultiplier,
    double? suggestLessMultiplier,
    int? historyLimit,
    double? discoveryLevel,
  }) {
    return ShuffleConfig(
      enabled: enabled ?? this.enabled,
      antiRepeatEnabled: antiRepeatEnabled ?? this.antiRepeatEnabled,
      streakBreakerEnabled: streakBreakerEnabled ?? this.streakBreakerEnabled,
      favoriteMultiplier: favoriteMultiplier ?? this.favoriteMultiplier,
      suggestLessMultiplier:
          suggestLessMultiplier ?? this.suggestLessMultiplier,
      historyLimit: historyLimit ?? this.historyLimit,
      discoveryLevel: discoveryLevel ?? this.discoveryLevel,
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        antiRepeatEnabled,
        streakBreakerEnabled,
        favoriteMultiplier,
        suggestLessMultiplier,
        historyLimit,
        discoveryLevel,
      ];
}

class HistoryEntry extends Equatable {
  final String filename;
  final double timestamp;

  const HistoryEntry({required this.filename, required this.timestamp});

  factory HistoryEntry.fromJson(dynamic json) {
    if (json is String) {
      // Backwards compatibility for legacy string-only history
      return HistoryEntry(filename: json, timestamp: 0);
    }
    return HistoryEntry(
      filename: json['filename'],
      timestamp: (json['timestamp'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'timestamp': timestamp,
    };
  }

  @override
  List<Object?> get props => [filename, timestamp];
}

class ShuffleState extends Equatable {
  final ShuffleConfig config;

  const ShuffleState({this.config = const ShuffleConfig()});

  factory ShuffleState.fromJson(Map<String, dynamic> json) {
    return ShuffleState(
      config: json['config'] != null
          ? ShuffleConfig.fromJson(json['config'])
          : const ShuffleConfig(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'config': config.toJson()};
  }

  ShuffleState copyWith({ShuffleConfig? config}) {
    return ShuffleState(config: config ?? this.config);
  }

  @override
  List<Object?> get props => [config];
}
