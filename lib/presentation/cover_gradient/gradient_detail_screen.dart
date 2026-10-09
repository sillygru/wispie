import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
import '../components/pressable.dart';
import '../components/progressive_edge_fade.dart';
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
import '../widgets/clickable_artist_text.dart';
import '../widgets/duration_display.dart';
import '../widgets/song_options_menu.dart';
import '../widgets/sort_menu.dart';
import '../components/transport_controls.dart';
import 'cover_blur_background.dart';
import 'cover_gradient_palette.dart';
import '../../providers/browse_palette_provider.dart';
import 'floating_mini_player.dart';
import 'glass_chrome.dart';
import '../components/animated_removal.dart';

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
  // Scroll position drives the hero parallax and the top bar through this
  // notifier only. Nothing may call setState from the scroll listener:
  // that rebuilt the screen (and re-sorted the song list) on every tick.
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);
  Color? _detailAccent;
  bool _detailNeutral = false;
  String _paletteKey = '';
  late final BrowsePaletteNotifier _browsePalette;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _browsePalette = ref.read(browsePaletteProvider.notifier);
  }

  @override
  void dispose() {
    // Deferred: providers can't be modified while the tree is finalizing.
    Future.microtask(() => _browsePalette.release(this));
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;
    _scrollOffset.value = _scroll.offset;
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
      _browsePalette.claim(this, palette);
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

    final MediaQueryData mq = MediaQuery.of(context);
    final double dpr = mq.devicePixelRatio;
    final double topPad = mq.padding.top;

    // Layout: anything with a cover, playlists included, gets the full-bleed
    // hero. Only coverless entries fall back to the cover card.
    final bool hasAnyCover =
        hasCustomArtwork || (firstSong?.coverUrl ?? '').isNotEmpty;
    final bool photoHero = hasAnyCover;
    final double photoH = (mq.size.height * 0.5).clamp(320.0, 520.0);
    final double cardSide = (mq.size.width * 0.62).clamp(180.0, 300.0);
    final double cardTop = topPad + 68;
    // One art widget serves both heroes, so it decodes at the width it will
    // actually paint at.
    final bool isWide = WideLayout.isWide(context);
    final double sidebarW = (mq.size.width * 0.32).clamp(340.0, 460.0);
    final double wideSide = sidebarW - 32;
    final double artWidth =
        isWide ? wideSide : (photoHero ? mq.size.width : cardSide);

    // Scroll offset at which the in-page title has slid under the top bar,
    // so the bar can take the title over.
    final double rawReveal = photoHero ? photoH - topPad - 150 : cardSide + 32;
    final double titleRevealOffset = rawReveal < 120 ? 120 : rawReveal;

    final String coverUrl = firstSong?.coverUrl ?? '';
    Widget coverArt;
    if (hasCustomArtwork && customArt != null) {
      coverArt = Image.file(
        File(customArt),
        fit: BoxFit.cover,
        // Width only: giving cacheWidth and cacheHeight together resizes to
        // exactly that box and squashes non-square art.
        cacheWidth: (artWidth * dpr).round(),
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF1E1E1E)),
      );
    } else if (coverUrl.isNotEmpty) {
      coverArt = AlbumArtImage(
        url: coverUrl,
        filename: firstSong?.filename,
        width: isWide ? wideSide : (photoHero ? null : cardSide),
        height: isWide ? wideSide : (photoHero ? null : cardSide),
        memCacheWidth: (artWidth * dpr).round(),
        fit: BoxFit.cover,
      );
    } else {
      coverArt = const ColoredBox(
        color: Color(0xFF1E1E1E),
        child: Center(
          child: AppIcon(AppIcons.musicNote, color: Colors.white24, size: 48),
        ),
      );
    }

    final VoidCallback? onArtworkTap = canFetchCover ? handleFetchCover : null;
    final Widget hero = photoHero
        ? _PhotoHero(
            art: coverArt,
            title: widget.title,
            height: photoH,
            scroll: _scrollOffset,
            onTap: onArtworkTap,
          )
        : _CardHero(
            art: coverArt,
            side: cardSide,
            topInset: cardTop,
            scroll: _scrollOffset,
            onTap: onArtworkTap,
          );

    final String? artistLine =
        effectiveIsAlbum && !effectiveIsArtist && effectiveArtistName.isNotEmpty
            ? effectiveArtistName
            : null;

    final Widget? albumsBlock = showAlbumGroups
        ? Padding(
            padding: const EdgeInsets.only(top: AppTokens.s2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  title: 'Albums',
                  trailing: selectedAlbum != null
                      ? _ClearChip(
                          onTap: () => setState(() => _selectedAlbum = null),
                        )
                      : null,
                ),
                AlbumCardSelector(
                  allSongs: widget.songs,
                  albums: orderedAlbums,
                  albumGroups: albumGroups,
                  selected: selectedAlbum,
                  artistName: effectiveArtistName,
                  onSelected: (album) => setState(() => _selectedAlbum = album),
                ),
              ],
            ),
          )
        : null;

    final Widget songsHeader = _SectionHeader(
      title: selectedAlbum ?? 'Songs',
      trailing: Text(
        '${visibleSongs.length}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );

    final Widget songsSliver = visibleSongs.isEmpty
        ? const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No songs in this list',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        : SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final Song song = visibleSongs[index];
                return _GradientSongRow(
                  song: song,
                  accent: baseAccent,
                  playlistId: widget.playlistId,
                  heroTagPrefix: 'gradient_${widget.title}',
                  visibleSongs: visibleSongs,
                  // Every song on an artist page is by that artist, so the
                  // album is the useful line.
                  showAlbumLine: effectiveIsArtist,
                );
              },
              childCount: visibleSongs.length,
            ),
          );

    final Widget detailInfo = _DetailInfo(
      title: (photoHero && !isWide) ? null : widget.title,
      artistLine: artistLine,
      visibleSongs: visibleSongs,
      sortedSongs: sortedSongs,
      playlistId: widget.playlistId,
      isUnknown: isUnknownArtistOrAlbum,
      albumCount: showAlbumGroups ? albumGroups.length : 0,
      accent: baseAccent,
    );

    // Desktop: cover, title, actions and albums pinned in a sidebar; the song
    // list gets the full height beside it.
    final double contentTop = topPad + 72;
    final Widget wideBody = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: sidebarW,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(top: contentTop, bottom: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: GestureDetector(
                    onTap: onArtworkTap,
                    child: Container(
                      width: wideSide,
                      height: wideSide,
                      decoration: BoxDecoration(
                        borderRadius: AppTokens.brLg,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: AppTokens.brLg,
                        child: coverArt,
                      ),
                    ),
                  ),
                ),
                detailInfo,
                if (albumsBlock != null) albumsBlock,
              ],
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ProgressiveEdgeFade(
                height: 140,
                topHeight: 64,
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(top: contentTop - 24),
                    ),
                    SliverToBoxAdapter(child: songsHeader),
                    songsSliver,
                    const SliverPadding(padding: EdgeInsets.only(bottom: 150)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

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
            // Flat legibility scrim. Deliberately not a gradient: one that
            // ends mid-screen makes scrolled content travel through a
            // near-black zone and hides the blur. Raise 0x4D (30%) if rows
            // lack contrast on a light cover.
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Color(0x4D000000)),
              ),
            ),
            if (isWide)
              wideBody
            else
              WideContentCenter(
                // Rows ease out under the floating mini player and under the
                // top bar instead of hard-cutting.
                child: ProgressiveEdgeFade(
                  height: 140,
                  topHeight: 64,
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      SliverToBoxAdapter(child: hero),
                      SliverToBoxAdapter(child: detailInfo),
                      if (albumsBlock != null)
                        SliverToBoxAdapter(child: albumsBlock),
                      SliverToBoxAdapter(child: songsHeader),
                      songsSliver,
                      const SliverPadding(
                          padding: EdgeInsets.only(bottom: 150)),
                    ],
                  ),
                ),
              ),
            // Floating top bar: glass buttons over the hero, a blurred bar
            // with the title once the hero has scrolled away.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _FloatingTopBar(
                title: widget.title,
                scroll: _scrollOffset,
                revealOffset: isWide ? 1e9 : titleRevealOffset,
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
            if (!LibraryTabScope.isEmbedded(context))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: selectionState.isSelectionMode
                      ? const BulkSelectionBar()
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
      final notifier = ref.read(userDataProvider.notifier);
      final String id = widget.playlistId!;
      Navigator.pop(context);
      AnimatedRemoval.run(id, () => notifier.deletePlaylist(id));
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

