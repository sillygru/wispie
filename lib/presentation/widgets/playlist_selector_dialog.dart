import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../tokens/app_tokens.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/pressable.dart';
import '../tokens/app_icons.dart';

void showPlaylistSelector(
    BuildContext context, WidgetRef ref, String songFilename) {
  showDialog(
    context: context,
    builder: (context) => PlaylistSelectorDialog(songFilenames: [songFilename]),
  );
}

void showBulkPlaylistSelector(
    BuildContext context, WidgetRef ref, List<String> songFilenames) {
  showDialog(
    context: context,
    builder: (context) => PlaylistSelectorDialog(songFilenames: songFilenames),
  );
}

class PlaylistSelectorDialog extends ConsumerStatefulWidget {
  final List<String> songFilenames;

  const PlaylistSelectorDialog({super.key, required this.songFilenames});

  @override
  ConsumerState<PlaylistSelectorDialog> createState() =>
      _PlaylistSelectorDialogState();
}

class _PlaylistSelectorDialogState
    extends ConsumerState<PlaylistSelectorDialog> {
  late Set<String> _selectedPlaylistIds;
  late bool? _isFavorite; // null means mixed, true means all, false means none
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final userData = ref.read(userDataProvider);

      if (widget.songFilenames.length == 1) {
        final songFilename = widget.songFilenames[0];
        _isFavorite = userData.isFavorite(songFilename);
        _selectedPlaylistIds = userData.playlists
            .where((p) => !p.isRecommendation)
            .where(
                (pl) => pl.songs.any((ps) => ps.songFilename == songFilename))
            .map((pl) => pl.id)
            .toSet();
      } else {
        // Bulk mode
        int favoriteCount = 0;
        for (final f in widget.songFilenames) {
          if (userData.isFavorite(f)) favoriteCount++;
        }
        if (favoriteCount == 0) {
          _isFavorite = false;
        } else if (favoriteCount == widget.songFilenames.length) {
          _isFavorite = true;
        } else {
          _isFavorite = null; // Mixed
        }

        // For playlists in bulk mode, we only show as "selected" if ALL songs are in it?
        // Actually, maybe it's better to show as selected if ANY song is in it, or use a tri-state.
        // Let's use ANY for simplicity in initialization, but maybe null for mixed.
        _selectedPlaylistIds = {};
        for (final pl in userData.playlists.where((p) => !p.isRecommendation)) {
          bool anyIn = false;
          for (final f in widget.songFilenames) {
            if (pl.songs.any((ps) => ps.songFilename == f)) {
              anyIn = true;
              break;
            }
          }
          if (anyIn) {
            _selectedPlaylistIds.add(pl.id);
          }
        }
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);
    final playlists =
        userData.playlists.where((p) => !p.isRecommendation).toList();

    return AlertDialog(
      title: Text(
          widget.songFilenames.length == 1 ? 'Add to...' : 'Bulk Add to...'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const AppIcon(AppIcons.add),
                title: const Text('New Playlist'),
                onTap: () {
                  _showNewPlaylistDialog(context, ref, widget.songFilenames);
                },
              ),
              const Divider(),
              _PickRow(
                title: 'Favorites',
                leading:
                    const AppIcon(AppIcons.favorite, color: AppTokens.danger),
                value: _isFavorite,
                onTap: () =>
                    setState(() => _isFavorite = !(_isFavorite ?? false)),
              ),
              const Divider(),
              ...playlists.map((playlist) {
                final isSelected = _selectedPlaylistIds.contains(playlist.id);
                // In bulk mode, we could also use tri-state for playlists
                bool allIn = true;
                bool anyIn = false;
                for (final f in widget.songFilenames) {
                  if (playlist.songs.any((ps) => ps.songFilename == f)) {
                    anyIn = true;
                  } else {
                    allIn = false;
                  }
                }

                return _PickRow(
                  title: playlist.name,
                  subtitle: '${playlist.songs.length} songs',
                  leading: const AppIcon(AppIcons.queue),
                  value: widget.songFilenames.length > 1
                      ? (allIn && isSelected
                          ? true
                          : (anyIn || isSelected ? null : false))
                      : isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedPlaylistIds.remove(playlist.id);
                      } else {
                        _selectedPlaylistIds.add(playlist.id);
                      }
                    });
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final notifier = ref.read(userDataProvider.notifier);
            final currentData = ref.read(userDataProvider);

            // Handle Favorites
            if (widget.songFilenames.length == 1) {
              if (_isFavorite !=
                  currentData.isFavorite(widget.songFilenames[0])) {
                await notifier.toggleFavorite(widget.songFilenames[0],
                    sync: false);
              }
            } else {
              if (_isFavorite == true) {
                await notifier.bulkToggleFavorite(widget.songFilenames, true);
              } else if (_isFavorite == false) {
                await notifier.bulkToggleFavorite(widget.songFilenames, false);
              }
            }

            // Handle Playlists
            for (final pl in playlists) {
              final isSelected = _selectedPlaylistIds.contains(pl.id);

              if (widget.songFilenames.length == 1) {
                final songFilename = widget.songFilenames[0];
                final wasIn =
                    pl.songs.any((ps) => ps.songFilename == songFilename);
                if (isSelected && !wasIn) {
                  await notifier.addSongToPlaylist(pl.id, songFilename,
                      sync: false);
                } else if (!isSelected && wasIn) {
                  await notifier.removeSongFromPlaylist(pl.id, songFilename,
                      sync: false);
                }
              } else {
                // Bulk mode
                // If isSelected is true, ensure ALL are in
                if (isSelected) {
                  final songsToAdd = widget.songFilenames
                      .where((f) => !pl.songs.any((ps) => ps.songFilename == f))
                      .toList();
                  if (songsToAdd.isNotEmpty) {
                    await notifier.bulkAddSongsToPlaylist(pl.id, songsToAdd);
                  }
                } else {
                  // If isSelected is false, ensure NONE are in
                  final songsToRemove = widget.songFilenames
                      .where((f) => pl.songs.any((ps) => ps.songFilename == f))
                      .toList();
                  if (songsToRemove.isNotEmpty) {
                    await notifier.bulkRemoveSongsFromPlaylist(
                        pl.id, songsToRemove);
                  }
                }
              }
            }

            if (context.mounted) {
              Navigator.pop(context);
              appSnack(context, 'Updated selections');
            }
          },
          child: const Text('Done'),
        ),
      ],
    );
  }

  void _showNewPlaylistDialog(
      BuildContext context, WidgetRef ref, List<String> songFilenames) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Playlist Name'),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _createNewPlaylistAndAdd(
                  context, ref, value.trim(), songFilenames);
              Navigator.pop(dialogContext);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _createNewPlaylistAndAdd(context, ref, name, songFilenames);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createNewPlaylistAndAdd(BuildContext context, WidgetRef ref,
      String name, List<String> songFilenames) async {
    final notifier = ref.read(userDataProvider.notifier);
    if (songFilenames.length == 1) {
      await notifier.createPlaylist(name, songFilenames[0]);
    } else {
      await notifier.createPlaylist(name);
      final userPlaylists = ref
          .read(userDataProvider)
          .playlists
          .where((p) => !p.isRecommendation)
          .toList();
      final newPlaylist = userPlaylists.isNotEmpty ? userPlaylists.first : null;
      if (newPlaylist != null) {
        await notifier.bulkAddSongsToPlaylist(newPlaylist.id, songFilenames);
        setState(() {
          _selectedPlaylistIds.add(newPlaylist.id);
        });
      }
    }
    if (context.mounted) {
      appSnack(context, 'Created playlist "$name"');
    }
  }
}

