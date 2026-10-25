import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/quick_action_config.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../tokens/player_tokens.dart';
import '../widgets/heart_context_menu.dart';
import 'song_actions.dart';
import 'app_icon.dart';
import '../tokens/app_icons.dart';
import '../motion/motion.dart';

/// The configurable row of actions on the Now Playing pane.
///
/// Order and membership come straight from `settings.quickActionConfig`, which
/// the Quick Actions settings screen already writes. Every action delegates to
/// the shared handlers in `song_actions.dart`, so behaviour matches the full
/// options menu exactly.
class QuickActionBar extends ConsumerWidget {
  final Song song;
  final Color accent;

  const QuickActionBar({
    super.key,
    required this.song,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(
      settingsProvider.select((s) => s.quickActionConfig),
    );

    // actionOrder is the master ordering; enabledActions is the subset shown.
    final actions = config.actionOrder
        .where((a) => config.enabledActions.contains(a))
        .toList();

    if (actions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PlayerTokens.s5),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: PlayerTokens.s2),
        itemBuilder: (context, index) => _QuickActionButton(
          action: actions[index],
          song: song,
          accent: accent,
        ),
      ),
    );
  }
}

class _QuickActionButton extends ConsumerWidget {
  final QuickAction action;
  final Song song;
  final Color accent;

  const _QuickActionButton({
    required this.action,
    required this.song,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userDataProvider);
    final isFavorite = userData.isFavorite(song.filename);
    final isSuggestLess = userData.isSuggestLess(song.filename);

    final active = (action == QuickAction.toggleFavorite && isFavorite) ||
        (action == QuickAction.toggleSuggestLess && isSuggestLess);

    final destructive =
        action == QuickAction.delete || action == QuickAction.hide;

    final foreground = active
        ? accent
        : destructive
            ? Colors.redAccent.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: PlayerTokens.aSecondary);

    // Bare icons on the backdrop — no chips, no fills, no borders.
    return Tooltip(
      message:
          _label(context, isFavorite: isFavorite, isSuggestLess: isSuggestLess),
      child: InkResponse(
        radius: 26,
        onTap: () => _invoke(context, ref, isFavorite, isSuggestLess),
        onLongPress: action == QuickAction.toggleFavorite
            ? () {
                MotionHaptics.medium();
                showHeartContextMenu(
                  context: context,
                  ref: ref,
                  songFilename: song.filename,
                  songTitle: song.title,
                );
              }
            : null,
        child: SizedBox(
          width: 52,
          height: 48,
          child: AppIcon(
            _icon(isFavorite: isFavorite, isSuggestLess: isSuggestLess),
            size: 22,
            color: foreground,
          ),
        ),
      ),
    );
  }

  void _invoke(
    BuildContext context,
    WidgetRef ref,
    bool isFavorite,
    bool isSuggestLess,
  ) {
    MotionHaptics.selection();

    switch (action) {
      case QuickAction.toggleFavorite:
        // The icon itself flips to filled, so a snackbar would just be noise.
        songActionToggleFavorite(
          context,
          ref,
          song.filename,
          song.title,
          showFeedback: false,
        );
      case QuickAction.toggleSuggestLess:
        songActionToggleSuggestLess(context, ref, song.filename, song.title);
      case QuickAction.playNext:
        songActionPlayNext(context, ref, song);
      case QuickAction.addToPlaylist:
        songActionAddToPlaylist(context, ref, song.filename);
      case QuickAction.addToNewPlaylist:
        songActionAddToNewPlaylist(context, ref, song.filename);
      case QuickAction.share:
        songActionShare(context, song);
      case QuickAction.editMetadata:
        songActionEditMetadata(context, song);
      case QuickAction.moveToFolder:
        songActionMoveToFolder(context, ref, song);
      case QuickAction.goToAlbum:
        songActionGoToAlbum(context, ref, song);
      case QuickAction.goToArtist:
        songActionGoToArtist(context, ref, song);
      case QuickAction.hide:
        songActionHide(context, ref, song);
      case QuickAction.delete:
        songActionDelete(context, ref, song);
    }
  }

  AppIconData _icon({required bool isFavorite, required bool isSuggestLess}) {
    switch (action) {
      case QuickAction.toggleFavorite:
        return isFavorite ? AppIcons.favorite : AppIcons.favorite;
      case QuickAction.toggleSuggestLess:
        return isSuggestLess ? AppIcons.thumbDown : AppIcons.thumbDown;
      case QuickAction.playNext:
        return AppIcons.playlist;
      case QuickAction.addToPlaylist:
        return AppIcons.playlistAdd;
      case QuickAction.addToNewPlaylist:
        return AppIcons.libraryAdd;
      case QuickAction.share:
        return AppIcons.share;
      case QuickAction.editMetadata:
        return AppIcons.edit;
      case QuickAction.moveToFolder:
        return AppIcons.folderMove;
      case QuickAction.goToAlbum:
        return AppIcons.album;
      case QuickAction.goToArtist:
        return AppIcons.person;
      case QuickAction.hide:
        return AppIcons.visibilityOff;
      case QuickAction.delete:
        return AppIcons.delete;
    }
  }

  String _label(
    BuildContext context, {
    required bool isFavorite,
    required bool isSuggestLess,
  }) {
    final l10n = context.l10n;
    switch (action) {
      case QuickAction.toggleFavorite:
        return isFavorite
            ? l10n.songMenuRemoveFavorite
            : l10n.songMenuAddFavorite;
      case QuickAction.toggleSuggestLess:
        return isSuggestLess
            ? l10n.quickActionSuggestMore
            : l10n.quickActionSuggestLess;
      case QuickAction.playNext:
        return l10n.songMenuPlayNext;
      case QuickAction.addToPlaylist:
        return l10n.songMenuAddToPlaylist;
      case QuickAction.addToNewPlaylist:
        return l10n.songMenuAddToNewPlaylist;
      case QuickAction.share:
        return l10n.songMenuShare;
      case QuickAction.editMetadata:
        return l10n.songMenuEditMetadata;
      case QuickAction.moveToFolder:
        return l10n.songMenuMoveToFolder;
      case QuickAction.goToAlbum:
        return l10n.quickActionGoToAlbum;
      case QuickAction.goToArtist:
        return l10n.quickActionGoToArtist;
      case QuickAction.hide:
        return l10n.songMenuRemoveFromLibrary;
      case QuickAction.delete:
        return l10n.actionDelete;
    }
  }
}
