import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../widgets/collection_cover.dart';
import '../widgets/duration_display.dart';
import 'song_list_screen.dart';
import 'select_songs_screen.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';
import '../components/app_sheet.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../components/animated_removal.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songsProvider);
    final userData = ref.watch(userDataProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AmbientScaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.playlistsSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text(context.l10n.playlistsTitle),
        leading: _isSearching
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: const AppIcon(AppIcons.arrowBack),
              )
            : null,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
            icon: AppIcon(_isSearching ? AppIcons.close : AppIcons.search),
          ),
          IconButton(
            onPressed: () => _createPlaylist(context, ref, songsAsync),
            icon: const AppIcon(AppIcons.add),
            tooltip: context.l10n.playlistsCreate,
          ),
        ],
      ),
      body: songsAsync.when(
        data: (songs) {
          var playlists =
              userData.playlists.where((p) => !p.isRecommendation).toList();

          if (_searchQuery.isNotEmpty) {
            playlists = playlists
                .where((p) =>
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                .toList();
          }

          if (playlists.isEmpty && _searchQuery.isEmpty) {
            return _buildEmptyState(context, colorScheme, songsAsync);
          }

          if (playlists.isEmpty && _searchQuery.isNotEmpty) {
            return Center(
              child: Text(context.l10n.playlistsNoMatches),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final playlistSongs = songs
                  .where((s) =>
                      playlist.songs.any((ps) => ps.songFilename == s.filename))
                  .toList();

              return RemovableEntry(
                key: ValueKey<String>('playlist_${playlist.id}'),
                id: playlist.id,
                child: AppSurface(
                  padding: EdgeInsets.zero,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SongListScreen(
                            title: playlist.name,
                            songs: playlistSongs,
                            playlistId: playlist.id,
                          ),
                        ),
                      );
                    },
                    borderRadius: AppTokens.brMd,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: AppTokens.brSm,
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: CollectionCover(songs: playlistSongs),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                CollectionDurationDisplay(
                                  songs: playlistSongs,
                                  showSongCount: true,
                                  compact: true,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.playlistsCreatedOn(
                                    _formatDate(context, playlist.createdAt),
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showPlaylistOptions(
                              context,
                              ref,
                              playlist.id,
                              playlist.name,
                            ),
                            icon: const AppIcon(AppIcons.moreVert),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(context.l10n.songListMergeError('$e')),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ColorScheme colorScheme,
    AsyncValue<List<Song>> songsAsync,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(
            AppIcons.queue,
            size: 100,
            color: colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.playlistsEmptyTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.playlistsEmptyMessage,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _createPlaylist(context, ref, songsAsync),
            icon: const AppIcon(AppIcons.add),
            label: Text(context.l10n.playlistsCreate),
          ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Song>> songsAsync,
  ) async {
    final songs = songsAsync.value;
    if (songs == null || songs.isEmpty) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectSongsScreen(
          songs: songs,
          title: context.l10n.playlistsCreate,
          isMerging: false,
          actionLabel: context.l10n.playlistsCreate,
          minSelection: 1,
        ),
      ),
    );

    if (result != null && context.mounted) {
      final selected = result['filenames'] as List<String>;
      if (selected.isNotEmpty) {
        final name = await _showNameDialog(context);
        if (name != null && name.isNotEmpty && context.mounted) {
          await ref
              .read(userDataProvider.notifier)
              .createPlaylist(name, selected.first);
          // Add remaining songs
          for (int i = 1; i < selected.length; i++) {
            await ref.read(userDataProvider.notifier).addSongToPlaylist(
                  ref.read(userDataProvider).playlists.first.id,
                  selected[i],
                );
          }
        }
      }
    }
  }

  Future<String?> _showNameDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.playlistNameHint),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.playlistsNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.actionCreate),
          ),
        ],
      ),
    );
  }

  void _showPlaylistOptions(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
    String playlistName,
  ) {
    showAppSheet(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetAction(
            icon: AppIcons.edit,
            label: context.l10n.actionRename,
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context, ref, playlistId, playlistName);
            },
          ),
          AppSheetAction(
            icon: AppIcons.delete,
            label: context.l10n.actionDelete,
            isDanger: true,
            onTap: () {
              Navigator.pop(context);
              final notifier = ref.read(userDataProvider.notifier);
              AnimatedRemoval.run(
                playlistId,
                () => notifier.deletePlaylist(playlistId),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.songListRenamePlaylist),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.actionRename),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await ref
          .read(userDataProvider.notifier)
          .updatePlaylistName(playlistId, newName);
    }
  }

  String _formatDate(BuildContext context, double timestamp) {
    final date =
        DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt());
    final now = DateTime.now();
    final diff = now.difference(date);
    final l10n = context.l10n;

    if (diff.inDays == 0) return l10n.playlistsCreatedToday;
    if (diff.inDays == 1) return l10n.playlistsCreatedYesterday;
    if (diff.inDays < 7) return l10n.playlistsDaysAgo(diff.inDays);
    if (diff.inDays < 30) return l10n.playlistsWeeksAgo(diff.inDays ~/ 7);

    return '${date.month}/${date.year}';
  }
}
