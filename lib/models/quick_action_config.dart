import 'dart:convert';

enum QuickAction {
  playNext,
  goToAlbum,
  goToArtist,
  moveToFolder,
  addToPlaylist,
  share,
  addToNewPlaylist,
  editMetadata,
  toggleFavorite,
  toggleSuggestLess,
  delete,
  hide,
}

/// The saved layout is a list of enum *indices*, which makes removing an action a
/// decode hazard rather than a cleanup: an index saved by an older build points
/// past the end of [QuickAction.values]. Throwing on it would discard the user's
/// whole arrangement over one deleted row, so unresolvable indices are dropped and
/// the rest of the layout is honoured.
QuickAction? _quickActionAtIndex(Object? value) {
  final index = value is int ? value : int.tryParse('$value');
  if (index == null || index < 0 || index >= QuickAction.values.length) {
    return null;
  }
  return QuickAction.values[index];
}

List<QuickAction> _decodeActions(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final value in raw)
      if (_quickActionAtIndex(value) case final action?) action,
  ];
}

class QuickActionConfig {
  final List<QuickAction> enabledActions;
  final List<QuickAction> actionOrder;

  const QuickActionConfig({
    required this.enabledActions,
    required this.actionOrder,
  });

  static const List<QuickAction> defaultOrder = [
    QuickAction.toggleFavorite,
    QuickAction.playNext,
    QuickAction.addToPlaylist,
    QuickAction.share,
    QuickAction.delete,
    QuickAction.hide,
    QuickAction.goToAlbum,
    QuickAction.goToArtist,
    QuickAction.moveToFolder,
    QuickAction.addToNewPlaylist,
    QuickAction.editMetadata,
    QuickAction.toggleSuggestLess,
  ];

  /// Off by default. These are the actions that need no target to be chosen
  /// first, so they are what the bar offers out of the box.
  static const List<QuickAction> defaultEnabled = [
    QuickAction.toggleFavorite,
    QuickAction.playNext,
    QuickAction.addToPlaylist,
    QuickAction.share,
    QuickAction.delete,
  ];

  static QuickActionConfig get defaults => const QuickActionConfig(
        enabledActions: defaultEnabled,
        actionOrder: defaultOrder,
      );

  QuickActionConfig copyWith({
    List<QuickAction>? enabledActions,
    List<QuickAction>? actionOrder,
  }) {
    return QuickActionConfig(
      enabledActions: enabledActions ?? this.enabledActions,
      actionOrder: actionOrder ?? this.actionOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabledActions': enabledActions.map((e) => e.index).toList(),
        'actionOrder': actionOrder.map((e) => e.index).toList(),
      };

  factory QuickActionConfig.fromJson(Map<String, dynamic> json) {
    final enabled = _decodeActions(json['enabledActions']);
    final order = _decodeActions(json['actionOrder']);
    return QuickActionConfig(
      enabledActions: enabled.isEmpty ? defaultEnabled : enabled,
      actionOrder: order.isEmpty ? defaultOrder : order,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory QuickActionConfig.fromJsonString(String jsonString) {
    try {
      return QuickActionConfig.fromJson(jsonDecode(jsonString));
    } catch (_) {
      return defaults;
    }
  }
}