// ---------------------------------------------------------------------------
// Heroes
// ---------------------------------------------------------------------------

/// Full-bleed artist or album art. Parallax on scroll, stretches on
/// overscroll, and dissolves into the page's own blurred backdrop (alpha, not
/// black) so the blur keeps showing through as the page scrolls. The title
/// sits on the fade, large and left-aligned; that is the one bold moment on
/// the screen.
class _PhotoHero extends StatelessWidget {
  final Widget art;
  final String title;
  final double height;
  final ValueListenable<double> scroll;
  final VoidCallback? onTap;

  const _PhotoHero({
    required this.art,
    required this.title,
    required this.height,
    required this.scroll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget photo = ShaderMask(
      blendMode: BlendMode.dstIn,
      // Smoothstep falloff ending at zero alpha: no visible start or end line.
      shaderCallback: (Rect bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white,
          for (var i = 0; i <= 8; i++)
            Colors.white.withValues(
              alpha: 1 - (i / 8) * (i / 8) * (3 - 2 * i / 8),
            ),
        ],
        stops: <double>[
          0.0,
          for (var i = 0; i <= 8; i++) 0.4 + 0.6 * i / 8,
        ],
      ).createShader(bounds),
      child: art,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          // The stretched photo overflows the box while overscrolling.
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: scroll,
                child: photo,
                builder: (context, offset, child) {
                  final double pull = offset < 0 ? -offset : 0.0;
                  return Transform.translate(
                    // Pinned to the top while pulling, half-speed on scroll.
                    offset: Offset(0, offset < 0 ? offset : offset * 0.35),
                    child: Transform.scale(
                      scale: 1 + pull / height,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 14),
                // A band that fades out at both ends, so the title reads on
                // the photo without leaving an edge where the hero ends.
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x00000000),
                      Color(0x66000000),
                      Color(0x73000000),
                      Color(0x40000000),
                      Color(0x00000000),
                    ],
                    stops: <double>[0.0, 0.35, 0.6, 0.85, 1.0],
                  ),
                ),
                // The title drifts up and dissolves faster than the photo
                // parallax, so it clears before sliding under the top bar.
                child: ValueListenableBuilder<double>(
                  valueListenable: scroll,
                  child: _TitleText(title, fontSize: 36, shadow: true),
                  builder: (context, offset, child) {
                    final double t = (offset / (height * 0.45)).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: 1 - Curves.easeIn.transform(t),
                      child: Transform.translate(
                        offset: Offset(0, -AppTokens.s5 * t),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered cover card for playlists and coverless collections. Shrinks and
/// fades as the page scrolls, grows slightly when pulled down.
class _CardHero extends StatelessWidget {
  final Widget art;
  final double side;
  final double topInset;
  final ValueListenable<double> scroll;
  final VoidCallback? onTap;

  const _CardHero({
    required this.art,
    required this.side,
    required this.topInset,
    required this.scroll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          borderRadius: AppTokens.brLg,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: AppTokens.brLg, child: art),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: topInset, bottom: AppTokens.s3),
      child: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: scroll,
          child: card,
          builder: (context, offset, child) {
            final double t = (offset / side).clamp(0.0, 1.0);
            final double pull =
                offset < 0 ? (-offset / side).clamp(0.0, 0.3) : 0.0;
            return Opacity(
              opacity: 1 - 0.7 * t,
              child: Transform.scale(
                scale: 1 - 0.12 * t + pull,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool shadow;

  const _TitleText(this.text, {required this.fontSize, this.shadow = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTokens.screenTitle(context).copyWith(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.06,
        shadows: shadow
            ? <Shadow>[
                Shadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info + actions
// ---------------------------------------------------------------------------

/// Everything between the hero and the lists: the title (when the hero does
/// not already carry it), the artist link for albums, the stats, and the
/// shuffle / play controls on one row.
class _DetailInfo extends ConsumerWidget {
  final String? title;
  final String? artistLine;
  final List<Song> visibleSongs;
  final List<Song> sortedSongs;
  final String? playlistId;
  final bool isUnknown;
  final int albumCount;
  final Color accent;

  const _DetailInfo({
    required this.title,
    required this.artistLine,
    required this.visibleSongs,
    required this.sortedSongs,
    required this.playlistId,
    required this.isUnknown,
    required this.albumCount,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final bool enabled = visibleSongs.isNotEmpty;
    final String? artist = artistLine;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, title == null ? 2 : 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) _TitleText(title!, fontSize: 28),
          if (artist != null && artist.isNotEmpty) ...[
            const SizedBox(height: 6),
            ClickableArtistText(
              artist: artist,
              style: AppTokens.rowTitle(context).copyWith(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              onArtistTap: (name) =>
                  songActionGoToArtistByName(context, ref, name),
            ),
          ],
          SizedBox(height: title == null ? 6 : 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CollectionDurationDisplay(
                      songs: visibleSongs,
                      showSongCount: true,
                      compact: true,
                      style: AppTokens.meta(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    if (albumCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$albumCount albums',
                          style: AppTokens.meta(context).copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _RoundAction(
                size: 48,
                iconSize: 22,
                tooltip: 'Shuffle',
                // Tinted from the cover accent so both actions belong to the
                // page's palette rather than the global scheme.
                background: accent.withValues(alpha: 0.22),
                foreground: Color.lerp(accent, Colors.white, 0.45)!,
                icon: AppIcons.shuffle,
                enabled: enabled,
                onTap: () {
                  audioManager.shuffleAndPlay(
                    visibleSongs,
                    isRestricted: true,
                  );
                },
              ),
              const SizedBox(width: 12),
              CollectionPlaybackBuilder(
                audioManager: audioManager,
                songs: visibleSongs,
                builder: (context, isCurrent, playing) => _RoundAction(
                  size: 64,
                  iconSize: 30,
                  tooltip: isCurrent && playing ? 'Pause' : 'Play',
                  background: accent,
                  foreground: AppTokens.onAccent(accent),
                  icon: AppIcons.play,
                  enabled: enabled,
                  glyphBuilder: (fg) => PlayPauseMorphIcon(
                    playing: isCurrent && playing,
                    size: 30,
                    color: fg,
                  ),
                  onTap: () {
                    if (isCurrent) {
                      audioManager.togglePlayPause();
                      return;
                    }
                    audioManager.replaceQueue(
                      visibleSongs,
                      playlistId: playlistId,
                      forceLinear: true,
                      clearCurrentSong: true,
                    );
                  },
                ),
              ),
            ],
          ),
          if (isUnknown && sortedSongs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.s3),
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

/// Circular tap target with press feedback. Same icon set and callbacks as
/// the previous detail actions.
class _RoundAction extends StatelessWidget {
  final double size;
  final double iconSize;
  final String tooltip;
  final Color background;
  final Color foreground;
  final AppIconData icon;
  final bool enabled;
  final VoidCallback onTap;

  /// Replaces the static [icon] glyph, e.g. with an animated one.
  final Widget Function(Color fg)? glyphBuilder;

  const _RoundAction({
    required this.size,
    required this.iconSize,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.glyphBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg =
        enabled ? background : Colors.white.withValues(alpha: 0.08);
    final Color fg =
        enabled ? foreground : Colors.white.withValues(alpha: 0.35);
    return Tooltip(
      message: tooltip,
      child: Pressable(
        pressedScale: 0.92,
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          alignment: Alignment.center,
          child: glyphBuilder?.call(fg) ??
              AppIcon(icon, color: fg, size: iconSize),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final Widget? end = trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
          ),
          if (end != null) end,
        ],
      ),
    );
  }
}

/// Shown beside "Albums" while an album filter is active.
class _ClearChip extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: AppTokens.brPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Show all',
              style: AppTokens.meta(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.close_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song row
// ---------------------------------------------------------------------------

/// Transparent song row painted on the page backdrop. The active / selected
/// wash is a rounded, fading highlight with the ripple above it. Each row
/// watches only the slices of state it displays, so a favorite toggle or a
/// selection change rebuilds one row instead of the whole list.
class _GradientSongRow extends ConsumerWidget {
  final Song song;
  final Color accent;
  final String? playlistId;
  final String heroTagPrefix;
  final List<Song> visibleSongs;
  final bool showAlbumLine;

  const _GradientSongRow({
    required this.song,
    required this.accent,
    required this.playlistId,
    required this.heroTagPrefix,
    required this.visibleSongs,
    required this.showAlbumLine,
  });

  static final BorderRadius _radius = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final bool isSelectionMode =
        ref.watch(selectionProvider.select((s) => s.isSelectionMode));
    final bool isSelected = ref.watch(selectionProvider
        .select((s) => s.selectedFilenames.contains(song.filename)));
    final bool isFavorite =
        ref.watch(userDataProvider.select((d) => d.isFavorite(song.filename)));
    final bool isSuggestLess = ref
        .watch(userDataProvider.select((d) => d.isSuggestLess(song.filename)));
    final VisualizerMode visualizerMode =
        ref.watch(settingsProvider.select((s) => s.visualizerMode));
    final bool showDuration =
        ref.watch(settingsProvider.select((s) => s.showSongDuration));
    final String heroTag = '${heroTagPrefix}_${song.filename}';
    final String subtitle = showAlbumLine && song.album.trim().isNotEmpty
        ? song.album
        : song.artist;

    return ValueListenableBuilder<Song?>(
      valueListenable: audioManager.currentSongNotifier,
      builder: (context, currentSong, _) {
        final bool isActive = currentSong?.filename == song.filename;
        return Opacity(
          opacity: isSuggestLess ? 0.55 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isSelected || isActive
                    ? accent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: _radius,
              ),
              // Clip + transparent Material: the ripple paints above the
              // wash and stays inside the rounded corners.
              child: ClipRRect(
                borderRadius: _radius,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: isSelectionMode
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
                      if (!isSelectionMode) {
                        ref
                            .read(selectionProvider.notifier)
                            .enterSelectionMode(song.filename);
                        HapticFeedback.heavyImpact();
                      } else {
                        showSongOptionsMenu(
                            context, ref, song.filename, song.title,
                            song: song, playlistId: playlistId);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
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
                            visualizerMode: visualizerMode,
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
                                    color: isActive ? accent : Colors.white,
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
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTokens.rowSubtitle(context)
                                            .copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.62),
                                        ),
                                      ),
                                    ),
                                    if (showDuration &&
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
                          if (!isSelectionMode) ...[
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
                              inactiveColor:
                                  Colors.white.withValues(alpha: 0.5),
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
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _FloatingTopBar extends StatelessWidget {
  final String title;
  final ValueListenable<double> scroll;
  final double revealOffset;
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
    required this.scroll,
    required this.revealOffset,
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

  /// 0 while the in-page title is still visible, 1 once the bar owns it.
  static double _reveal(double offset, double revealOffset) =>
      ((offset - (revealOffset - 60)) / 60).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final double topPad = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        // Over the hero: an eased scrim behind the glass buttons. Once the
        // hero has scrolled away: a blurred bar. Nothing blurs the photo
        // itself, only content that has actually scrolled underneath.
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: scroll,
              builder: (context, offset, _) {
                final double t = _reveal(offset, revealOffset);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (t < 1)
                      Opacity(
                        opacity: 1 - t,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x8C000000),
                                Color(0x69000000),
                                Color(0x24000000),
                                Color(0x00000000),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (t > 0)
                      Opacity(
                        opacity: t,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: const ColoredBox(color: Color(0x66000000)),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppTokens.s3, topPad + AppTokens.s2, AppTokens.s3, AppTokens.s2),
          child: Row(
            children: [
              GlassCircleButton(
                icon: const AppIcon(AppIcons.arrowBack, color: Colors.white),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: IgnorePointer(
                  child: ValueListenableBuilder<double>(
                    valueListenable: scroll,
                    builder: (context, offset, _) => Opacity(
                      opacity: _reveal(offset, revealOffset),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.s3),
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
                  icon: const AppIcon(AppIcons.merge,
                      color: Colors.white, size: 20),
                  tooltip: 'Merge Songs',
                  onPressed: onMerge,
                ),
            ],
          ),
        ),
      ],
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
                  return PlayingVisualizerOverlay(
                    playing: playing,
                    mode: visualizerMode,
                    size: 22,
                    radius: AppTokens.brSm,
                  );
                },
              ),
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
