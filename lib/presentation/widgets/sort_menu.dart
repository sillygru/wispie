import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/settings_provider.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

class SortMenu extends ConsumerWidget {
  /// Optional local override. When provided, the menu reads and writes this
  /// value instead of the global [settingsProvider] sort — used by screens
  /// like the grouped artist view that default to their own ordering without
  /// polluting every other list in the app.
  final SongSortOrder? sortOrder;
  final ValueChanged<SongSortOrder>? onSelected;

  const SortMenu({super.key, this.sortOrder, this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveSort = sortOrder ?? ref.watch(settingsProvider).sortOrder;

    return PopupMenuButton<SongSortOrder>(
      icon: const AppIcon(AppIcons.sort, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      tooltip: context.l10n.sortBy,
      onSelected: (order) {
        final override = onSelected;
        if (override != null) {
          override(order);
        } else {
          ref.read(settingsProvider.notifier).setSortOrder(order);
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: SongSortOrder.title,
          checked: effectiveSort == SongSortOrder.title,
          child: Text(context.l10n.sortTitleAZ),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.artist,
          checked: effectiveSort == SongSortOrder.artist,
          child: Text(context.l10n.metadataArtistLabel),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.album,
          checked: effectiveSort == SongSortOrder.album,
          child: Text(context.l10n.metadataAlbumLabel),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.dateAdded,
          checked: effectiveSort == SongSortOrder.dateAdded,
          child: Text(context.l10n.sortDateAdded),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.songDateOldNew,
          checked: effectiveSort == SongSortOrder.songDateOldNew,
          child: Text(context.l10n.sortSongDateOldNew),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.songDateNewOld,
          checked: effectiveSort == SongSortOrder.songDateNewOld,
          child: Text(context.l10n.sortSongDateNewOld),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.playCount,
          checked: effectiveSort == SongSortOrder.playCount,
          child: Text(context.l10n.sortMostPlayed),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.recentlyPlayed,
          checked: effectiveSort == SongSortOrder.recentlyPlayed,
          child: Text(context.l10n.sortRecentlyPlayed),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.recommended,
          checked: effectiveSort == SongSortOrder.recommended,
          child: Text(context.l10n.sortRecommended),
        ),
      ],
    );
  }
}
