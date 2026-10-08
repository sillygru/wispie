import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:video_player/video_player.dart';

import '../../domain/services/video_sync_policy.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/audio_player_manager.dart';
import '../../services/display_refresh_service.dart';
import '../../services/power_state_service.dart';
import '../../services/screen_wake_lock_service.dart';
import '../../theme/app_theme.dart';
import '../components/player_segmented_pill.dart';
import '../components/pressable.dart';
import '../components/song_actions.dart';
import '../components/track_swipe_switcher.dart';
import '../components/transport_controls.dart';
import '../tokens/player_tokens.dart';
import '../utils/wide_layout.dart';
import '../widgets/album_art_image.dart';
import '../widgets/basic_progress_bar.dart';
import '../widgets/beat_particle_field.dart';
import '../widgets/clickable_artist_text.dart';
import '../widgets/heart_context_menu.dart';
import '../widgets/now_playing_lyric_peek.dart';
import '../widgets/player_motion.dart';
import '../widgets/reactive_waveform_progress_bar.dart';
import '../widgets/shrink_then_wrap_text.dart';
import '../widgets/song_options_menu.dart';
import '../widgets/waveform_progress_bar.dart';
import '../motion/player_motion_ensemble.dart';
import '../screens/player/lyrics_pane.dart';
import '../screens/player/queue_pane.dart';
import '../screens/unified_player_screen.dart' show PlayerPane;
import 'cover_blur_background.dart';
import 'cover_gradient_palette.dart';
import 'glass_chrome.dart';

/// Single kill-switch for the full-bleed particle layer.
const bool kFullBleedParticlesEnabled = true;

/// Full-bleed cover player. Owns its own shell lifecycle so the legacy
/// [UnifiedPlayerScreen] stays byte-identical when the toggle is off.
class FullBleedPlayerScreen extends ConsumerStatefulWidget {
  final PlayerPane initialPane;
  final bool queueShowsHistory;

  const FullBleedPlayerScreen({
    super.key,
    this.initialPane = PlayerPane.player,
    this.queueShowsHistory = false,
  });

  @override
  ConsumerState<FullBleedPlayerScreen> createState() =>
      _FullBleedPlayerScreenState();
}

