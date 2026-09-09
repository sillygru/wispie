import 'dart:io';
import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../models/song.dart';
import '../../models/shuffle_config.dart';
import '../../providers/artist_album_art_provider.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../services/audio_player_manager.dart';
import '../../services/library_logic.dart';
import '../widgets/folder_options_menu.dart';
import '../widgets/folder_grid_image.dart';
import '../widgets/header_shuffle_button.dart';
import '../widgets/song_list_item.dart';
import '../widgets/sort_menu.dart';
import '../widgets/duration_display.dart';
import '../components/app_feedback.dart';
import '../components/app_list_row.dart';
import '../components/app_media_card.dart';
import '../components/app_screen_header.dart';
import '../components/app_surface.dart';
import '../components/scroll_chrome.dart';
import '../components/app_segmented_tabs.dart';
import '../components/app_sheet.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_tokens.dart';
import 'song_list_screen.dart';
import 'merged_songs_screen.dart';
import 'select_songs_screen.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../utils/wide_layout.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final String? relativePath;
  final ScrollController? scrollController;
  final int initialTabIndex;

  const LibraryScreen({
    super.key,
    this.relativePath,
    this.scrollController,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with ScrollChromeMixin {
  final TextEditingController _filterController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songsAsyncValue = ref.watch(songsProvider);
    final rootPathAsync = ref.watch(libraryRootPathProvider);
    final userData = ref.watch(userDataProvider);
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final settings = ref.watch(settingsProvider);
    final sortOrder = settings.sortOrder;
    final shuffleConfig = audioManager.shuffleStateNotifier.value.config;
    final playCounts = ref.watch(playCountsProvider);
    final lastPlayedAsync = ref.watch(lastPlayedTimestampsProvider);
    final lastPlayedTimestamps = lastPlayedAsync.asData?.value ?? const {};
    final isRoot = widget.relativePath == null;

    // The folder tab needs both the library and the folder it is rooted at, so
    // it stays on the loading state until both are known — never on an "empty"
    // one that reads as "you have no music".
    Widget buildFolderTab() {
      return songsAsyncValue.when(
        data: (allSongs) => rootPathAsync.when(
          data: (musicRoot) {
            if (musicRoot == null) {
              return const AppEmptyState(
                icon: AppIcons.folderOff,
                title: 'No music folder yet',
                message: 'Select a music folder in Home to fill this out.',
              );
            }
            return _buildFolderView(
              context,
              musicRoot,
              allSongs,
              userData,
              audioManager,
              sortOrder,
              shuffleConfig,
              lastPlayedTimestamps,
              playCounts,
            );
          },
          loading: () => const AppLoading(),
          error: (e, s) => AppEmptyState(
            icon: AppIcons.error,
            title: 'Could not find your music folder',
            message: '$e',
            tone: AppTone.danger,
          ),
        ),
        loading: () => const AppLoading(),
        error: (e, s) => AppEmptyState(
          icon: AppIcons.error,
          title: isRoot ? 'Could not load library' : 'Could not open folder',
          message: '$e',
          tone: AppTone.danger,
        ),
      );
    }

    if (!isRoot) {
      // Sub-folder screens own their own scaffold once content is available;
      // until then they still need chrome to hang the loading state on.
      final hasContent = songsAsyncValue.hasValue &&
          rootPathAsync.hasValue &&
          rootPathAsync.value != null;
      if (hasContent) return buildFolderTab();

      return AmbientScaffold(
        appBar: AppTopBar(title: widget.relativePath ?? 'Library'),
        body: buildFolderTab(),
      );
    }

    final navIntent = ref.watch(libraryNavigationProvider);
    final initialTabIndex =
        (navIntent?.subTabIndex ?? widget.initialTabIndex).clamp(0, 2);

    return DefaultTabController(
      length: 3,
      initialIndex: initialTabIndex,
      child: Consumer(
        builder: (context, ref, _) {
          ref.listen(libraryNavigationProvider, (previous, next) {
            if (next == null) return;
            final controller = DefaultTabController.of(context);
            if (controller.index != next.subTabIndex) {
              controller.animateTo(next.subTabIndex);
            }
          });

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: NestedScrollView(
              controller: widget.scrollController,
              // Required for the header's snap to work over the tab body —
              // without it the outer scroll won't float the sliver back in.
              floatHeaderSlivers: true,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                // Desktop keeps its toolbar pinned: the tabs and sort actions
                // stay put instead of snapping away mid-scroll.
                final wideHeader = WideLayout.isWide(context);
                return [
                  AppSliverHeader(
                    title: 'Library',
                    isScrolled: innerBoxIsScrolled,
                    floating: !wideHeader,
                    snap: !wideHeader,
                    pinned: wideHeader,
                    actions: [
                      songsAsyncValue.when(
                        data: (songs) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SortMenu(),
                            HeaderShuffleButton(
                              tooltip: 'Shuffle all',
                              onShufflePressed: () {
                                if (songs.isNotEmpty) {
                                  audioManager.shuffleAndPlay(songs,
                                      isRestricted: false);
                                }
                              },
                              onShuffleAfterSong: () {
                                if (songs.isNotEmpty) {
                                  audioManager.shuffleAfterCurrentSong(songs);
                                }
                              },
                              onShuffleAfterQueue: () {
                                if (songs.isNotEmpty) {
                                  audioManager.shuffleAfterCurrentQueue(songs);
                                }
                              },
                            ),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                    bottom: AppSegmentedTabs(
                      controller: DefaultTabController.of(context),
                      labels: const ['Folders', 'Artists', 'Albums'],
                      accent: AppTokens.accentOf(context, ref),
                    ),
                  ),
                ];
              },
              body: songsAsyncValue.when(
                data: (allSongs) => TabBarView(
                  children: [
                    buildFolderTab(),
                    _buildArtistsView(context, allSongs),
                    _buildAlbumsView(context, allSongs),
                  ],
                ),
                loading: () => const AppLoading(),
                error: (e, s) => AppEmptyState(
                  icon: AppIcons.error,
                  title: 'Could not load library',
                  message: '$e',
                  tone: AppTone.danger,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFolderView(
    BuildContext context,
    String musicRoot,
    List<Song> allSongs,
    UserDataState userData,
    AudioPlayerManager audioManager,
    SongSortOrder sortOrder,
    ShuffleConfig shuffleConfig,
    Map<String, double> lastPlayedTimestamps,
    Map<String, int> playCounts,
  ) {
    final currentFullPath = widget.relativePath == null
        ? musicRoot
        : p.join(musicRoot, widget.relativePath);

    final content = LibraryLogic.getFolderContent(
      allSongs: allSongs,
      currentFullPath: currentFullPath,
      sortOrder: sortOrder,
      userData: userData,
      shuffleConfig: shuffleConfig,
      playCounts: playCounts,
      lastPlayedTimestamps: lastPlayedTimestamps,
      affinities: ref.watch(songAffinitiesProvider).asData?.value,
    );

    final sortedSubFolders = content.subFolders;
    final immediateSongs = content.immediateSongs;
    final isRoot = widget.relativePath == null;
    final playlists =
        userData.playlists.where((p) => !p.isRecommendation).toList();
    final wideFolders = WideLayout.isWide(context);

    // Desktop-only inline filter. Narrow windows never show the field, so
    // `_filter` stays empty there and every list below is unfiltered.
    final query = _filter.trim().toLowerCase();
    bool matches(String text) =>
        query.isEmpty || text.toLowerCase().contains(query);
    final visiblePlaylists = query.isEmpty
        ? playlists
        : playlists.where((pl) => matches(pl.name)).toList();
    final visibleSubFolders = query.isEmpty
        ? sortedSubFolders
        : sortedSubFolders.where(matches).toList();
    final visibleSongs = query.isEmpty
        ? immediateSongs
        : immediateSongs
            .where((s) =>
                matches(s.title) || matches(s.artist) || matches(s.album))
            .toList();
    final showFavorites =
        isRoot && (query.isEmpty || 'favorites'.contains(query));
    final showMerged =
        isRoot && (query.isEmpty || 'merged songs'.contains(query));

    Widget folderIndexBuilder(BuildContext context, int index) {
      int cursor = index;

      // 1. Favorites Folder (at root only)
      if (showFavorites) {
        if (cursor == 0) {
          final favSongs =
              allSongs.where((s) => userData.isFavorite(s.filename)).toList();

          return _desktopRow(
            child: AppListRow(
              leading: const AppRowIcon(
                icon: AppIcons.favorite,
                color: AppTokens.danger,
              ),
              title: 'Favorites',
              subtitleWidget: CollectionDurationDisplay(
                songs: favSongs,
                showSongCount: true,
                compact: true,
              ),
              onTap: () {
                context.pushApp(
                  SongListScreen(title: 'Favorites', songs: favSongs),
                );
              },
            ),
          );
        }
        cursor -= 1;
      }

      // 2. Merged Songs Folder (at root only)
      if (showMerged) {
        if (cursor == 0) {
          final mergedCount = userData.mergedGroups.length;

          return _desktopRow(
            child: AppListRow(
              leading: AppRowIcon(
                icon: AppIcons.merge,
                color: AppTokens.accentOf(context, ref),
              ),
              title: 'Merged Songs',
              subtitle: '$mergedCount group${mergedCount != 1 ? 's' : ''}',
              trailing: IconButton(
                icon: const AppIcon(AppIcons.add),
                tooltip: 'Create new merge group',
                onPressed: () async {
                  final result = await context.pushApp<Map<String, dynamic>>(
                    SelectSongsScreen(
                      songs: allSongs,
                      title: 'Select Songs to Merge',
                    ),
                  );
                  if (result != null && context.mounted) {
                    final selected = result['filenames'] as List<String>;
                    final priority = result['priority'] as String?;
                    if (selected.length >= 2) {
                      try {
                        await ref
                            .read(userDataProvider.notifier)
                            .createMergedGroup(selected,
                                priorityFilename: priority);
                        if (context.mounted) {
                          appSnack(
                            context,
                            'Merged ${selected.length} songs',
                            tone: AppTone.success,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          appSnack(context, '$e', tone: AppTone.danger);
                        }
                      }
                    }
                  }
                },
              ),
              onTap: () {
                context.pushApp(const MergedSongsScreen());
              },
            ),
          );
        }
        cursor -= 1;
      }

      // 3. Playlists (at root only)
      if (isRoot) {
        if (cursor < visiblePlaylists.length) {
          final playlist = visiblePlaylists[cursor];
          final playlistSongs = allSongs
              .where((s) =>
                  playlist.songs.any((ps) => ps.songFilename == s.filename))
              .toList();
          void showPlaylistOptions() {
            showAppSheet(
              context,
              title: playlist.name,
              builder: (sheetContext) => AppSheetAction(
                icon: AppIcons.delete,
                label: 'Delete playlist',
                isDanger: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(userDataProvider.notifier)
                      .deletePlaylist(playlist.id);
                },
              ),
            );
          }

          // The playlist used to be marked by a 2px accent ring; the
          // collage now stands on its own.
          return _desktopRow(
            onSecondaryTap: showPlaylistOptions,
            child: AppListRow(
              leading: AppRowArt(
                child: FolderGridImage(songs: playlistSongs),
              ),
              title: playlist.name,
              subtitleWidget: CollectionDurationDisplay(
                songs: playlistSongs,
                showSongCount: true,
                compact: true,
              ),
              trailing: IconButton(
                icon: const AppIcon(AppIcons.moreVert),
                tooltip: 'Playlist options',
                onPressed: showPlaylistOptions,
              ),
              onTap: () {
                context.pushApp(
                  SongListScreen(
                    title: playlist.name,
                    songs: playlistSongs,
                    playlistId: playlist.id,
                  ),
                );
              },
            ),
          );
        }
        cursor -= visiblePlaylists.length;
      }

      if (cursor < visibleSubFolders.length) {
        final folderName = visibleSubFolders[cursor];
        final folderRelativePath = widget.relativePath == null
            ? folderName
            : p.join(widget.relativePath!, folderName);
        final folderSongs = content.subFolderSongs[folderName] ?? [];
        void showFolderOptions() {
          // Absolute, because the tree root is not necessarily the
          // first configured music folder any more.
          showFolderOptionsMenu(
              context, ref, folderName, p.join(currentFullPath, folderName));
        }

        return _desktopRow(
          onSecondaryTap: showFolderOptions,
          child: AppListRow(
            leading: AppRowArt(child: FolderGridImage(songs: folderSongs)),
            title: folderName,
            subtitleWidget: CollectionDurationDisplay(
              songs: folderSongs,
              showSongCount: true,
              compact: true,
            ),
            trailing: IconButton(
              icon: const AppIcon(AppIcons.moreVert),
              tooltip: 'Folder options',
              onPressed: showFolderOptions,
            ),
            onTap: () {
              context.pushApp(LibraryScreen(relativePath: folderRelativePath));
            },
          ),
        );
      }

      final songIndex = cursor - visibleSubFolders.length;
      final song = visibleSongs[songIndex];

      return _desktopRow(
        child: SongListItem(
          song: song,
          heroTagPrefix: 'library_${widget.relativePath ?? 'root'}',
          onTap: () {
            audioManager.playSong(song, contextQueue: visibleSongs);
          },
        ),
      );
    }

    final itemCount = (isRoot
            ? ((showFavorites ? 1 : 0) +
                (showMerged ? 1 : 0) +
                visiblePlaylists.length)
            : 0) +
        visibleSubFolders.length +
        visibleSongs.length;

    if (isRoot) {
      if (wideFolders) {
        return NotificationListener<ScrollNotification>(
          onNotification: handleScrollNotification,
          child: WideContentCenter(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _filterBar('Filter folders, playlists, songs...'),
                ),
                if (itemCount == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: query.isEmpty
                        ? const SizedBox.shrink()
                        : AppEmptyState(
                            icon: AppIcons.searchOff,
                            title: 'No matches',
                            message:
                                'Nothing in your library matches "${_filter.trim()}".',
                          ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.s4,
                      0,
                      AppTokens.s4,
                      AppTokens.scrollBottomInset,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 76,
                        crossAxisSpacing: AppTokens.s3,
                        mainAxisSpacing: AppTokens.s2,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            Center(child: folderIndexBuilder(context, index)),
                        childCount: itemCount,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      return NotificationListener<ScrollNotification>(
        onNotification: handleScrollNotification,
        child: WideContentCenter(
          child: ListView.builder(
            itemCount: itemCount,
            padding: const EdgeInsets.only(
              bottom: AppTokens.scrollBottomInset,
            ),
            itemBuilder: folderIndexBuilder,
          ),
        ),
      );
    } else {
      return AmbientScaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: handleScrollNotification,
          child: WideContentCenter(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                AppSliverHeader(
                  title: widget.relativePath ?? 'Library',
                  isScrolled: isScrolled,
                  large: false,
                  floating: !wideFolders,
                  snap: !wideFolders,
                  pinned: wideFolders,
                  actions: [
                    const SortMenu(),
                    if (content.allSongsInFolder.isNotEmpty)
                      IconButton(
                        icon: const AppIcon(AppIcons.shuffle),
                        tooltip: 'Shuffle folder',
                        onPressed: () => audioManager.shuffleAndPlay(
                          content.allSongsInFolder,
                          isRestricted: true,
                        ),
                      ),
                  ],
                ),
                if (wideFolders) ...[
                  SliverToBoxAdapter(child: _breadcrumbBar()),
                  SliverToBoxAdapter(
                    child: _filterBar('Filter folders, songs...'),
                  ),
                  if (itemCount == 0)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: query.isEmpty
                          ? const SizedBox.shrink()
                          : AppEmptyState(
                              icon: AppIcons.searchOff,
                              title: 'No matches',
                              message:
                                  'Nothing in this folder matches "${_filter.trim()}".',
                            ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.s4,
                        0,
                        AppTokens.s4,
                        AppTokens.scrollBottomInset,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 76,
                          crossAxisSpacing: AppTokens.s3,
                          mainAxisSpacing: AppTokens.s2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              Center(child: folderIndexBuilder(context, index)),
                          childCount: itemCount,
                        ),
                      ),
                    ),
                ] else ...[
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      folderIndexBuilder,
                      childCount: itemCount,
                    ),
                  ),
                  const SliverPadding(
                    padding:
                        EdgeInsets.only(bottom: AppTokens.scrollBottomInset),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
  }

  /// Desktop-only inline filter pill. Same vocabulary as the settings
  /// search field, so it reads as one app on wide windows.
  Widget _filterBar(String hint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s2,
        AppTokens.s4,
        AppTokens.s2,
      ),
      child: AppSurface(
        depth: AppDepth.well,
        borderRadius: AppTokens.brPill,
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
        child: Row(
          children: [
            const AppIcon(
              AppIcons.search,
              size: AppTokens.iconSm,
              color: AppTokens.fgTertiary,
            ),
            const SizedBox(width: AppTokens.s3),
            Expanded(
              child: TextField(
                controller: _filterController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: AppTokens.rowSubtitle(context),
                ),
                style: AppTokens.rowTitle(context),
                onChanged: (value) => setState(() => _filter = value),
              ),
            ),
            if (_filter.isNotEmpty)
              IconButton(
                icon: const AppIcon(AppIcons.close, size: AppTokens.iconSm),
                tooltip: 'Clear',
                onPressed: () {
                  _filterController.clear();
                  setState(() => _filter = '');
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Desktop-only breadcrumb for pushed sub-folders: each crumb pops back
  /// to its level instead of forcing repeated back gestures.
  Widget _breadcrumbBar() {
    final relative = widget.relativePath;
    if (relative == null || relative.isEmpty) {
      return const SizedBox.shrink();
    }
    final segments = p.split(relative);
    final crumbs = ['Library', ...segments];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s2,
        AppTokens.s4,
        0,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < crumbs.length; i++) ...[
            if (i > 0) ...[
              const AppIcon(
                AppIcons.chevronRight,
                size: AppTokens.iconSm,
                color: AppTokens.fgTertiary,
              ),
              const SizedBox(width: AppTokens.s1),
            ],
            if (i < crumbs.length - 1)
              GestureDetector(
                onTap: () {
                  final nav = Navigator.of(context);
                  final pops = crumbs.length - 1 - i;
                  for (var k = 0; k < pops; k++) {
                    nav.pop();
                  }
                },
                child: Text(
                  crumbs[i],
                  style: AppTokens.rowSubtitle(context).copyWith(
                    color: AppTokens.accentOf(context, ref),
                  ),
                ),
              )
            else
              Text(crumbs[i], style: AppTokens.rowTitle(context)),
            if (i < crumbs.length - 1) const SizedBox(width: AppTokens.s1),
          ],
        ],
      ),
    );
  }

  /// Desktop pointer affordances: hover wash, click cursor and right-click
  /// where a menu exists. Narrow windows get the row untouched.
  Widget _desktopRow({required Widget child, VoidCallback? onSecondaryTap}) {
    if (!WideLayout.isWide(context)) return child;
    final hovered = _HoverWash(child: child);
    final secondary = onSecondaryTap;
    if (secondary == null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: hovered,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTap: secondary,
        child: hovered,
      ),
    );
  }

  Widget _buildArtistsView(BuildContext context, List<Song> allSongs) {
    final artists = ref.watch(artistListProvider);
    final artistMap = ref.watch(artistMapProvider);

    return _buildCollectionGrid(
      keys: artists,
      songsFor: (artist) => artistMap[artist] ?? const [],
      subtitleFor: collectionSummary,
      emptyTitle: 'No artists yet',
      isArtist: true,
    );
  }

  Widget _buildAlbumsView(BuildContext context, List<Song> allSongs) {
    final albums = ref.watch(albumListProvider);
    final albumMap = ref.watch(albumMapProvider);

    return _buildCollectionGrid(
      keys: albums,
      songsFor: (album) => albumMap[album] ?? const [],
      subtitleFor: (songs) =>
          '${songs.first.artist} · ${collectionSummary(songs)}',
      emptyTitle: 'No albums yet',
      isAlbum: true,
    );
  }

  /// Artists and Albums are the same grid of cover collages with different
  /// labels underneath, so they are the same code.
  Widget _buildCollectionGrid({
    required List<String> keys,
    required List<Song> Function(String) songsFor,
    required String Function(List<Song>) subtitleFor,
    required String emptyTitle,
    bool isArtist = false,
    bool isAlbum = false,
  }) {
    final wideGrid = WideLayout.isWide(context);
    final gridQuery = _filter.trim().toLowerCase();
    final entries = keys
        .where(
            (key) => gridQuery.isEmpty || key.toLowerCase().contains(gridQuery))
        .map((key) => (key: key, songs: songsFor(key)))
        .where((entry) => entry.songs.isNotEmpty)
        .toList();

    if (entries.isEmpty) {
      if (wideGrid && gridQuery.isNotEmpty) {
        return Column(
          children: [
            _filterBar('Filter artists, albums...'),
            Expanded(
              child: AppEmptyState(
                icon: AppIcons.searchOff,
                title: 'No matches',
                message: 'Nothing here matches "${_filter.trim()}".',
              ),
            ),
          ],
        );
      }
      return AppEmptyState(
        icon: AppIcons.library,
        title: emptyTitle,
        message: 'Scan a music folder to fill this out.',
      );
    }

    final artState = ref.watch(artistAlbumArtProvider);
    final columns = WideLayout.gridColumns(context, base: wideGrid ? 3 : 2);

    Widget grid = GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s4,
        AppTokens.s4,
        AppTokens.scrollBottomInset,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 0.78,
        crossAxisSpacing: AppTokens.s4,
        mainAxisSpacing: AppTokens.s4,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final String? artistName = isArtist
            ? entry.key
            : (entry.songs.isNotEmpty ? entry.songs.first.artist : null);
        final String? albumName = isAlbum ? entry.key : null;

        final cachedArt = isArtist
            ? artState.getArtistArt(artistName)
            : (isAlbum
                ? artState.getAlbumArt(albumName, artistName: artistName)
                : null);

        final Widget artworkWidget = (cachedArt != null && cachedArt.isNotEmpty)
            ? ClipRRect(
                borderRadius: AppTokens.brSm,
                child: Image.file(
                  File(cachedArt),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: 350,
                  cacheHeight: 350,
                  errorBuilder: (_, __, ___) => FolderGridImage(
                    songs: entry.songs,
                    isGridItem: true,
                  ),
                ),
              )
            : FolderGridImage(songs: entry.songs, isGridItem: true);

        return AppMediaCard(
          expand: true,
          title: entry.key,
          subtitle: subtitleFor(entry.songs),
          artwork: artworkWidget,
          onTap: () => context.pushApp(
            SongListScreen(
              title: entry.key,
              songs: entry.songs,
              isArtist: isArtist,
              isAlbum: isAlbum,
              artistName: artistName,
              albumName: albumName,
            ),
          ),
        );
      },
    );

    if (wideGrid) {
      return Column(
        children: [
          _filterBar('Filter artists, albums...'),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: handleScrollNotification,
              child: grid,
            ),
          ),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: handleScrollNotification,
      child: grid,
    );
  }
}

/// Desktop pointer wash for library rows: the token-blessed hovered surface
/// (`surface(2)`), so mouse users get the same feedback a finger gets.
class _HoverWash extends StatefulWidget {
  final Widget child;

  const _HoverWash({required this.child});

  @override
  State<_HoverWash> createState() => _HoverWashState();
}

class _HoverWashState extends State<_HoverWash> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: AppTokens.dFast,
        curve: AppTokens.cStandard,
        decoration: BoxDecoration(
          color: _hovering ? AppTokens.surface(2) : Colors.transparent,
          borderRadius: AppTokens.brMd,
        ),
        child: widget.child,
      ),
    );
  }
}
