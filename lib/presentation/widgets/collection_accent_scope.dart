import 'package:flutter/widgets.dart';

/// The accent a collection (artist / album) supplies to everything drawn
/// inside it, overriding the app-wide playing-song accent.
///
/// The app theme is always the *current track's* cover, which is right for the
/// player and the library lists but wrong for an artist or album page: opening
/// "Radiohead" while something blue plays left the page's buttons blue. Pages
/// that already own a collection's art install this scope so their descendants
/// — buttons, chips, active rows — follow that artwork instead.
class CollectionAccentScope extends InheritedWidget {
  final Color accent;

  /// The collection's cover has no usable chroma, so the page falls back to the
  /// colourless variant rather than inventing a hue.
  final bool isNeutral;

  const CollectionAccentScope({
    super.key,
    required this.accent,
    required this.isNeutral,
    required super.child,
  });

  /// The nearest enclosing collection accent, or null when the page is running
  /// on the app-wide theme.
  static CollectionAccentScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CollectionAccentScope>();

  @override
  bool updateShouldNotify(CollectionAccentScope oldWidget) =>
      accent != oldWidget.accent || isNeutral != oldWidget.isNeutral;
}