/// Selectable row whose check springs in and whose wash fades, so toggling a
/// playlist feels like a response rather than a checkbox repaint. A null
/// [value] is the bulk "some songs already here" state.
class _PickRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget leading;
  final bool? value;
  final VoidCallback onTap;

  const _PickRow({
    required this.title,
    this.subtitle,
    required this.leading,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;
    final bool on = value ?? false;
    final bool partial = value == null;
    return Pressable(
      haptic: PressHaptic.selection,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTokens.dBase,
        curve: AppTokens.cStandard,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s3,
          vertical: AppTokens.s3,
        ),
        decoration: BoxDecoration(
          borderRadius: AppTokens.brMd,
          color: on || partial
              ? accent.withValues(alpha: AppTokens.accentWashAlpha)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppTokens.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.rowTitle(context),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      style: AppTokens.rowSubtitle(context),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: AppTokens.iconLg,
              height: AppTokens.iconLg,
              child: AnimatedSwitcher(
                duration: AppTokens.dBase,
                switchInCurve: AppTokens.cSpring,
                switchOutCurve: AppTokens.cStandard,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Container(
                  key: ValueKey<bool?>(value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on || partial
                        ? accent
                        : AppTokens.fg(AppTokens.surface2Alpha),
                  ),
                  child: on || partial
                      ? Icon(
                          partial ? Icons.remove_rounded : Icons.check_rounded,
                          size: AppTokens.iconSm,
                          color: AppTokens.onAccent(accent),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
