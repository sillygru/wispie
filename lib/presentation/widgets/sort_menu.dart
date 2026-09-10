import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      tooltip: 'Sort by',
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
          child: const Text('Title (A-Z)'),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.artist,
          checked: effectiveSort == SongSortOrder.artist,
          child: const Text('Artist'),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.album,
          checked: effectiveSort == SongSortOrder.album,
          child: const Text('Album'),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.dateAdded,
          checked: effectiveSort == SongSortOrder.dateAdded,
          child: const Text('Date Added'),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.songDate,
          checked: effectiveSort == SongSortOrder.songDate,
          child: const Text('Song Date'),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.playCount,
          checked: effectiveSort == SongSortOrder.playCount,
          child: const Text('Most Played'),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.recentlyPlayed,
          checked: effectiveSort == SongSortOrder.recentlyPlayed,
          child: const Text('Recently Played'),
        ),
        CheckedPopupMenuItem(
          value: SongSortOrder.recommended,
          checked: effectiveSort == SongSortOrder.recommended,
          child: const Text('Recommended'),
        ),
      ],
    );
  }
}
