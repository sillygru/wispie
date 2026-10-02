import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/song.dart';
import '../../providers/artist_album_art_provider.dart';
import '../../providers/providers.dart';
import '../../providers/selection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/audio_player_manager.dart';
import '../../services/color_extraction_service.dart';
import '../../services/library_logic.dart';
import '../../services/online_metadata_service.dart';
import '../../services/passive_art_fetcher_service.dart';
import '../components/app_dialog.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_sheet.dart';
import '../components/pop_icon.dart';
import '../components/song_actions.dart';
import '../routes/app_page_route.dart';
import '../screens/select_songs_screen.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import '../widgets/album_art_image.dart';
import '../widgets/album_card_selector.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/bulk_selection_bar.dart';
import '../widgets/duration_display.dart';
import '../widgets/song_options_menu.dart';
import '../widgets/sort_menu.dart';
import 'cover_blur_background.dart';
import 'cover_gradient_palette.dart';
import 'floating_mini_player.dart';
import 'glass_chrome.dart';

/// Shared artist/album/playlist layout over a continuous cover gradient.
///
/// Same data and actions as [SongListScreen], restructured over one continuous
/// clamped gradient with a floating glass top bar and floating mini player.
class GradientDetailScreen extends ConsumerStatefulWidget {
  final String title;
  final List<Song> songs;
  final String? playlistId;
  final bool isArtist;
  final bool isAlbum;
  final String? artistName;
  final String? albumName;

  const GradientDetailScreen({
    super.key,
    required this.title,
    required this.songs,
    this.playlistId,
    this.isArtist = false,
    this.isAlbum = false,
    this.artistName,
    this.albumName,
  });

  @override
  ConsumerState<GradientDetailScreen> createState() =>
      _GradientDetailScreenState();
}