class _FullBleedPlayerScreenState extends ConsumerState<FullBleedPlayerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const String _wakeLockReason = 'full_bleed_player_lyrics';

  late final PageController _pageController;
  late final PlayerMotionController _motion;
  late final PlayerMotionEnsemble _ensemble;

  final ValueNotifier<double> _pagePosition = ValueNotifier(0);
  final ValueNotifier<double> _landscapePosition = ValueNotifier(0);
  final ValueNotifier<bool> _nowPlayingVisible = ValueNotifier(false);
  final ValueNotifier<bool> _lyricsVisible = ValueNotifier(false);

  final GlobalKey _coverKey = GlobalKey(debugLabel: 'fullbleed cover');
  final GlobalKey _shellKey = GlobalKey(debugLabel: 'fullbleed shell');

  late int _pane;
  bool _wakeLockHeld = false;
  bool _appActive = true;
  double _dismissDrag = 0;
  late int _landscapeTab;
  bool _showingWide = false;
  bool _reduceMotion = false;

  String? _beatMapFilename;
  int _beatMapToken = 0;
  late final AudioPlayerManager _manager;

  @override
  void initState() {
    super.initState();
    _pane = widget.initialPane.index;
    _pagePosition.value = _pane.toDouble();
    _landscapeTab = widget.initialPane == PlayerPane.queue ? 1 : 0;
    _landscapePosition.value = _landscapeTab.toDouble();
    _nowPlayingVisible.value = _isNowPlayingVisible(_pagePosition.value);
    _lyricsVisible.value = _isLyricsVisible(_pagePosition.value);
    _pageController = PageController(initialPage: _pane);
    _pageController.addListener(_onPageScroll);

    WidgetsBinding.instance.addObserver(this);

    _manager = ref.read(audioPlayerManagerProvider);
    _motion = PlayerMotionController(player: _manager.player)..attach(this);
    _ensemble = PlayerMotionEnsemble(controller: _motion);
    _manager.currentSongNotifier.addListener(_onSongChanged);
    _manager.playingNotifier.addListener(_syncWakeLock);
    _manager.playingNotifier.addListener(_syncRefresh);
    PowerStateService.instance.powerSave.addListener(_syncMotionSettings);
    PowerStateService.instance.powerSave.addListener(_syncRefresh);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWakeLock();
      _syncMotionSettings();
      _syncRefresh();
      _onSongChanged();
    });
    DisplayRefreshService.instance.enterPlayer(
      playing: _manager.playingNotifier.value,
      powerSave: PowerStateService.instance.powerSave.value,
    );
  }

  @override
  void dispose() {
    DisplayRefreshService.instance.leavePlayer();
    WidgetsBinding.instance.removeObserver(this);
    _manager.currentSongNotifier.removeListener(_onSongChanged);
    _manager.playingNotifier.removeListener(_syncWakeLock);
    _manager.playingNotifier.removeListener(_syncRefresh);
    PowerStateService.instance.powerSave.removeListener(_syncMotionSettings);
    PowerStateService.instance.powerSave.removeListener(_syncRefresh);
    _ensemble.dispose();
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    _pagePosition.dispose();
    _landscapePosition.dispose();
    _nowPlayingVisible.dispose();
    _lyricsVisible.dispose();
    _releaseWakeLock();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMotionSettings();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _appActive = state == AppLifecycleState.resumed;
    _motion.appActive = _appActive;
    if (_appActive) {
      _syncPaneVisibility();
      _syncRefresh();
      _syncWakeLock();
      if (_motion.beatMap == null) _onSongChanged();
    } else {
      _nowPlayingVisible.value = false;
      _lyricsVisible.value = false;
      DisplayRefreshService.instance.leavePlayer();
      _releaseWakeLock();
    }
  }

  void _syncPaneVisibility() {
    if (!_appActive) {
      _nowPlayingVisible.value = false;
      _lyricsVisible.value = false;
      return;
    }
    if (_showingWide) {
      _nowPlayingVisible.value = true;
      _lyricsVisible.value = _landscapeTab == 0;
      return;
    }
    _nowPlayingVisible.value = _isNowPlayingVisible(_pagePosition.value);
    _lyricsVisible.value = _isLyricsVisible(_pagePosition.value);
  }

  Future<void> _onSongChanged() async {
    if (!mounted) return;
    final Song? song = _manager.currentSongNotifier.value;
    if (song == null) {
      _beatMapFilename = null;
      _motion.beatMap = null;
      return;
    }
    if (song.filename == _beatMapFilename && _motion.beatMap != null) return;
    _beatMapFilename = song.filename;
    final int token = ++_beatMapToken;
    _motion.beatMap = null;
    if (!mounted) return;
    final service = ref.read(beatAnalysisServiceProvider);
    final cached = await service.readCached(song.filename);
    if (!mounted || token != _beatMapToken) return;
    if (cached != null) {
      _motion.beatMap = cached;
      return;
    }
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation != null && !animation.isCompleted) {
      final completer = Completer<void>();
      void listener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          animation.removeStatusListener(listener);
          if (!completer.isCompleted) completer.complete();
        }
      }

      animation.addStatusListener(listener);
      await completer.future;
      if (!mounted || token != _beatMapToken) return;
    }
    final analyzed = await service.analyze(song.filename, song.url);
    if (!mounted || token != _beatMapToken) return;
    _motion.beatMap = analyzed;
  }

  void _syncMotionSettings() {
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    _motion
      ..powerSave = PowerStateService.instance.powerSave.value
      ..enabled = !_reduceMotion &&
          (settings.beatReactiveCoverEnabled ||
              settings.beatReactiveParticlesEnabled)
      ..coverIntensity = settings.coverMotionIntensity
      ..particleIntensity = settings.particleMotionIntensity
      ..coverCustomIntensity = settings.coverMotionCustomIntensity
      ..particleCustomIntensity = settings.particleMotionCustomIntensity
      ..latencyMs = settings.playerMotionLatencyMs;
  }

  bool _isNowPlayingVisible(double page) =>
      (page - PlayerPane.player.index).abs() <= 0.6;

  bool _isLyricsVisible(double page) =>
      (page - PlayerPane.lyrics.index).abs() <= 0.6;

  void _onPageScroll() {
    final double? page = _pageController.page;
    if (page == null) return;
    final double prev = _pagePosition.value;
    _pagePosition.value = page;
    if (!_showingWide) {
      _nowPlayingVisible.value = _appActive && _isNowPlayingVisible(page);
      _lyricsVisible.value = _appActive && _isLyricsVisible(page);
    }
    if ((page - prev).abs() > 0.005 && _appActive) {
      DisplayRefreshService.instance.boost120();
    }
    final int settled = page.round();
    if (settled != _pane) {
      _pane = settled;
      _syncWakeLock();
    }
  }

  void _syncRefresh() {
    if (!_appActive || !mounted) return;
    final bool playing = _manager.playingNotifier.value;
    final bool powerSave = PowerStateService.instance.powerSave.value;
    DisplayRefreshService.instance.enterPlayer(
      playing: playing && !powerSave ? true : playing,
      powerSave: playing && !powerSave ? false : powerSave,
    );
  }

  void _syncWakeLock() {
    if (!_appActive || !mounted) return;
    final bool playing = _manager.playingNotifier.value;
    final bool lyricsSelected =
        _showingWide ? _landscapeTab == 0 : _pane == PlayerPane.lyrics.index;
    final bool wanted = lyricsSelected &&
        ref.read(settingsProvider).keepScreenAwakeOnLyrics &&
        playing;
    if (wanted && !_wakeLockHeld) {
      _wakeLockHeld = true;
      ScreenWakeLockService.instance.acquire(_wakeLockReason);
    } else if (!wanted && _wakeLockHeld) {
      _releaseWakeLock();
    }
  }

  void _releaseWakeLock() {
    if (!_wakeLockHeld) return;
    _wakeLockHeld = false;
    ScreenWakeLockService.instance.release(_wakeLockReason);
  }

  void _goToPane(int index) {
    DisplayRefreshService.instance.boost120();
    _pageController.animateToPage(
      index,
      duration: PlayerTokens.dBase,
      curve: PlayerTokens.cEmphasized,
    );
  }

  void _selectLandscapeTab(int index) {
    if (index == _landscapeTab) return;
    setState(() => _landscapeTab = index);
    _landscapePosition.value = index.toDouble();
    _syncPaneVisibility();
    _syncWakeLock();
  }

  void _onDismissDragUpdate(DragUpdateDetails details) {
    _dismissDrag += details.delta.dy;
  }

  void _onDismissDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (_dismissDrag > 90 || velocity > 700) {
      Navigator.of(context).maybePop();
    }
    _dismissDrag = 0;
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final Color accent =
        themeState.extractedColor ?? Theme.of(context).colorScheme.primary;

    ref.listen(
      settingsProvider.select((s) => s.keepScreenAwakeOnLyrics),
      (_, __) => _syncWakeLock(),
    );
    ref.listen(
      settingsProvider.select(
        (s) => (
          s.beatReactiveCoverEnabled,
          s.beatReactiveParticlesEnabled,
          s.coverMotionIntensity,
          s.particleMotionIntensity,
          s.coverMotionCustomIntensity,
          s.particleMotionCustomIntensity,
          s.playerMotionLatencyMs,
        ),
      ),
      (_, __) => _syncMotionSettings(),
    );

    return Theme(
      data: AppTheme.getPlayerTheme(themeState, accent),
      child: Builder(
        builder: (context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).maybePop(),
          },
          child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: Colors.black,
                body: ValueListenableBuilder<Song?>(
                  valueListenable:
                      ref.watch(audioPlayerManagerProvider).currentSongNotifier,
                  builder: (context, song, _) {
                    if (song == null) return _buildEmptyState(context);
                    return _buildBody(context, song, accent);
                  },
                ),
              )),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: PlayerTokens.aTertiary),
            ),
            const SizedBox(height: PlayerTokens.s3),
            Text('Nothing playing', style: PlayerTokens.paneTitle(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Song song, Color accent) {
    final bool particlesAllowed = kFullBleedParticlesEnabled &&
        !_reduceMotion &&
        ref.watch(
            settingsProvider.select((s) => s.beatReactiveParticlesEnabled));
    final bool isWide = WideLayout.isWide(context);
    if (isWide != _showingWide) {
      _showingWide = isWide;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncPaneVisibility();
          _syncWakeLock();
        }
      });
    }
    final bool isNeutral = ref.watch(
      themeProvider.select((t) => t.isNeutralCover),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenH = constraints.maxHeight <= 0
            ? MediaQuery.sizeOf(context).height
            : constraints.maxHeight;
        final double coverH = (screenH * 0.58).clamp(280.0, 620.0);

        return Stack(
          key: _shellKey,
          children: [
            Positioned.fill(
              child: CoverBlurBackground(
                coverUrl: song.coverUrl ?? '',
                filename: song.filename,
                accent: accent,
                isNeutral: isNeutral,
              ),
            ),
            if (particlesAllowed)
              Positioned(
                top: coverH,
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: Opacity(
                      opacity: 0.55,
                      child: BeatParticleField(
                        controller: _motion,
                        accent: accent,
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              top: false,
              bottom: false,
              child: isWide
                  ? _buildWideContent(context, song, accent, coverH)
                  : _buildNarrowContent(context, song, accent, coverH),
            ),
          ],
        );
      },
    );
  }

  /// Narrow layout: cover extends under the status bar with header/tabs
  /// floating over it. Lyrics/Queue get top padding so rows start below the
  /// chrome; the Player pane stays full-bleed.
  Widget _buildNarrowContent(
    BuildContext context,
    Song song,
    Color accent,
    double coverH,
  ) {
    final double chromeHeight = MediaQuery.paddingOf(context).top + 100;
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _PaneTransition(
                      position: _pagePosition,
                      index: 0,
                      child: Padding(
                        padding: EdgeInsets.only(top: chromeHeight),
                        child: LyricsPane(
                          song: song,
                          accent: accent,
                          paneVisible: _lyricsVisible,
                        ),
                      ),
                    ),
                    _PaneTransition(
                      position: _pagePosition,
                      index: 1,
                      child: _FullBleedPlayerPane(
                        song: song,
                        accent: accent,
                        coverHeight: coverH,
                        coverKey: _coverKey,
                        paneVisible: _nowPlayingVisible,
                        audioManager: _manager,
                        pagePosition: _pagePosition,
                      ),
                    ),
                    _PaneTransition(
                      position: _pagePosition,
                      index: 2,
                      child: Padding(
                        padding: EdgeInsets.only(top: chromeHeight),
                        child: QueuePane(
                          accent: accent,
                          initialShowHistory: widget.queueShowsHistory,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _FullBleedTransportDock(song: song, accent: accent),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: chromeHeight + 28,
          // Eased legibility scrim: a smooth ramp instead of four linear
          // stops, so no band shows where the chrome sits over bright art.
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    for (var i = 0; i <= 6; i++)
                      Colors.black.withValues(
                        alpha: 0.32 * (1 - Curves.easeOut.transform(i / 6)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingHeader(context, song, accent, scrim: false),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: WideLayoutGutter.of(context),
                  vertical: PlayerTokens.s1,
                ),
                child: PlayerSegmentedPill(
                  labels: const <String>['Lyrics', 'Player', 'Queue'],
                  position: _pagePosition,
                  onSelected: _goToPane,
                  accent: accent,
                  overCover: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideContent(
    BuildContext context,
    Song song,
    Color accent,
    double coverH,
  ) {
    final double topPad = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double sideWidth = (constraints.maxWidth * 0.4).clamp(
              320.0,
              WideLayout.playerSideWidth * 1.3,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: sideWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) => _FullBleedPlayerPane(
                            song: song,
                            accent: accent,
                            coverHeight: box.maxHeight * 0.62,
                            coverKey: _coverKey,
                            paneVisible: _nowPlayingVisible,
                            audioManager: _manager,
                          ),
                        ),
                      ),
                      _FullBleedTransportDock(song: song, accent: accent),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          PlayerTokens.s6,
                          topPad + PlayerTokens.s3,
                          PlayerTokens.s6,
                          PlayerTokens.s2,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: PlayerSegmentedPill(
                              labels: const <String>['Lyrics', 'Queue'],
                              position: _landscapePosition,
                              onSelected: _selectLandscapeTab,
                              accent: accent,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: PlayerTokens.s4,
                              ),
                              child: IndexedStack(
                                index: _landscapeTab,
                                children: [
                                  LyricsPane(
                                    song: song,
                                    accent: accent,
                                    paneVisible: _lyricsVisible,
                                  ),
                                  QueuePane(
                                    accent: accent,
                                    initialShowHistory:
                                        widget.queueShowsHistory,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildFloatingHeader(
            context,
            song,
            accent,
            scrim: false,
            wide: true,
          ),
        ),
      ],
    );
  }

  /// Chevron + menu floating over the cover with a top scrim. The centered
  /// title/artist text is intentionally omitted here because the info block
  /// below the cover already carries it.
  Widget _buildFloatingHeader(
    BuildContext context,
    Song song,
    Color accent, {
    bool scrim = true,
    bool wide = false,
  }) {
    final double topPad = MediaQuery.paddingOf(context).top;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: wide ? null : _onDismissDragUpdate,
      onVerticalDragEnd: wide ? null : _onDismissDragEnd,
      child: Stack(
        children: [
          // The narrow layout lays its own eased scrim under the whole chrome
          // block; stacking this one on top read as a dark band over the art.
          if (scrim)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: CoverGradientPalette.topScrim(),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              WideLayoutGutter.of(context),
              topPad + PlayerTokens.s1,
              PlayerTokens.s3,
              2,
            ),
            child: Column(
              children: [
                if (!wide)
                  Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: PlayerTokens.s1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.38),
                      borderRadius: PlayerTokens.brPill,
                    ),
                  ),
                Row(
                  children: [
                    GlassCircleButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      tooltip: wide ? 'Close (Esc)' : 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    GlassCircleButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: 'Song options',
                      onPressed: () => showSongOptionsMenu(
                        context,
                        ref,
                        song.filename,
                        song.title,
                        song: song,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Player page for the full-bleed layout: static cover with a shader fade,
/// then the same info hierarchy and lyric peek as the legacy pane.
class _FullBleedPlayerPane extends ConsumerWidget {
  final Song song;
  final Color accent;
  final double coverHeight;
  final GlobalKey coverKey;
  final ValueListenable<bool> paneVisible;
  final AudioPlayerManager audioManager;

  /// Page position in pane units (1.0 = this pane). When given, the cover
  /// dissolves into the shell's blurred backdrop while swiping away instead
  /// of sliding off sharp. Null in the wide layout, where nothing swipes.
  final ValueListenable<double>? pagePosition;

  const _FullBleedPlayerPane({
    required this.song,
    required this.accent,
    required this.coverHeight,
    required this.coverKey,
    required this.paneVisible,
    required this.audioManager,
    this.pagePosition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flex cover: the artwork takes exactly the leftover viewport space, so
    // no slack can pool anywhere - no mid-screen void, no top seam. Falls
    // back to a fixed small cover with scroll on tiny windows and video
    // tracks (whose toggle would overflow the tight column).
    return LayoutBuilder(
      builder: (context, constraints) {
        final double viewportH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 640;
        if (viewportH < 380 || song.hasVideo) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCover(context, 240),
                ContentGutter(
                  child: _FullBleedInfoBlock(song: song, accent: accent),
                ),
                const SizedBox(height: PlayerTokens.s1),
                SizedBox(
                  height: 24,
                  child: ContentGutter(
                    child: Transform.translate(
                      offset: const Offset(-PlayerTokens.s5, 0),
                      child: NowPlayingLyricPeek(
                        song: song,
                        accent: accent,
                        paneVisible: paneVisible,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PlayerTokens.s1),
                if (song.hasVideo)
                  Center(
                    child: _FullBleedVideoToggle(
                      accent: accent,
                      audioManager: audioManager,
                    ),
                  ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SwipeFade(
                position: pagePosition,
                child: LayoutBuilder(
                  builder: (context, c) {
                    // Tall windows: the sharp art stops at a mild crop so it is
                    // never zoomed far, and the space above is filled by a
                    // heavily blurred copy of the same art. The sharp cover's
                    // top edge feathers into it, so the artwork still reads
                    // as reaching the top with no band or seam.
                    final double cap = MediaQuery.sizeOf(context).width * 1.2;
                    final bool capped = c.maxHeight > cap;
                    final double h = capped ? cap : c.maxHeight;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        if (capped)
                          _CoverExtension(song: song, height: c.maxHeight),
                        _CoverPrefetch(
                          audioManager: audioManager,
                          song: song,
                          height: h,
                        ),
                        TrackSwipeSwitcher<Song>(
                          item: song,
                          idOf: (s) => s.filename,
                          audioManager: audioManager,
                          fade: 0.3,
                          builder: (context, s, current) => Align(
                            alignment: Alignment.bottomCenter,
                            child: _buildCover(
                              context,
                              h,
                              fadeTop: capped,
                              forSong: s,
                              current: current,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            ContentGutter(
              child: TrackSwipeSwitcher<Song>(
                item: song,
                idOf: (s) => s.filename,
                audioManager: audioManager,
                travel: 0.35,
                fade: 1,
                builder: (context, s, _) =>
                    _FullBleedInfoBlock(song: s, accent: accent),
              ),
            ),
            const SizedBox(height: PlayerTokens.s1),
            SizedBox(
              height: 24,
              child: ContentGutter(
                child: Transform.translate(
                  offset: const Offset(-PlayerTokens.s5, 0),
                  child: NowPlayingLyricPeek(
                    song: song,
                    accent: accent,
                    paneVisible: paneVisible,
                  ),
                ),
              ),
            ),
            const SizedBox(height: PlayerTokens.s1),
          ],
        );
      },
    );
  }

  Widget _buildCover(BuildContext context, double height,
      {bool fadeTop = false, Song? forSong, bool current = true}) {
    final Song song = forSong ?? this.song;
    return ValueListenableBuilder<PlaybackMediaMode>(
      valueListenable: audioManager.effectiveMediaModeNotifier,
      builder: (context, mode, _) {
        final bool isVideo = mode == PlaybackMediaMode.video;
        if (isVideo) {
          if (!current) return SizedBox(height: height);
          return SizedBox(
            width: double.infinity,
            height: height,
            child: _FullBleedVideoSurface(
              song: song,
              audioManager: audioManager,
              paneVisible: paneVisible,
              placeholderHeight: height,
            ),
          );
        }
        // Static cover: no beat transform on purpose in this design. The
        // artwork is edge-to-edge here, so a scale has nowhere to go but under
        // the bottom fade, where it opens a gap above the transport dock.
        //
        // ShaderMask fades the lower third into transparency so the blur
        // behind shows through with no edge to color-match.
        final Widget art = Hero(
          tag: PlayerTokens.coverHeroTag(song.filename),
          flightShuttleBuilder: (_, animation, direction, fromCtx, toCtx) {
            final Hero hero = (direction == HeroFlightDirection.push
                ? toCtx.widget
                : fromCtx.widget) as Hero;
            // The landed cover carries a bottom fade. Growing that fade in
            // with the flight (instead of applying it on landing) keeps the
            // darkening from popping in after the route settles.
            return AnimatedBuilder(
              animation: animation,
              child: hero.child,
              builder: (context, child) {
                final double t = animation.value.clamp(0.0, 1.0);
                return ClipRRect(
                  borderRadius:
                      BorderRadius.circular((1 - t) * PlayerTokens.rSm),
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        _coverFadeShader(bounds, fadeTop, t),
                    blendMode: BlendMode.dstIn,
                    child: child,
                  ),
                );
              },
            );
          },
          child: Container(
            key: current ? coverKey : null,
            width: double.infinity,
            height: height,
            color: Colors.black,
            child: AlbumArtImage(
              url: song.coverUrl ?? '',
              filename: song.filename,
              cacheVersion: song.mtime,
              width: MediaQuery.sizeOf(context).width,
              height: height,
              memCacheWidth: (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
              fit: BoxFit.cover,
            ),
          ),
        );
        return SizedBox(
          width: double.infinity,
          height: height,
          child: _SideFade(
            enabled: WideLayout.isWide(context),
            child: ShaderMask(
              shaderCallback: (Rect bounds) =>
                  _coverFadeShader(bounds, fadeTop, 1),
              blendMode: BlendMode.dstIn,
              child: art,
            ),
          ),
        );
      },
    );
  }

  /// Fades the lower part of the cover (and the top edge when capped) into
  /// the blurred backdrop. [strength] 0 is an unmasked cover, 1 the full fade.
  /// The ramp follows a smoothstep rather than linear segments, so there is no
  /// visible knee where the art starts to dissolve.
  static Shader _coverFadeShader(Rect bounds, bool fadeTop, double strength) {
    Color c(double alpha) => Color.lerp(
          Colors.white,
          Colors.white.withValues(alpha: alpha),
          strength,
        )!;
    final colors = <Color>[];
    final stops = <double>[];
    if (fadeTop) {
      for (var i = 0; i <= 4; i++) {
        final double t = i / 4;
        colors.add(c(Curves.easeInOut.transform(t)));
        stops.add(0.24 * t);
      }
    } else {
      colors.add(Colors.white);
      stops.add(0.0);
    }
    const double fadeStart = 0.5;
    for (var i = 0; i <= 8; i++) {
      final double t = i / 8;
      final double smooth = t * t * (3 - 2 * t);
      colors.add(c(1 - smooth));
      stops.add(fadeStart + (1 - fadeStart) * t);
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(bounds);
  }
}

/// Dissolves the right edge of the cover into the backdrop on wide windows,
/// where the cover column sits beside the lyrics instead of spanning the screen.
class _SideFade extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _SideFade({required this.enabled, required this.child});

  static double _smootherstep(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: <Color>[
          for (var i = 0; i <= 12; i++)
            Colors.white.withValues(alpha: 1 - _smootherstep(i / 12)),
        ],
        stops: <double>[
          for (var i = 0; i <= 12; i++) 0.3 + 0.7 * (i / 12),
        ],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Blurred, full-height copy of the cover that fills the area above a capped
/// sharp cover on tall windows. Static, so it is cached behind a repaint
/// boundary and crossfades on track change.
class _CoverExtension extends StatelessWidget {
  final Song song;
  final double height;

  const _CoverExtension({required this.song, required this.height});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    return IgnorePointer(
      child: RepaintBoundary(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              for (var i = 0; i <= 6; i++)
                Colors.white.withValues(
                  alpha: 1 - Curves.easeIn.transform(i / 6),
                ),
            ],
            stops: const <double>[0.0, 0.2, 0.35, 0.5, 0.62, 0.72, 0.8],
          ).createShader(bounds),
          child: AnimatedSwitcher(
            duration: PlayerTokens.dSlow,
            switchInCurve: PlayerTokens.cStandard,
            child: ClipRect(
              key: ValueKey(song.filename),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 28,
                  sigmaY: 28,
                  tileMode: TileMode.mirror,
                ),
                child: AlbumArtImage(
                  url: song.coverUrl ?? '',
                  filename: song.filename,
                  cacheVersion: song.mtime,
                  width: width,
                  height: height,
                  // The blur discards detail, so decode small.
                  memCacheWidth: 256,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decodes the neighbouring tracks' covers off-screen at the exact size the
/// player draws them, so a skip slides in a ready image instead of fading
/// one in after the slide.
class _CoverPrefetch extends StatelessWidget {
  final AudioPlayerManager audioManager;
  final Song song;
  final double height;

  const _CoverPrefetch({
    required this.audioManager,
    required this.song,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final queue = audioManager.queueNotifier.value;
    final int i = queue.indexWhere((q) => q.song.filename == song.filename);
    if (i < 0) return const SizedBox.shrink();
    final double w = MediaQuery.sizeOf(context).width;
    final int memW = (w * MediaQuery.devicePixelRatioOf(context)).round();
    return Offstage(
      child: Column(
        children: [
          for (final int j in <int>[i - 1, i + 1])
            if (j >= 0 && j < queue.length)
              AlbumArtImage(
                url: queue[j].song.coverUrl ?? '',
                filename: queue[j].song.filename,
                cacheVersion: queue[j].song.mtime,
                width: w,
                height: height,
                memCacheWidth: memW,
                fit: BoxFit.cover,
              ),
        ],
      ),
    );
  }
}

/// Crossfade + slight parallax for a PageView pane. Always wraps its child
/// (never swaps in and out) so pane state, like lyric scroll position, is
/// kept. Opacity 1.0 paints directly with no extra layer.
class _PaneTransition extends StatelessWidget {
  final ValueListenable<double> position;
  final int index;
  final Widget child;

  const _PaneTransition({
    required this.position,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: position,
      child: child,
      builder: (context, pos, child) {
        final double signed = pos - index;
        final double d = signed.abs().clamp(0.0, 1.0);
        // Eased fade plus a slight recede, so the outgoing pane sinks back
        // into the backdrop rather than sliding off flat.
        return Opacity(
          opacity: 1.0 - Curves.easeOut.transform(d),
          child: FractionalTranslation(
            translation: Offset(signed * 0.2, 0),
            child: Transform.scale(
              scale: 1.0 - 0.04 * Curves.easeOut.transform(d),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Fades its child out as [position] moves away from the Player page (1.0).
/// At rest the opacity is 1.0, so it costs nothing outside a swipe.
class _SwipeFade extends StatelessWidget {
  final ValueListenable<double>? position;
  final Widget child;

  const _SwipeFade({required this.position, required this.child});

  @override
  Widget build(BuildContext context) {
    final ValueListenable<double>? p = position;
    if (p == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: p,
      child: child,
      builder: (context, value, child) {
        final double signed = (value - 1.0).clamp(-1.0, 1.0);
        final double away = (signed.abs() * 1.6).clamp(0.0, 1.0);
        // Cancel the page's horizontal travel (PageView slide minus the
        // _PaneTransition parallax) so the edge-to-edge cover dissolves in
        // place instead of dragging its hard side edges across the screen.
        return FractionalTranslation(
          translation: Offset(signed * 0.8, 0),
          child: Opacity(
            opacity: 1.0 - Curves.easeOut.transform(away),
            child: child,
          ),
        );
      },
    );
  }
}

class _FullBleedInfoBlock extends ConsumerWidget {
  final Song song;
  final Color accent;

  const _FullBleedInfoBlock({required this.song, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShrinkThenWrapText(
                song.title,
                maxLines: 2,
                minFontSize: 16,
                style: PlayerTokens.paneTitle(context).copyWith(fontSize: 22),
              ),
              const SizedBox(height: PlayerTokens.s1),
              ClickableArtistText(
                artist: song.artist,
                style:
                    PlayerTokens.trackSubtitle(context).copyWith(fontSize: 14),
                onArtistTap: (artistName) =>
                    songActionGoToArtistByName(context, ref, artistName),
              ),
              if (song.album.isNotEmpty) ...[
                const SizedBox(height: 2),
                Pressable(
                  alignment: Alignment.centerLeft,
                  onTap: () => songActionGoToAlbum(context, ref, song),
                  child: Text(
                    song.album,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PlayerTokens.meta(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: PlayerTokens.s3),
        // The 48pt hit box leaves the 28pt heart inset by 10pt; pull it back
        // so the icon's edge lines up with the seek bar. Hit-testing follows
        // the transform.
        Transform.translate(
          offset: const Offset(10, 0),
          child: _FullBleedFavoriteButton(song: song, accent: accent),
        ),
      ],
    );
  }
}

/// Same heart behavior as the legacy pane: tap toggles, long-press opens the
/// heart menu, both directions pop and favouriting adds a ring.
class _FullBleedFavoriteButton extends ConsumerStatefulWidget {
  final Song song;
  final Color accent;

  const _FullBleedFavoriteButton({required this.song, required this.accent});

  @override
  ConsumerState<_FullBleedFavoriteButton> createState() =>
      _FullBleedFavoriteButtonState();
}

class _FullBleedFavoriteButtonState
    extends ConsumerState<_FullBleedFavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pop;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;
  bool _showRing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.78)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.78, end: 1.32)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.32, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 56,
      ),
    ]).animate(_controller);
    _ringScale = Tween<double>(begin: 0.35, end: 1.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _ringFade = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.65)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final bool wasFavorite = ref.read(userDataProvider).isFavorite(
          widget.song.filename,
        );
    HapticFeedback.mediumImpact();
    songActionToggleFavorite(
      context,
      ref,
      widget.song.filename,
      widget.song.title,
      showFeedback: false,
    );
    _showRing = !wasFavorite;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isFavorite = ref.watch(
      userDataProvider.select((data) => data.isFavorite(widget.song.filename)),
    );
    return InkResponse(
      radius: 28,
      onTap: _toggle,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showHeartContextMenu(
          context: context,
          ref: ref,
          songFilename: widget.song.filename,
          songTitle: widget.song.title,
        );
      },
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_showRing && _controller.isAnimating && _ringFade.value > 0)
                  Transform.scale(
                    scale: _ringScale.value,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              widget.accent.withValues(alpha: _ringFade.value),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                Transform.scale(scale: _pop.value, child: child),
              ],
            );
          },
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 28,
            color: isFavorite
                ? widget.accent
                : Colors.white.withValues(alpha: PlayerTokens.aSecondary),
          ),
        ),
      ),
    );
  }
}

class _FullBleedVideoToggle extends StatelessWidget {
  final Color accent;
  final AudioPlayerManager audioManager;

  const _FullBleedVideoToggle(
      {required this.accent, required this.audioManager});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackMediaMode>(
      valueListenable: audioManager.effectiveMediaModeNotifier,
      builder: (context, mode, _) {
        final bool isVideo = mode == PlaybackMediaMode.video;
        return TextButton.icon(
          onPressed: () {
            HapticFeedback.selectionClick();
            audioManager.setPreferredMediaMode(
              isVideo ? PlaybackMediaMode.audio : PlaybackMediaMode.video,
            );
          },
          icon: Icon(
            isVideo ? Icons.album_rounded : Icons.movie_outlined,
            size: 18,
          ),
          label: Text(isVideo ? 'Show artwork' : 'Show video'),
          style: TextButton.styleFrom(
            foregroundColor: isVideo ? accent : Colors.white70,
            padding: const EdgeInsets.symmetric(
              horizontal: PlayerTokens.s4,
              vertical: PlayerTokens.s2,
            ),
          ),
        );
      },
    );
  }
}

class _FullBleedVideoSurface extends StatefulWidget {
  final Song song;
  final AudioPlayerManager audioManager;
  final ValueListenable<bool> paneVisible;
  final double placeholderHeight;

  const _FullBleedVideoSurface({
    required this.song,
    required this.audioManager,
    required this.paneVisible,
    required this.placeholderHeight,
  });

  @override
  State<_FullBleedVideoSurface> createState() => _FullBleedVideoSurfaceState();
}

class _FullBleedVideoSurfaceState extends State<_FullBleedVideoSurface>
    with WidgetsBindingObserver {
  static const Duration _syncInterval = Duration(seconds: 1);

  VideoPlayerController? _controller;
  Timer? _syncTimer;
  StreamSubscription<PlayerState>? _stateSub;
  bool _initialized = false;
  Object? _error;
  double _aspectRatio = 1;
  bool _appResumed = true;
  bool _visible = true;
  bool _seeking = false;
  final Stopwatch _sinceLastSeek = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appResumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _visible = widget.paneVisible.value;
    widget.paneVisible.addListener(_onPaneVisibilityChanged);
    _setUp();
  }

  @override
  void didUpdateWidget(_FullBleedVideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paneVisible != widget.paneVisible) {
      oldWidget.paneVisible.removeListener(_onPaneVisibilityChanged);
      widget.paneVisible.addListener(_onPaneVisibilityChanged);
    }
    if (oldWidget.song.filename != widget.song.filename) {
      _tearDown();
      _setUp();
    }
  }

  @override
  void dispose() {
    widget.paneVisible.removeListener(_onPaneVisibilityChanged);
    WidgetsBinding.instance.removeObserver(this);
    _tearDown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final bool resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    _applyPlayState(resync: resumed);
  }

  void _onPaneVisibilityChanged() {
    final bool visible = widget.paneVisible.value;
    if (visible == _visible) return;
    _visible = visible;
    _applyPlayState(resync: visible);
  }

  String? _resolveVideoPath() {
    final tag = widget.audioManager.player.sequenceState.currentSource?.tag;
    if (tag is MediaItem) {
      final Object? path = tag.extras?['videoPath'];
      if (path is String && path.isNotEmpty) return path;
    }
    return widget.song.hasVideo ? widget.song.url : null;
  }

  Future<void> _setUp() async {
    if (Platform.isLinux || Platform.isWindows) return;
    final String? path = _resolveVideoPath();
    if (path == null) return;
    final controller = VideoPlayerController.file(
      File(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
    } catch (e) {
      if (mounted) setState(() => _error = e);
      return;
    }
    if (!mounted || _controller != controller) {
      await controller.dispose();
      return;
    }
    final player = widget.audioManager.player;
    await controller.seekTo(player.position);
    _sinceLastSeek
      ..reset()
      ..start();
    _stateSub = player.playerStateStream.listen((_) {
      if (_controller != controller) return;
      _applyPlayState();
    });
    await _applyPlayState();
    if (mounted) {
      setState(() {
        _aspectRatio = videoDisplayAspectRatio(
          controller.value.aspectRatio,
          controller.value.rotationCorrection,
        );
        _initialized = true;
      });
    }
  }

  Future<void> _applyPlayState({bool resync = false}) async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _syncSyncTimer();
    final player = widget.audioManager.player;
    final bool shouldPlay = player.playing && _appResumed && _visible;
    if (!shouldPlay) {
      if (controller.value.isPlaying) await controller.pause();
      return;
    }
    if (resync) await _seekTo(player.position);
    if (_controller != controller) return;
    if (!controller.value.isPlaying) await controller.play();
  }

  void _syncSyncTimer() {
    final bool wanted = _controller != null && _appResumed && _visible;
    if (wanted == (_syncTimer != null)) return;
    if (wanted) {
      _syncTimer = Timer.periodic(_syncInterval, (_) => _syncToAudio());
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  Future<void> _syncToAudio() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!_appResumed || !_visible) return;
    final player = widget.audioManager.player;
    final VideoSyncAction action = resolveVideoSync(
      audioPosition: player.position,
      videoPosition: controller.value.position,
      audioPlaying: player.playing,
      videoBuffering: controller.value.isBuffering,
      seekInFlight: _seeking,
      msSinceLastSeek: _sinceLastSeek.isRunning
          ? _sinceLastSeek.elapsedMilliseconds.toDouble()
          : double.infinity,
    );
    if (action == VideoSyncAction.none) return;
    await _seekTo(player.position);
  }

  Future<void> _seekTo(Duration position) async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || _seeking) return;
    _seeking = true;
    try {
      await controller.seekTo(position);
    } catch (_) {
      // A seek landing after disposal is not surfaced.
    } finally {
      _seeking = false;
      _sinceLastSeek
        ..reset()
        ..start();
    }
  }

  void _tearDown() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _stateSub?.cancel();
    _stateSub = null;
    _controller?.dispose();
    _controller = null;
    _initialized = false;
    _seeking = false;
    _sinceLastSeek.stop();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;
    if (_error != null || (controller == null && _resolveVideoPath() == null)) {
      return SizedBox(
        width: double.infinity,
        height: widget.placeholderHeight,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: const Center(child: Icon(Icons.videocam_off_rounded)),
        ),
      );
    }
    if (!_initialized || controller == null) {
      return SizedBox(
        width: double.infinity,
        height: widget.placeholderHeight,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          child: const Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: widget.placeholderHeight,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _aspectRatio * 240,
            height: 240,
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinned transport copied from the legacy shell so the seek bar, time labels
/// and control row stay identical in content and style.
class _FullBleedTransportDock extends ConsumerWidget {
  final Song song;
  final Color accent;

  const _FullBleedTransportDock({required this.song, required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AudioPlayerManager audioManager =
        ref.watch(audioPlayerManagerProvider);
    final AudioPlayer player = audioManager.player;
    final ProgressBarType progressBarType =
        ref.watch(settingsProvider.select((s) => s.progressBarType));
    final bool compact = WideLayout.isCompact(context);
    final double bottomSafe = MediaQuery.paddingOf(context).bottom;
    final double bottomPad =
        (compact ? PlayerTokens.s4 : PlayerTokens.s6) + bottomSafe;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? PlayerTokens.s3 : WideLayoutGutter.of(context),
        PlayerTokens.s2,
        compact ? PlayerTokens.s3 : WideLayoutGutter.of(context),
        bottomPad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: StreamBuilder<Duration?>(
              stream: player.durationStream,
              initialData: player.duration,
              builder: (context, snapshot) {
                final Duration total =
                    snapshot.data ?? song.duration ?? Duration.zero;
                switch (progressBarType) {
                  case ProgressBarType.reactive:
                    return ReactiveWaveformProgressBar(
                      key: ValueKey<String>('reactive_${song.filename}'),
                      filename: song.filename,
                      path: song.url,
                      progress: player.position,
                      total: total,
                      positionStream: player.positionStream,
                      onSeek: player.seek,
                    );
                  case ProgressBarType.waveform:
                    return WaveformProgressBar(
                      key: ValueKey<String>('waveform_${song.filename}'),
                      filename: song.filename,
                      path: song.url,
                      progress: player.position,
                      total: total,
                      positionStream: player.positionStream,
                      onSeek: player.seek,
                    );
                  case ProgressBarType.basic:
                    return BasicProgressBar(
                      key: ValueKey<String>('basic_${song.filename}'),
                      player: player,
                      total: total,
                      onSeek: player.seek,
                    );
                }
              },
            ),
          ),
          const SizedBox(height: PlayerTokens.s1),
          _FullBleedControls(
              audioManager: audioManager,
              player: player,
              accent: accent,
              song: song),
        ],
      ),
    );
  }
}

class _FullBleedControls extends StatelessWidget {
  final AudioPlayerManager audioManager;
  final AudioPlayer player;
  final Color accent;
  final Song song;

  const _FullBleedControls({
    required this.audioManager,
    required this.player,
    required this.accent,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LoopMode>(
      stream: player.loopModeStream,
      initialData: player.loopMode,
      builder: (context, loopSnapshot) {
        return StreamBuilder<SequenceState?>(
          stream: player.sequenceStateStream,
          builder: (context, _) => _FullBleedControlRow(
            audioManager: audioManager,
            player: player,
            loopMode: loopSnapshot.data ?? LoopMode.off,
            accent: accent,
            song: song,
          ),
        );
      },
    );
  }
}

class _FullBleedControlRow extends StatelessWidget {
  final AudioPlayerManager audioManager;
  final AudioPlayer player;
  final LoopMode loopMode;
  final Color accent;
  final Song song;

  const _FullBleedControlRow({
    required this.audioManager,
    required this.player,
    required this.loopMode,
    required this.accent,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    final bool canSkipPrevious = player.hasPrevious;
    final bool canSkipNext = player.hasNext;
    final Color disabled =
        Colors.white.withValues(alpha: PlayerTokens.aTertiary);
    // Tappable-but-inactive controls (repeat off, share) get the secondary
    // alpha so they don't read as disabled next to prev/next.
    final Color idle = Colors.white.withValues(alpha: PlayerTokens.aSecondary);
    final bool compact = WideLayout.isCompact(context);
    final double skipSize =
        compact ? PlayerTokens.skipIconSizeCompact : PlayerTokens.skipIconSize;
    final double playSize = compact
        ? PlayerTokens.playControlSizeCompact
        : PlayerTokens.playControlSize;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        RepeatToggleButton(
          loopMode: loopMode,
          accent: accent,
          idleColor: idle,
          onChanged: player.setLoopMode,
        ),
        SkipButton(
          icon: Icons.skip_previous_rounded,
          size: skipSize,
          color: canSkipPrevious ? Colors.white : disabled,
          direction: -1,
          onTap: canSkipPrevious ? player.seekToPrevious : null,
        ),
        PlayPauseDisc(
          audioManager: audioManager,
          accent: accent,
          size: playSize,
        ),
        NextFastForwardButton(
          audioManager: audioManager,
          canSkipNext: canSkipNext,
          size: skipSize,
          color: Colors.white,
          disabledColor: disabled,
          accent: accent,
        ),
        HopIconButton(
          icon: Icons.ios_share_rounded,
          color: idle,
          tooltip: 'Share',
          onPressed: () => songActionShare(song),
        ),
      ],
    );
  }
}
