import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../widgets/heart_context_menu.dart';
import 'pop_icon.dart';
import 'song_actions.dart';

/// Heart toggle for a track. The pop and the accent ring come from [PopIcon],
/// so every favourite control in the app animates the same way.
class FavoriteHeartButton extends ConsumerWidget {
  final String filename;
  final String title;
  final Color accent;
  final Color inactiveColor;
  final double iconSize;
  final double boxSize;

  const FavoriteHeartButton({
    super.key,
    required this.filename,
    required this.title,
    required this.accent,
    required this.inactiveColor,
    this.iconSize = 28,
    this.boxSize = 48,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isFavorite = ref.watch(
      userDataProvider.select((data) => data.isFavorite(filename)),
    );
    return PopIcon(
      isActive: isFavorite,
      size: iconSize,
      hitSize: boxSize,
      activeColor: accent,
      inactiveColor: inactiveColor,
      onTap: () => songActionToggleFavorite(
        context,
        ref,
        filename,
        title,
        showFeedback: false,
      ),
      onLongPress: () => showHeartContextMenu(
        context: context,
        ref: ref,
        songFilename: filename,
        songTitle: title,
      ),
    );
  }
}