class _GradientDetailScreenState extends ConsumerState<GradientDetailScreen> {
  String? _selectedAlbum;
  SongSortOrder? _localSort;
  final ScrollController _scroll = ScrollController();
  double _scrollOffset = 0;
  Color? _detailAccent;
  bool _detailNeutral = false;
  String _paletteKey = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final double offset = _scroll.offset;
    if ((offset - _scrollOffset).abs() < 2) return;
    setState(() => _scrollOffset = offset);
  }

  @override
  void didUpdateWidget(covariant GradientDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.artistName != widget.artistName ||
        oldWidget.albumName != widget.albumName ||
        oldWidget.playlistId != widget.playlistId) {
      _selectedAlbum = null;
      _localSort = null;
    }
  }

  static bool _looksLikeArtist(List<Song> songs, String title) {
    if (songs.isEmpty) return false;
    final String lowerTitle = title.toLowerCase();
    return songs.any(
      (s) =>
          s.artist.toLowerCase().contains(lowerTitle) ||
          lowerTitle.contains(s.artist.toLowerCase()),
    );
  }

  Future<void> _ensurePalette(String? artworkPath, List<Song> songs) async {
    final coverSong = LibraryLogic.pickCoverSong(songs);
    final String key = artworkPath ?? coverSong?.filename ?? '';
    if (key.isEmpty || key == _paletteKey) return;
    _paletteKey = key;
    // Prefer the header artwork; fall back to the collection's most-listened
    // cover.
    final String? path = (artworkPath == null || artworkPath.isEmpty)
        ? coverSong?.coverUrl
        : artworkPath;
    if (path == null || path.isEmpty) return;
    try {
      final palette = await ColorExtractionService.extractPalette(path);
      if (!mounted) return;
      if (palette == null) return;
      setState(() {
        _detailAccent = palette.color;
        _detailNeutral = palette.isNeutral;
      });
    } catch (_) {
      // Keep the theme accent fallback; background stays dark regardless.
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final selectionState = ref.watch(selectionProvider);
    final sortOrder = ref.watch(settingsProvider).sortOrder;
    final userData = ref.watch(userDataProvider);
    final shuffleConfig = audioManager.shuffleStateNotifier.value.config;
    final playCounts = ref.watch(playCountsProvider);
    final lastPlayedAsync = ref.watch(lastPlayedTimestampsProvider);
    final lastPlayedTimestamps = lastPlayedAsync.asData?.value ?? const {};

    final bool multiAlbumArtist = widget.playlistId == null &&
        (widget.isArtist || _looksLikeArtist(widget.songs, widget.title)) &&
        !widget.isAlbum &&
        LibraryLogic.hasMultipleAlbums(widget.songs);

    final SongSortOrder effectiveSortOrder =
        multiAlbumArtist ? (_localSort ?? SongSortOrder.playCount) : sortOrder;

    final List<Song> sortedSongs = LibraryLogic.sortSongs(
      widget.songs,
      effectiveSortOrder,
      userData: userData,
      shuffleConfig: shuffleConfig,
      playCounts: playCounts,
      lastPlayedTimestamps: lastPlayedTimestamps,
    );

    final bool effectiveIsArtist = widget.isArtist ||
        (widget.playlistId == null &&
            !widget.isAlbum &&
            sortedSongs.isNotEmpty &&
            sortedSongs.any(
              (s) =>
                  s.artist.toLowerCase().contains(widget.title.toLowerCase()) ||
                  widget.title.toLowerCase().contains(s.artist.toLowerCase()),
            ));

    final bool effectiveIsAlbum = widget.isAlbum ||
        (widget.playlistId == null &&
            !effectiveIsArtist &&
            sortedSongs.isNotEmpty &&
            sortedSongs.any(
              (s) =>
                  s.album.toLowerCase().contains(widget.title.toLowerCase()) ||
                  widget.title.toLowerCase().contains(s.album.toLowerCase()),
            ));

    final String effectiveArtistName = (widget.artistName ??
            (effectiveIsArtist
                ? widget.title
                : (sortedSongs.isNotEmpty ? sortedSongs.first.artist : '')))
        .trim();

    final String effectiveAlbumName = (widget.albumName ??
            (effectiveIsAlbum
                ? widget.title
                : (sortedSongs.isNotEmpty
                    ? sortedSongs.first.album
                    : widget.title)))
        .trim();

    final String? artworkPath = effectiveIsArtist
        ? ref.watch(artistAlbumArtProvider).getArtistArt(effectiveArtistName)
        : (effectiveIsAlbum
            ? ref.watch(artistAlbumArtProvider).getAlbumArt(
                  effectiveAlbumName,
                  artistName: effectiveArtistName,
                )
            : null);

    final bool hasCustomArtwork =
        artworkPath != null && File(artworkPath).existsSync();

    if (effectiveIsArtist && !hasCustomArtwork) {
      PassiveArtFetcherService.instance.fetchArtistArtIfNeeded(
        effectiveArtistName,
      );
    } else if (effectiveIsAlbum && !hasCustomArtwork) {
      PassiveArtFetcherService.instance.fetchAlbumArtIfNeeded(
        effectiveAlbumName,
        effectiveArtistName,
      );
    }

    final bool isUnknownArtistOrAlbum = (effectiveIsArtist &&
            OnlineMetadataService.cleanTag(effectiveArtistName) == null) ||
        (effectiveIsAlbum &&
            OnlineMetadataService.cleanTag(effectiveAlbumName) == null) ||
        widget.title.toLowerCase() == 'unknown artist' ||
        widget.title.toLowerCase() == 'unknown album';

    final bool showAlbumGroups = effectiveIsArtist &&
        widget.playlistId == null &&
        LibraryLogic.hasMultipleAlbums(widget.songs);
    final Map<String, List<Song>> albumGroups = showAlbumGroups
        ? LibraryLogic.groupSongsByAlbum(widget.songs)
        : const {};
    final List<String> orderedAlbums = showAlbumGroups
        ? LibraryLogic.sortAlbumsByTotalPlays(
            albumGroups,
            playCounts: playCounts,
          )
        : const [];
    final String? selectedAlbum = showAlbumGroups &&
            _selectedAlbum != null &&
            albumGroups.containsKey(_selectedAlbum)
        ? _selectedAlbum
        : null;
    List<Song> visibleSongs = sortedSongs;
    if (showAlbumGroups && selectedAlbum != null) {
      final Set<String> allowed =
          albumGroups[selectedAlbum]!.map((s) => s.filename).toSet();
      visibleSongs =
          sortedSongs.where((s) => allowed.contains(s.filename)).toList();
    }

    final themeAccent = ref.watch(themeProvider).extractedColor ??
        Theme.of(context).colorScheme.primary;
    final bool themeNeutral =
        ref.watch(themeProvider.select((t) => t.isNeutralCover));
    final Color baseAccent = _detailAccent ?? themeAccent;
    final bool baseNeutral =
        _detailAccent != null ? _detailNeutral : themeNeutral;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensurePalette(hasCustomArtwork ? artworkPath : null, sortedSongs);
      }
    });

    final List<Color> gradient =
        CoverGradientPalette.detailGradient(baseAccent, isNeutral: baseNeutral);

    final bool canFetchCover = widget.playlistId == null;
    void handleFetchCover() {
      if (effectiveIsArtist) {
        _showChangeArtistArtworkDialog(
            context, ref, effectiveArtistName, sortedSongs);
      } else if (effectiveIsAlbum) {
        _showChangeAlbumArtworkDialog(
            context, ref, effectiveAlbumName, effectiveArtistName, sortedSongs);
      } else {
        _showChangeArtistArtworkDialog(context, ref, widget.title, sortedSongs);
      }
    }

    // Big title visible until scrolled past the header (~220px).
    final bool showBarTitle = _scrollOffset > 230;

    // Immersive background: blurred header artwork so the whole page feels
    // tinted like the iOS reference, still clamped dark for white text.
    // Falls back to the flat gradient when no cover resolves.
    final Song? firstSong = LibraryLogic.pickCoverSong(sortedSongs);
    final String? customArt = artworkPath;
    String bgUrl = firstSong?.coverUrl ?? '';
    String bgKey = firstSong?.filename ?? widget.title;
    if (hasCustomArtwork && customArt != null) {
      bgUrl = customArt;
      bgKey = customArt;
    }

    return PopScope(
      canPop: !selectionState.isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (selectionState.isSelectionMode) {
          ref.read(selectionProvider.notifier).exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: bgUrl.isNotEmpty
                  ? CoverBlurBackground(
                      coverUrl: bgUrl,
                      filename: bgKey,
                      accent: baseAccent,
                      isNeutral: baseNeutral,
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: gradient,
                        ),
                      ),
                    ),
            ),
            // Near-black fade behind the content's top region: the joint
            // where the cover's opaque black bottom meets the background
            // lands inside it, so both sides read the same and no line can
            // draw. Static and screen-sized; scrolling rows simply travel
            // through it. Detail-only.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.78),
                        Colors.black.withValues(alpha: 0.78),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                      stops: const <double>[0.0, 0.52, 0.72],
                    ),
                  ),
                ),
              ),
            ),

            WideContentCenter(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(
                    child: _Header(
                      title: widget.title,
                      visibleSongs: visibleSongs,
                      sortedSongs: sortedSongs,
                      artworkPath: hasCustomArtwork ? artworkPath : null,
                      canFetchCover: canFetchCover,
                      onArtworkTap: handleFetchCover,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Actions(
                      visibleSongs: visibleSongs,
                      sortedSongs: sortedSongs,
                      playlistId: widget.playlistId,
                      isUnknown: isUnknownArtistOrAlbum,
                    ),
                  ),
                  if (showAlbumGroups)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: AppTokens.s4, bottom: AppTokens.s1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppTokens.s4),
                              child: Text(
                                'Albums',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppTokens.s2),
                            AlbumCardSelector(
                              allSongs: widget.songs,
                              albums: orderedAlbums,
                              albumGroups: albumGroups,
                              selected: selectedAlbum,
                              artistName: effectiveArtistName,
                              onSelected: (album) =>
                                  setState(() => _selectedAlbum = album),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (visibleSongs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No songs in this list',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final Song song = visibleSongs[index];
                          return _GradientSongRow(
                            song: song,
                            accent: baseAccent,
                            playlistId: widget.playlistId,
                            heroTagPrefix: 'gradient_${widget.title}',
                            visibleSongs: visibleSongs,
                          );
                        },
                        childCount: visibleSongs.length,
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 150)),
                ],
              ),
            ),
            // Floating transparent top bar with glass icon backings.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _FloatingTopBar(
                title: widget.title,
                showTitle: showBarTitle,
                effectiveSortOrder: effectiveSortOrder,
                showAlbumGroups: showAlbumGroups,
                isUnknown: isUnknownArtistOrAlbum,
                canFetchCover: canFetchCover,
                effectiveIsArtist: effectiveIsArtist,
                effectiveIsAlbum: effectiveIsAlbum,
                playlistId: widget.playlistId,
                sortedSongs: sortedSongs,
                visibleSongs: visibleSongs,
                onLocalSort: (order) => setState(() => _localSort = order),
                onFetchCover: handleFetchCover,
                onPlaylistOptions: () => _showPlaylistOptions(context, ref),
                onMerge: () => _onMerge(context, ref, sortedSongs),
                onFetchMissing: () => songActionFetchMissingMetadataForList(
                    context, ref, sortedSongs),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: selectionState.isSelectionMode
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: BulkSelectionBar(),
                      )
                    : const FloatingGlassMiniPlayer(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context, WidgetRef ref) {
    if (widget.playlistId == null) return;
    showAppSheet(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetAction(
            icon: AppIcons.edit,
            label: 'Rename',
            onTap: () {
              Navigator.pop(sheetContext);
              _showRenameDialog(context, ref);
            },
          ),
          AppSheetAction(
            icon: AppIcons.delete,
            label: 'Delete',
            isDanger: true,
            onTap: () {
              Navigator.pop(sheetContext);
              _showDeleteConfirmation(context, ref);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    if (widget.playlistId == null) return;
    final String? newName = await showAppTextPrompt(
      context,
      title: 'Rename Playlist',
      initialValue: widget.title,
      confirmLabel: 'Rename',
    );
    if (newName != null && newName != widget.title) {
      ref
          .read(userDataProvider.notifier)
          .updatePlaylistName(widget.playlistId!, newName);
    }
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context, WidgetRef ref) async {
    if (widget.playlistId == null) return;
    final bool? confirmed = await showAppConfirm(
      context,
      title: 'Delete Playlist',
      message: 'Are you sure you want to delete "${widget.title}"?',
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (confirmed == true && context.mounted) {
      ref.read(userDataProvider.notifier).deletePlaylist(widget.playlistId!);
      Navigator.pop(context);
    }
  }

  Future<void> _onMerge(
      BuildContext context, WidgetRef ref, List<Song> sortedSongs) async {
    final Map<String, Object?>? result =
        await context.pushApp<Map<String, Object?>>(
      SelectSongsScreen(songs: sortedSongs, title: 'Select Songs to Merge'),
    );
    if (result != null && context.mounted) {
      final Object? raw = result['filenames'];
      final Object? priority = result['priority'];
      if (raw is List<String> && raw.length >= 2) {
        try {
          await ref.read(userDataProvider.notifier).createMergedGroup(
                raw,
                priorityFilename: priority is String ? priority : null,
              );
          if (context.mounted) {
            appSnack(context, 'Merged ${raw.length} songs');
          }
        } catch (e) {
          if (context.mounted) appSnack(context, 'Error: $e');
        }
      }
    }
  }

  Future<void> _showChangeArtistArtworkDialog(
    BuildContext context,
    WidgetRef ref,
    String artist,
    List<Song> songs,
  ) async {
    appSnack(context, 'Searching online for $artist artwork...');
    final onlineService = OnlineMetadataService.instance;
    final List<Map<String, String>> results = <Map<String, String>>[];
    try {
      results.addAll(await onlineService.searchArtistImageCandidates(artist));
    } catch (_) {}
    if (!context.mounted) return;
    final String? selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Select Artwork for $artist'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const AppIcon(AppIcons.musicNote),
                title: const Text('Use Song Cover Grid'),
                subtitle: const Text('Remove custom artwork'),
                onTap: () => Navigator.pop(dialogContext, 'reset'),
              ),
              ListTile(
                leading: const AppIcon(AppIcons.image),
                title: const Text('Choose Custom Image'),
                subtitle: const Text('Select image from device storage'),
                onTap: () => Navigator.pop(dialogContext, 'custom'),
              ),
              if (results.isNotEmpty) const Divider(),
              ...results.map(
                (res) => ListTile(
                  leading: Image.network(
                    res['url'] ?? '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const AppIcon(AppIcons.image),
                  ),
                  title: Text('Artwork from ${res['source']}'),
                  subtitle: Text(
                    res['url'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(dialogContext, res['url']),
                ),
              ),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No online artwork options found'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    if (selected == 'reset') {
      await ref.read(artistAlbumArtProvider.notifier).removeArtistArt(artist);
      if (context.mounted) appSnack(context, 'Reset to song cover grid');
      return;
    }
    if (selected == 'custom') {
      final picked = await FilePicker.pickFile(type: FileType.image);
      final String? localPath = picked?.path;
      if (localPath != null) {
        await ref.read(artistAlbumArtProvider.notifier).setArtistArt(
              artistName: artist,
              localPath: localPath,
              source: 'custom',
            );
        if (context.mounted) {
          appSnack(context, 'Updated artwork for $artist');
        }
      }
      return;
    }
    if (context.mounted) appSnack(context, 'Downloading artwork...');
    final String? localPath = await onlineService.downloadAndCacheCover(
      selected,
      'artist_$artist',
    );
    if (localPath != null && context.mounted) {
      await ref.read(artistAlbumArtProvider.notifier).setArtistArt(
            artistName: artist,
            localPath: localPath,
            imageUrl: selected,
            source: 'online',
          );
      if (context.mounted) {
        appSnack(context, 'Updated artwork for $artist');
      }
    } else if (context.mounted) {
      appSnack(context, 'Failed to download artwork');
    }
  }

  Future<void> _showChangeAlbumArtworkDialog(
    BuildContext context,
    WidgetRef ref,
    String album,
    String artist,
    List<Song> songs,
  ) async {
    appSnack(context, 'Searching online for $album artwork...');
    final onlineService = OnlineMetadataService.instance;
    final String compositeKey = artist.isNotEmpty ? '$artist|$album' : album;
    final List<Map<String, String>> results = <Map<String, String>>[];
    try {
      results.addAll(
        await onlineService.searchAlbumImageCandidates(album,
            artistName: artist),
      );
    } catch (_) {}
    if (!context.mounted) return;
    final String? selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Select Artwork for $album'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const AppIcon(AppIcons.musicNote),
                title: const Text('Use Song Cover Grid'),
                subtitle: const Text('Remove custom artwork'),
                onTap: () => Navigator.pop(dialogContext, 'reset'),
              ),
              ListTile(
                leading: const AppIcon(AppIcons.image),
                title: const Text('Choose Custom Image'),
                subtitle: const Text('Select image from device storage'),
                onTap: () => Navigator.pop(dialogContext, 'custom'),
              ),
              if (results.isNotEmpty) const Divider(),
              ...results.map(
                (res) => ListTile(
                  leading: Image.network(
                    res['url'] ?? '',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const AppIcon(AppIcons.image),
                  ),
                  title: Text('Artwork from ${res['source']}'),
                  subtitle: Text(
                    res['url'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(dialogContext, res['url']),
                ),
              ),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No online artwork options found'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    if (selected == 'reset') {
      await ref
          .read(artistAlbumArtProvider.notifier)
          .removeAlbumArt(compositeKey);
      if (context.mounted) appSnack(context, 'Reset to song cover grid');
      return;
    }
    if (selected == 'custom') {
      final picked = await FilePicker.pickFile(type: FileType.image);
      final String? localPath = picked?.path;
      if (localPath != null) {
        await ref.read(artistAlbumArtProvider.notifier).setAlbumArt(
              albumKey: compositeKey,
              albumName: album,
              artistName: artist.isNotEmpty ? artist : null,
              localPath: localPath,
              source: 'custom',
            );
        if (context.mounted) {
          appSnack(context, 'Updated artwork for $album');
        }
      }
      return;
    }
    if (context.mounted) appSnack(context, 'Downloading artwork...');
    final String? localPath = await onlineService.downloadAndCacheCover(
      selected,
      'album_$compositeKey',
    );
    if (localPath != null && context.mounted) {
      await ref.read(artistAlbumArtProvider.notifier).setAlbumArt(
            albumKey: compositeKey,
            albumName: album,
            artistName: artist.isNotEmpty ? artist : null,
            localPath: localPath,
            imageUrl: selected,
            source: 'online',
          );
      if (context.mounted) {
        appSnack(context, 'Updated artwork for $album');
      }
    } else if (context.mounted) {
      appSnack(context, 'Failed to download artwork');
    }
  }
}

class _Header extends StatelessWidget {
  final String title;
  final List<Song> visibleSongs;
  final List<Song> sortedSongs;
  final String? artworkPath;
  final bool canFetchCover;
  final VoidCallback onArtworkTap;

  const _Header({
    required this.title,
    required this.visibleSongs,
    required this.sortedSongs,
    required this.artworkPath,
    required this.canFetchCover,
    required this.onArtworkTap,
  });

  @override
  Widget build(BuildContext context) {
    // Full-bleed immersive cover like the player: full screen width starting
    // at the very top under the status bar, no margins or rounded corners,
    // fading into the blurred background with the title over its lower edge.
    final double screenH = MediaQuery.sizeOf(context).height;
    final double coverH = (screenH * 0.44).clamp(260.0, 460.0);
    final String? customArt = artworkPath;
    final Song? firstSong = LibraryLogic.pickCoverSong(sortedSongs);
    final String firstCover = firstSong?.coverUrl ?? '';

    Widget art;
    if (customArt != null) {
      art = Image.file(
        File(customArt),
        width: double.infinity,
        height: coverH,
        fit: BoxFit.cover,
        cacheWidth: 900,
        cacheHeight: 900,
        errorBuilder: (_, __, ___) => Container(color: Colors.black),
      );
    } else if (firstCover.isNotEmpty) {
      art = AlbumArtImage(
        url: firstCover,
        filename: firstSong?.filename,
        cacheVersion: firstSong?.mtime,
        width: MediaQuery.sizeOf(context).width,
        height: coverH,
        memCacheWidth: (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .round(),
        fit: BoxFit.cover,
      );
    } else {
      art = Container(color: Colors.black);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canFetchCover ? onArtworkTap : null,
          onLongPress: canFetchCover ? onArtworkTap : null,
          child: SizedBox(
            width: double.infinity,
            height: coverH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                art,
                // Dissolve the photo into opaque black: the bottom lands on
                // the same near-black as the page background, so the joint
                // below the title cannot draw an edge the way a transparency
                // fade over mottled blur did.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xCC000000),
                          Color(0xF2000000),
                        ],
                        stops: <double>[0.0, 0.4, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
                // Title + count overlap the lower edge with a wash for
                // legibility, mirroring the player info block hierarchy.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Color(0x66000000),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTokens.screenTitle(context).copyWith(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                        if (visibleSongs.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          CollectionDurationDisplay(
                            songs: visibleSongs,
                            showSongCount: true,
                            compact: true,
                            style: AppTokens.meta(context).copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Fade tail: continues the cover's black dissolve past its edge so
        // the photo meets the page with no cutoff line.
        Container(
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xF2000000), Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.s1),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  final List<Song> visibleSongs;
  final List<Song> sortedSongs;
  final String? playlistId;
  final bool isUnknown;

  const _Actions({
    required this.visibleSongs,
    required this.sortedSongs,
    required this.playlistId,
    required this.isUnknown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final Color accent = AppTokens.accentOf(context, ref);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = visibleSongs.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTokens.s4, AppTokens.s2, AppTokens.s4, AppTokens.s2),
      child: Column(
        children: [
          // Circular actions instead of pills: big accent Play beside a
          // smaller tonal Shuffle, centered. Same icons, same callbacks,
          // flat with no glow.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleAction(
                size: 52,
                iconSize: 24,
                tooltip: 'Shuffle',
                background: scheme.secondaryContainer,
                foreground: scheme.onSecondaryContainer,
                icon: AppIcons.shuffle,
                enabled: enabled,
                onTap: () {
                  audioManager.shuffleAndPlay(
                    visibleSongs,
                    isRestricted: true,
                  );
                },
              ),
              const SizedBox(width: AppTokens.s4),
              _CircleAction(
                size: 72,
                iconSize: 32,
                tooltip: 'Play',
                background: accent,
                foreground: AppTokens.onAccent(accent),
                icon: AppIcons.play,
                enabled: enabled,
                onTap: () {
                  audioManager.replaceQueue(
                    visibleSongs,
                    playlistId: playlistId,
                    forceLinear: true,
                    clearCurrentSong: true,
                  );
                },
              ),
            ],
          ),
          if (isUnknown && sortedSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.s2),
              child: OutlinedButton.icon(
                onPressed: () => songActionFetchMissingMetadataForList(
                    context, ref, sortedSongs),
                icon: const AppIcon(AppIcons.manageSearch),
                label: const Text('Fetch Missing Metadata'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular tap target for the detail actions. Detail-only variant reusing
/// the app's own icon set; callbacks match the legacy pills exactly.
class _CircleAction extends StatelessWidget {
  final double size;
  final double iconSize;
  final String tooltip;
  final Color background;
  final Color foreground;
  final AppIconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CircleAction({
    required this.size,
    required this.iconSize,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg =
        enabled ? background : Colors.white.withValues(alpha: 0.08);
    final Color fg =
        enabled ? foreground : Colors.white.withValues(alpha: 0.35);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          alignment: Alignment.center,
          child: AppIcon(icon, color: fg, size: iconSize),
        ),
      ),
    );
  }
}

/// Transparent song row for the gradient detail: same content as the legacy
/// list item (artwork, title, artist, duration, heart, play-count, menu)
/// painted directly on the gradient with an accent wash when active.
class _GradientSongRow extends ConsumerWidget {
  final Song song;
  final Color accent;
  final String? playlistId;
  final String heroTagPrefix;
  final List<Song> visibleSongs;

  const _GradientSongRow({
    required this.song,
    required this.accent,
    required this.playlistId,
    required this.heroTagPrefix,
    required this.visibleSongs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userDataProvider);
    final settings = ref.watch(settingsProvider);
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final selectionState = ref.watch(selectionProvider);
    final bool isSelected =
        selectionState.selectedFilenames.contains(song.filename);
    final bool isFavorite = userData.isFavorite(song.filename);
    final bool isSuggestLess = userData.isSuggestLess(song.filename);
    final String heroTag = '${heroTagPrefix}_${song.filename}';

    return ValueListenableBuilder<Song?>(
      valueListenable: audioManager.currentSongNotifier,
      builder: (context, currentSong, _) {
        final bool isActive = currentSong?.filename == song.filename;
        return Container(
          color: isSelected || isActive
              ? accent.withValues(alpha: 0.14)
              : Colors.transparent,
          child: Opacity(
            opacity: isSuggestLess ? 0.55 : 1.0,
            child: InkWell(
              onTap: selectionState.isSelectionMode
                  ? () => ref
                      .read(selectionProvider.notifier)
                      .toggleSelection(song.filename)
                  : () {
                      audioManager.playSong(
                        song,
                        contextQueue: visibleSongs,
                        playlistId: playlistId,
                      );
                    },
              onLongPress: () {
                if (!selectionState.isSelectionMode) {
                  ref
                      .read(selectionProvider.notifier)
                      .enterSelectionMode(song.filename);
                  HapticFeedback.heavyImpact();
                } else {
                  showSongOptionsMenu(context, ref, song.filename, song.title,
                      song: song, playlistId: playlistId);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s3,
                  vertical: AppTokens.s2,
                ),
                child: Row(
                  children: [
                    _RowArtwork(
                      song: song,
                      heroTag: heroTag,
                      accent: accent,
                      isSelected: isSelected,
                      isActive: isActive,
                      audioManager: audioManager,
                      visualizerMode: settings.visualizerMode,
                    ),
                    const SizedBox(width: AppTokens.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTokens.rowTitle(context).copyWith(
                              color: Colors.white,
                              decoration: isSuggestLess
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      AppTokens.rowSubtitle(context).copyWith(
                                    color: Colors.white.withValues(alpha: 0.62),
                                  ),
                                ),
                              ),
                              if (settings.showSongDuration &&
                                  song.duration != null &&
                                  song.duration!.inSeconds > 0) ...[
                                const SizedBox(width: AppTokens.s2),
                                DurationBadge(
                                  duration: song.duration,
                                  isSubtle: true,
                                  showIcon: false,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!selectionState.isSelectionMode) ...[
                      if (song.playCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(
                                alpha: AppTokens.accentWashAlpha),
                            borderRadius: AppTokens.brPill,
                          ),
                          child: Text(
                            '${song.playCount}',
                            style: AppTokens.meta(context).copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      PopIcon(
                        isActive: isFavorite,
                        activeColor: accent,
                        inactiveColor: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                        onTap: () => ref
                            .read(userDataProvider.notifier)
                            .toggleFavorite(song.filename),
                      ),
                      IconButton(
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        icon: AppIcon(
                          AppIcons.moreVert,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                        onPressed: () {
                          showSongOptionsMenu(
                            context,
                            ref,
                            song.filename,
                            song.title,
                            song: song,
                            playlistId: playlistId,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RowArtwork extends StatelessWidget {
  final Song song;
  final String heroTag;
  final Color accent;
  final bool isSelected;
  final bool isActive;
  final AudioPlayerManager audioManager;
  final VisualizerMode visualizerMode;

  const _RowArtwork({
    required this.song,
    required this.heroTag,
    required this.accent,
    required this.isSelected,
    required this.isActive,
    required this.audioManager,
    required this.visualizerMode,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppTokens.artSize,
      height: AppTokens.artSize,
      child: Stack(
        children: [
          Hero(
            tag: heroTag,
            child: ClipRRect(
              borderRadius: AppTokens.brSm,
              child: AlbumArtImage(
                url: song.coverUrl ?? '',
                filename: song.filename,
                width: AppTokens.artSize,
                height: AppTokens.artSize,
                fit: BoxFit.cover,
                memCacheWidth: 104,
                memCacheHeight: 104,
              ),
            ),
          ),
          if (isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.72),
                  borderRadius: AppTokens.brSm,
                ),
                child: AppIcon(
                  AppIcons.tick,
                  color: AppTokens.onAccent(accent),
                  size: 26,
                ),
              ),
            )
          else if (isActive)
            Positioned.fill(
              child: StreamBuilder<PlayerState>(
                stream: audioManager.player.playerStateStream,
                builder: (context, snapshot) {
                  final bool playing = snapshot.data?.playing ?? false;
                  if (!playing) return const SizedBox.shrink();
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: AppTokens.brSm,
                    ),
                    child: Center(
                      child: visualizerMode != VisualizerMode.off
                          ? AudioVisualizer(
                              color: Colors.white,
                              width: 22,
                              height: 22,
                              isPlaying: true,
                              mode: visualizerMode,
                            )
                          : const AppIcon(AppIcons.graphicEq,
                              color: Colors.white, size: 22),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingTopBar extends StatelessWidget {
  final String title;
  final bool showTitle;
  final SongSortOrder effectiveSortOrder;
  final bool showAlbumGroups;
  final bool isUnknown;
  final bool canFetchCover;
  final bool effectiveIsArtist;
  final bool effectiveIsAlbum;
  final String? playlistId;
  final List<Song> sortedSongs;
  final List<Song> visibleSongs;
  final ValueChanged<SongSortOrder> onLocalSort;
  final VoidCallback onFetchCover;
  final VoidCallback onPlaylistOptions;
  final VoidCallback onMerge;
  final VoidCallback onFetchMissing;

  const _FloatingTopBar({
    required this.title,
    required this.showTitle,
    required this.effectiveSortOrder,
    required this.showAlbumGroups,
    required this.isUnknown,
    required this.canFetchCover,
    required this.effectiveIsArtist,
    required this.effectiveIsAlbum,
    required this.playlistId,
    required this.sortedSongs,
    required this.visibleSongs,
    required this.onLocalSort,
    required this.onFetchCover,
    required this.onPlaylistOptions,
    required this.onMerge,
    required this.onFetchMissing,
  });

  @override
  Widget build(BuildContext context) {
    // No full-width blur here on purpose: blurring the cover underneath
    // smeared it into ghost faces across the status area. The scrim alone
    // keeps the buttons legible; only the small circular buttons blur.
    final double topPad = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppTokens.s3, topPad + AppTokens.s2, AppTokens.s3, AppTokens.s2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          GlassCircleButton(
            icon: const AppIcon(AppIcons.arrowBack, color: Colors.white),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: AnimatedOpacity(
              duration: AppTokens.dFast,
              opacity: showTitle ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.s3),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTokens.rowTitle(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          _GlassWrap(
            child: showAlbumGroups
                ? SortMenu(
                    sortOrder: effectiveSortOrder,
                    onSelected: onLocalSort,
                  )
                : const SortMenu(),
          ),
          if (isUnknown)
            GlassCircleButton(
              icon: const AppIcon(AppIcons.manageSearch,
                  color: Colors.white, size: 20),
              tooltip: 'Fetch Missing Metadata',
              onPressed: onFetchMissing,
            )
          else if (canFetchCover)
            GlassCircleButton(
              icon: const AppIcon(AppIcons.imageSearch,
                  color: Colors.white, size: 20),
              tooltip: effectiveIsArtist
                  ? 'Fetch Artist Cover Online'
                  : (effectiveIsAlbum
                      ? 'Fetch Album Cover Online'
                      : 'Fetch Cover Online'),
              onPressed: onFetchCover,
            ),
          if (playlistId != null)
            GlassCircleButton(
              icon: const AppIcon(AppIcons.moreVert,
                  color: Colors.white, size: 20),
              tooltip: 'Playlist Options',
              onPressed: onPlaylistOptions,
            ),
          if (playlistId == null &&
              !effectiveIsArtist &&
              !effectiveIsAlbum &&
              sortedSongs.length >= 2)
            GlassCircleButton(
              icon:
                  const AppIcon(AppIcons.merge, color: Colors.white, size: 20),
              tooltip: 'Merge Songs',
              onPressed: onMerge,
            ),
        ],
      ),
    );
  }
}

/// Translucent circular backing for shared sort menus without editing them.
class _GlassWrap extends StatelessWidget {
  final Widget child;

  const _GlassWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.38),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
