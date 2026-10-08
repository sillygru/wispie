import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/setup_provider.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../widgets/beat_particle_field.dart';
import '../widgets/player_motion.dart';

const _stepCount = 4;

/// Height of every live preview on the appearance step. One value so the five
/// demos read as a set rather than as five separate decisions.
const _demoHeight = 72.0;

/// The immersive preview draws a phone-shaped screen, so it needs a strip wide
/// and tall enough to hold one at a readable scale.
const _layoutDemoHeight = 104.0;

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _usernameController = TextEditingController();

  late final AnimationController _introController;
  late final AnimationController _outroController;

  /// Shared loop for the progress bar demo, so swapping modes keeps the phase.
  late final AnimationController _demoClock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  )..value = 0.2;

  int _currentPage = 0;
  bool _isLoading = false;
  bool _permissionGranted = false;
  bool _permissionDeniedOnce = false;
  bool _showIntroScreen = true;

  List<Map<String, String>> _musicFolders = [];

  @override
  void initState() {
    super.initState();
    _loadInitialFolders();
    _checkPermissionStatus();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _outroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  Future<void> _loadInitialFolders() async {
    final storage = StorageService();
    final folders = await storage.getMusicFolders();
    if (mounted) {
      setState(() => _musicFolders = folders);
    }
  }

  Future<void> _checkPermissionStatus() async {
    final granted = await PermissionService.instance.hasStoragePermission();
    if (mounted) {
      setState(() => _permissionGranted = granted);
    }
  }

  void _syncDemoClock() {
    if (_currentPage == 1) {
      if (!_demoClock.isAnimating) _demoClock.repeat();
    } else {
      _demoClock.stop();
    }
  }

  @override
  void dispose() {
    _demoClock.dispose();
    _introController.dispose();
    _outroController.dispose();
    _pageController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _stepCount - 1) {
      _pageController.nextPage(
        duration: AppTokens.dSlow,
        curve: AppTokens.cEmphasized,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: AppTokens.dBase,
        curve: AppTokens.cStandard,
      );
    }
  }

  Future<void> _addFolder() async {
    final storage = StorageService();
    final Map<String, String>? selection;
    try {
      selection = await storage.pickMusicFolder(context);
    } on FolderPickerUnavailable catch (e) {
      if (mounted) appSnack(context, e.userFacingHint);
      return;
    }
    if (selection == null) return;
    final selectedPath = selection['path'] ?? '';
    if (selectedPath.isEmpty) {
      if (mounted) {
        appSnack(context, 'Unable to access selected folder');
      }
      return;
    }

    await storage.addMusicFolder(
      selectedPath,
      selection['treeUri'],
      iosBookmarkId: selection['iosBookmarkId'],
      platform: selection['platform'],
    );

    ref.invalidate(musicFoldersProvider);
    ref.invalidate(songsProvider);
    await _loadInitialFolders();

    if (mounted) {
      appSnack(context, 'Music folder added');
    }
  }

  Future<void> _removeFolder(Map<String, String> folder) async {
    final storage = StorageService();
    await storage.removeMusicFolder(
      folder['path'] ?? '',
      iosBookmarkId: folder['iosBookmarkId'],
    );

    ref.invalidate(musicFoldersProvider);
    ref.invalidate(songsProvider);
    await _loadInitialFolders();

    if (mounted) {
      appSnack(context, 'Music folder removed');
    }
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;

    setState(() => _isLoading = true);

    var isGranted = await PermissionService.instance.hasStoragePermission();
    if (isGranted) {
      setState(() {
        _permissionGranted = true;
        _isLoading = false;
      });
      return;
    }

    final isPermanentlyDenied =
        await PermissionService.instance.isStoragePermissionPermanentlyDenied();
    if (isPermanentlyDenied) {
      setState(() {
        _permissionDeniedOnce = true;
        _isLoading = false;
      });
      await openAppSettings();
      isGranted = await PermissionService.instance.hasStoragePermission();
      if (isGranted && mounted) {
        setState(() => _permissionGranted = true);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    final granted = await PermissionService.instance.requestStoragePermission();
    if (granted && mounted) {
      setState(() => _permissionGranted = true);
    } else if (await PermissionService.instance
            .isStoragePermissionPermanentlyDenied() &&
        mounted) {
      setState(() => _permissionDeniedOnce = true);
    } else if (mounted) {
      appSnack(
        context,
        'Storage permission is required to scan your music library.',
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeFinishSetup() async {
    final name = _usernameController.text.trim();
    if (name.isEmpty) {
      appSnack(context, 'Please enter a display name');
      _pageController.animateToPage(
        0,
        duration: AppTokens.dBase,
        curve: AppTokens.cStandard,
      );
      return;
    }

    setState(() => _isLoading = true);

    await _outroController.forward();

    try {
      final storage = StorageService();
      await storage.setIsLocalMode(true);
      await storage.setSetupComplete(true);

      await ref.read(authProvider.notifier).setDisplayName(name);
      ref.read(setupProvider.notifier).setComplete(true);
    } catch (e) {
      if (mounted) {
        appSnack(context, 'Setup error: $e');
        _outroController.reverse();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ------------------------------------------------------------------- INTRO
  Widget _buildIntro() {
    final accent = AppTokens.accentOf(context, ref);
    final solids = _Solids.of(context);

    return AnimatedBuilder(
      animation: _introController,
      builder: (context, _) {
        final t = _introController.value;
        final wipe = _at(t, 0.0, 0.5, Curves.easeInOutCubic);
        final tagline = _at(t, 0.7, 1.0);
        final button = _at(t, 0.8, 1.0);

        return Stack(
          children: [
            // Solid colour block, wiped down from the top. It has to reach past
            // the baseline of the wordmark on a window with no system insets,
            // where the letter row lands exactly on 60% of the height.
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.68 * wipe,
                  widthFactor: 1,
                  child: ColoredBox(color: accent),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (i, letter)
                                  in 'wispie'.split('').indexed)
                                _SpringLetter(
                                  letter: letter,
                                  color: AppTokens.onAccent(accent),
                                  value: _at(
                                    t,
                                    0.1 + i * 0.07,
                                    0.5 + i * 0.07,
                                    Curves.easeOutBack,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTokens.s5,
                        0,
                        AppTokens.s5,
                        AppTokens.s5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Opacity(
                            opacity: tagline,
                            child: Text(
                              'Your music stays on your device. Setting up '
                              'takes about a minute.',
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: AppTokens.fgSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppTokens.s5),
                          Opacity(
                            opacity: button,
                            child: _BlockButton(
                              label: 'Get started',
                              accent: accent,
                              solids: solids,
                              onPressed: () =>
                                  setState(() => _showIntroScreen = false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------- SETUP
  Widget _buildMainSetupScreen() {
    final accent = AppTokens.accentOf(context, ref);
    final solids = _Solids.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final canContinue =
        _currentPage != 0 || _usernameController.text.trim().isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: _currentPage > 0
                      ? IconButton(
                          icon: const AppIcon(AppIcons.arrowBack),
                          onPressed: _previousPage,
                          tooltip: 'Previous step',
                        )
                      : null,
                ),
                Expanded(
                  child: _ProgressBar(
                    value: (_currentPage + 1) / _stepCount,
                    accent: accent,
                    solids: solids,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${_currentPage + 1}/$_stepCount',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.fgTertiary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The whole body is what launches on the last step. It used to be a
          // fixed-height strip above the pages, which left a band of dead space
          // and threw away half the flight.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return AnimatedBuilder(
                  animation: _outroController,
                  builder: (context, _) {
                    final v = _outroController.value;
                    double dy = 0;
                    double dx = 0;
                    double scale = 1;
                    double tilt = 0;
                    double opacity = 1;

                    if (v > 0 && v < 0.16) {
                      final arc = math.sin(v / 0.16 * math.pi);
                      dy = arc * 16.0;
                      scale = 1.0 - arc * 0.05;
                    } else if (v >= 0.16) {
                      final lt = (v - 0.16) / 0.84;
                      final launch = lt * lt;
                      dy = -launch * constraints.maxHeight * 1.9;
                      dx = math.sin(lt * math.pi) * 48.0;
                      tilt = lt * 1.4;
                      scale = (1.0 - launch * 0.35).clamp(0.1, 1.0);
                      opacity = (1.0 - ((lt - 0.55) / 0.45).clamp(0.0, 1.0))
                          .clamp(0.0, 1.0);
                    }

                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.rotate(
                        angle: tilt,
                        child: Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity,
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              onPageChanged: (page) {
                                setState(() => _currentPage = page);
                                _syncDemoClock();
                              },
                              children: [
                                _StepBody(
                                  active: _currentPage == 0,
                                  builder: (context, t) =>
                                      _buildNameStep(t, accent, solids),
                                ),
                                _StepBody(
                                  active: _currentPage == 1,
                                  builder: (context, t) => _buildAppearanceStep(
                                    t,
                                    settings,
                                    notifier,
                                    accent,
                                    solids,
                                  ),
                                ),
                                _StepBody(
                                  active: _currentPage == 2,
                                  builder: (context, t) =>
                                      _buildFoldersStep(t, accent, solids),
                                ),
                                _StepBody(
                                  active: _currentPage == 3,
                                  builder: (context, t) => _buildReadyStep(
                                    t,
                                    settings,
                                    accent,
                                    solids,
                                  ),
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: _BlockButton(
              label: _currentPage == _stepCount - 1
                  ? (_isLoading ? 'Setting things up' : 'Start listening')
                  : 'Continue',
              accent: accent,
              solids: solids,
              onPressed: _isLoading || !canContinue
                  ? null
                  : (_currentPage == _stepCount - 1
                      ? _executeFinishSetup
                      : _nextPage),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AmbientScaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _showIntroScreen
            ? KeyedSubtree(key: const ValueKey('intro'), child: _buildIntro())
            : KeyedSubtree(
                key: const ValueKey('setup'),
                child: _buildMainSetupScreen(),
              ),
      ),
    );
  }

  // ------------------------------------------------------------- STEP 1: NAME
  Widget _buildNameStep(Animation<double> t, Color accent, _Solids solids) {
    final name = _usernameController.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      children: [
        _Headline(
          t: t,
          title: 'What should we call you?',
          subtitle:
              'Wispie uses your name to greet you and to sign your listening '
              'history. Nothing leaves this device either way.',
        ),
        const SizedBox(height: AppTokens.s5),
        _Rise(
          t: t,
          start: 0.25,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: solids.raised(),
              borderRadius: AppTokens.brLg,
            ),
            child: TextField(
              controller: _usernameController,
              onChanged: (_) => setState(() {}),
              enabled: !_isLoading,
              cursorColor: accent,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
                color: AppTokens.fgPrimary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                hintText: 'Your name',
                hintStyle: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  color: AppTokens.fgTertiary,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 22),
              ),
              onSubmitted: (_) {
                if (_usernameController.text.trim().isNotEmpty) {
                  _nextPage();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: AppTokens.s4),
        _Rise(
          t: t,
          start: 0.4,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedOpacity(
              duration: AppTokens.dBase,
              opacity: name.isEmpty ? 0 : 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppTokens.brPill,
                ),
                child: Text(
                  'Nice to meet you, $name.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.onAccent(accent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------- STEP 2: APPEARANCE
  Widget _buildAppearanceStep(
    Animation<double> t,
    SettingsState settings,
    SettingsNotifier notifier,
    Color accent,
    _Solids solids,
  ) {
    const intensities = [
      (PlayerMotionIntensity.subtle, 'Subtle'),
      (PlayerMotionIntensity.balanced, 'Balanced'),
      (PlayerMotionIntensity.bold, 'Bold'),
    ];

    // Previews only run while this page is the one on screen. The PageView
    // keeps its children alive, so without this the other four steps would
    // keep five tickers alive behind the one the user is reading.
    final live = _currentPage == 1;

    Widget demo(_DemoKind kind, bool on,
            {bool reactive = true,
            double height = _demoHeight,
            PlayerMotionIntensity intensity = PlayerMotionIntensity.balanced,
            double customIntensity = 0.5}) =>
        _DemoPreview(
          kind: kind,
          accent: accent,
          solids: solids,
          on: on,
          reactive: reactive,
          height: height,
          intensity: intensity,
          customIntensity: customIntensity,
          live: live,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      children: [
        _Headline(
          t: t,
          title: 'Make it look the way you like.',
          subtitle:
              'Everything on this page also lives in Settings, so you can '
              'change it whenever you want.',
        ),
        const SizedBox(height: AppTokens.s5),
        _Rise(
          t: t,
          start: 0.12,
          child: _SettingBlock(
            solids: solids,
            title: 'Immersive design',
            subtitle: 'A full-bleed cover player and gradient detail screens.',
            preview: demo(
              _DemoKind.immersive,
              settings.fullBleedDesignEnabled,
              height: _layoutDemoHeight,
            ),
            trailing: _Toggle(
              accent: accent,
              value: settings.fullBleedDesignEnabled,
              onChanged: notifier.setFullBleedDesignEnabled,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Rise(
          t: t,
          start: 0.2,
          child: _SettingBlock(
            solids: solids,
            title: 'Audio visualizer',
            subtitle: 'Bars over the artwork while you listen. Synced follows '
                'the song rather than a random pattern.',
            preview: demo(_DemoKind.spectrum,
                settings.visualizerMode != VisualizerMode.off),
            child: _Choice<VisualizerMode>(
              accent: accent,
              solids: solids,
              value: settings.visualizerMode,
              onChanged: notifier.setVisualizerMode,
              options: const [
                (VisualizerMode.off, 'Off'),
                (VisualizerMode.classic, 'Classic'),
                (VisualizerMode.synced, 'Synced'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Rise(
          t: t,
          start: 0.28,
          child: _SettingBlock(
            solids: solids,
            title: 'Beat-reactive cover',
            subtitle: settings.fullBleedDesignEnabled
                ? 'Unavailable while immersive design is on.'
                : 'The album art breathes on every beat.',
            preview: demo(
              _DemoKind.cover,
              settings.beatReactiveCoverEnabled &&
                  !settings.fullBleedDesignEnabled,
              intensity: settings.coverMotionIntensity,
              customIntensity: settings.coverMotionCustomIntensity,
            ),
            trailing: _Toggle(
              accent: accent,
              value: settings.beatReactiveCoverEnabled &&
                  !settings.fullBleedDesignEnabled,
              onChanged: settings.fullBleedDesignEnabled
                  ? null
                  : notifier.setBeatReactiveCoverEnabled,
            ),
            child: settings.beatReactiveCoverEnabled &&
                    !settings.fullBleedDesignEnabled
                ? _Choice<PlayerMotionIntensity>(
                    accent: accent,
                    solids: solids,
                    value: settings.coverMotionIntensity,
                    onChanged: notifier.setCoverMotionIntensity,
                    options: intensities,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        _Rise(
          t: t,
          start: 0.36,
          child: _SettingBlock(
            solids: solids,
            title: 'Beat-reactive particles',
            subtitle: 'Motes drift across the player, and each beat carries '
                'them further instead of just blinking them.',
            preview: demo(
              _DemoKind.particles,
              settings.beatReactiveParticlesEnabled,
              intensity: settings.particleMotionIntensity,
              customIntensity: settings.particleMotionCustomIntensity,
            ),
            trailing: _Toggle(
              accent: accent,
              value: settings.beatReactiveParticlesEnabled,
              onChanged: notifier.setBeatReactiveParticlesEnabled,
            ),
            child: settings.beatReactiveParticlesEnabled
                ? _Choice<PlayerMotionIntensity>(
                    accent: accent,
                    solids: solids,
                    value: settings.particleMotionIntensity,
                    onChanged: notifier.setParticleMotionIntensity,
                    options: intensities,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        _Rise(
          t: t,
          start: 0.44,
          child: _SettingBlock(
            solids: solids,
            title: 'Progress bar',
            subtitle: 'Draw the song itself as a waveform instead of a plain '
                'line. Sound reactive makes it move as it plays.',
            preview: AnimatedSwitcher(
              duration: AppTokens.dBase,
              switchInCurve: AppTokens.cStandard,
              switchOutCurve: AppTokens.cStandard,
              child: KeyedSubtree(
                key: ValueKey(settings.progressBarType),
                child: _DemoPreview(
                  kind: _DemoKind.waveform,
                  accent: accent,
                  solids: solids,
                  on: settings.progressBarType != ProgressBarType.basic,
                  reactive:
                      settings.progressBarType == ProgressBarType.reactive,
                  height: _demoHeight,
                  live: live,
                  clock: _demoClock,
                ),
              ),
            ),
            child: _Choice<ProgressBarType>(
              accent: accent,
              solids: solids,
              value: settings.progressBarType,
              onChanged: notifier.setProgressBarType,
              options: const [
                (ProgressBarType.basic, 'Standard'),
                (ProgressBarType.waveform, 'Waveform'),
                (ProgressBarType.reactive, 'Sound reactive'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- STEP 3: FOLDERS
  Widget _buildFoldersStep(
    Animation<double> t,
    Color accent,
    _Solids solids,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Headline(
            t: t,
            title: 'Where is your music?',
            subtitle: 'Point Wispie at the folders your songs live in. It only '
                'reads them, and you can add as many as you like.',
          ),
          const SizedBox(height: AppTokens.s5),
          if (Platform.isAndroid && !_permissionGranted) ...[
            _Rise(
              t: t,
              start: 0.2,
              child: _SettingBlock(
                solids: solids,
                title: 'Storage permission',
                subtitle: 'Wispie needs it to find audio files on this device.',
                child: _BlockButton(
                  label: _permissionDeniedOnce
                      ? 'Open system settings'
                      : 'Grant permission',
                  accent: accent,
                  solids: solids,
                  onPressed: _isLoading ? null : _requestPermission,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: _Rise(
              t: t,
              start: 0.3,
              child: _musicFolders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(
                            AppIcons.folder,
                            size: 40,
                            color: accent,
                          ),
                          const SizedBox(height: AppTokens.s3),
                          const Text(
                            'No folders yet',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTokens.fgPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTokens.s1),
                          const Text(
                            'Add the one that holds your songs.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTokens.fgTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _musicFolders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final folder = _musicFolders[index];
                        final path = folder['path'] ?? '';
                        final name = p.basename(path);

                        return Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          decoration: BoxDecoration(
                            color: solids.raised(),
                            borderRadius: AppTokens.brMd,
                          ),
                          child: Row(
                            children: [
                              AppRowIcon(
                                icon: AppIcons.folder,
                                color: accent,
                              ),
                              const SizedBox(width: AppTokens.s3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isEmpty ? path : name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTokens.fgPrimary,
                                      ),
                                    ),
                                    Text(
                                      path,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTokens.fgTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove folder',
                                icon: const AppIcon(AppIcons.delete, size: 18),
                                onPressed: () => _removeFolder(folder),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppTokens.s3),
          _Rise(
            t: t,
            start: 0.4,
            child: _BlockButton(
              label: 'Add a folder',
              accent: accent,
              solids: solids,
              tonal: true,
              onPressed: _addFolder,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- STEP 4: READY
  Widget _buildReadyStep(
    Animation<double> t,
    SettingsState settings,
    Color accent,
    _Solids solids,
  ) {
    final name = _usernameController.text.trim();

    // Full-width rows rather than a row of tiles: three columns this narrow
    // cannot hold a value like "Sound reactive" or a label like "Music folders"
    // without either truncating it or wrapping onto a second line, and a
    // wrapped label shifts the tile's number out of line with its neighbours.
    final summary = <(String, String)>[
      ('Music folders', '${_musicFolders.length}'),
      ('Immersive design', _yesNo(settings.fullBleedDesignEnabled)),
      ('Audio visualizer', _visualizerLabel(settings.visualizerMode)),
      ('Progress bar', _progressBarLabel(settings.progressBarType)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      children: [
        _Headline(
          t: t,
          title: name.isEmpty ? 'You are all set.' : 'You are all set, $name.',
          subtitle: 'Here is what we set up. You can change any of it later '
              'from Settings.',
        ),
        const SizedBox(height: AppTokens.s5),
        for (final (i, row) in summary.indexed) ...[
          if (i > 0) const SizedBox(height: AppTokens.s2),
          _Rise(
            t: t,
            start: 0.2 + i * 0.06,
            child: _SummaryRow(
              solids: solids,
              accent: accent,
              // The first row carries the one number that matters, so it is the
              // one block that gets the accent fill.
              highlight: i == 0,
              label: row.$1,
              value: row.$2,
            ),
          ),
        ],
      ],
    );
  }
}

String _yesNo(bool value) => value ? 'On' : 'Off';

String _visualizerLabel(VisualizerMode mode) => switch (mode) {
      VisualizerMode.off => 'Off',
      VisualizerMode.classic => 'Classic',
      VisualizerMode.synced => 'Synced',
    };

String _progressBarLabel(ProgressBarType type) => switch (type) {
      ProgressBarType.basic => 'Standard',
      ProgressBarType.waveform => 'Waveform',
      ProgressBarType.reactive => 'Sound reactive',
    };

// -------------------------------------------------------------- HELPERS

/// The onboarding flow paints solid fills instead of the app's translucent
/// tonal washes.
///
/// Behind this screen sits the ambient bloom, which is already a gradient, so a
/// 4% white card laid over it reads as a smear rather than as a block.
/// Blending the same values against the scaffold colour bakes them into one
/// opaque colour, which is what lets the cards here carry weight the same way
/// the app's do — with flat colour rather than with a glow.
class _Solids {
  const _Solids(this.canvas);

  factory _Solids.of(BuildContext context) =>
      _Solids(Theme.of(context).scaffoldBackgroundColor);

  final Color canvas;

  /// A block lifted off the page.
  Color raised([double alpha = 0.05]) =>
      Color.alphaBlend(Colors.white.withValues(alpha: alpha), canvas);

  /// A block sunk into it.
  Color well([double alpha = 0.16]) =>
      Color.alphaBlend(Colors.black.withValues(alpha: alpha), canvas);

  /// A block in the accent, quiet enough to sit behind text.
  Color accentWash(Color accent, [double alpha = 0.12]) =>
      Color.alphaBlend(accent.withValues(alpha: alpha), canvas);
}

double _at(double t, double begin, double end,
    [Curve curve = Curves.easeOutCubic]) {
  return Interval(begin, end, curve: curve).transform(t);
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: AppTokens.dFast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and rises a child in on the step's timeline. The overshoot on the
/// curve gives it a bit of spring rather than a flat ease.
class _Rise extends StatelessWidget {
  const _Rise({required this.t, required this.start, required this.child});

  final Animation<double> t;
  final double start;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) {
        final v = _at(
          t.value,
          start,
          math.min(start + 0.4, 1.0),
          Curves.easeOutBack,
        );
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 28),
            child: child,
          ),
        );
      },
    );
  }
}

/// Each word of a headline rises out of its own clip, one after another.
class _Headline extends StatelessWidget {
  const _Headline({required this.t, required this.title, this.subtitle});

  final Animation<double> t;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 40,
      height: 1.1,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.4,
      color: AppTokens.fgPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            for (final (i, word) in title.split(' ').indexed)
              ClipRect(
                child: AnimatedBuilder(
                  animation: t,
                  builder: (context, _) {
                    final v = _at(
                      t.value,
                      i * 0.06,
                      math.min(i * 0.06 + 0.45, 1.0),
                      Curves.easeOutBack,
                    );
                    return Transform.translate(
                      offset: Offset(0, (1 - v) * 48),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(word, style: style),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        if (subtitle != null)
          _Rise(
            t: t,
            start: 0.25,
            child: Padding(
              padding: const EdgeInsets.only(top: AppTokens.s3),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppTokens.fgSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SpringLetter extends StatelessWidget {
  const _SpringLetter({
    required this.letter,
    required this.color,
    required this.value,
  });

  final String letter;
  final Color color;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 64),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 150,
            height: 0.9,
            fontWeight: FontWeight.w900,
            letterSpacing: -6,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Owns one step's entrance timeline. It plays again each time the step
/// becomes the visible page.
class _StepBody extends StatefulWidget {
  const _StepBody({required this.active, required this.builder});

  final bool active;
  final Widget Function(BuildContext context, Animation<double> t) builder;

  @override
  State<_StepBody> createState() => _StepBodyState();
}

class _StepBodyState extends State<_StepBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _StepBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.accent,
    required this.solids,
  });

  final double value;
  final Color accent;
  final _Solids solids;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppTokens.dSlow,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Stack(
          children: [
            SizedBox(
              height: 6,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: solids.well(),
                  borderRadius: AppTokens.brPill,
                ),
              ),
            ),
            FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppTokens.brPill,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlockButton extends StatelessWidget {
  const _BlockButton({
    required this.label,
    required this.accent,
    required this.solids,
    this.onPressed,
    this.tonal = false,
  });

  final String label;
  final Color accent;
  final _Solids solids;
  final VoidCallback? onPressed;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final Color background;
    final Color foreground;
    if (!enabled) {
      background = solids.raised(0.07);
      foreground = AppTokens.fgTertiary;
    } else if (tonal) {
      background = solids.raised(0.09);
      foreground = AppTokens.fgPrimary;
    } else {
      background = accent;
      foreground = AppTokens.onAccent(accent);
    }

    return _Pressable(
      onTap: onPressed == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed!();
            },
      child: AnimatedContainer(
        duration: AppTokens.dBase,
        curve: AppTokens.cStandard,
        width: double.infinity,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppTokens.brLg,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _SettingBlock extends StatelessWidget {
  const _SettingBlock({
    required this.solids,
    required this.title,
    required this.subtitle,
    this.preview,
    this.trailing,
    this.child,
  });

  final _Solids solids;
  final String title;
  final String subtitle;

  /// A live demo of whatever this block controls, shown above the control.
  final Widget? preview;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: solids.raised(),
        borderRadius: AppTokens.brLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTokens.fgPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: AppTokens.fgSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppTokens.s3),
                trailing!,
              ],
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: AppTokens.s4),
            preview!,
          ],
          if (child != null) ...[
            const SizedBox(height: AppTokens.s3),
            child!,
          ],
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final Color accent;
  final bool value;

  /// Null disables the switch — for a setting the current combination of other
  /// settings makes unavailable.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      activeTrackColor: accent,
      onChanged: onChanged == null
          ? null
          : (v) {
              HapticFeedback.selectionClick();
              onChanged!(v);
            },
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.accent,
    required this.solids,
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final Color accent;
  final _Solids solids;
  final T value;
  final ValueChanged<T> onChanged;
  final List<(T, String)> options;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, option) in options.indexed)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : AppTokens.s1),
              child: _Pressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(option.$1);
                },
                child: AnimatedContainer(
                  duration: AppTokens.dFast,
                  curve: AppTokens.cStandard,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option.$1 == value ? accent : solids.well(0.10),
                    borderRadius: AppTokens.brPill,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppTokens.s2),
                      child: Text(
                        option.$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: option.$1 == value
                              ? AppTokens.onAccent(accent)
                              : AppTokens.fgSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.solids,
    required this.accent,
    required this.highlight,
    required this.label,
    required this.value,
  });

  final _Solids solids;
  final Color accent;
  final bool highlight;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final background = highlight ? accent : solids.raised();
    final foreground =
        highlight ? AppTokens.onAccent(accent) : AppTokens.fgPrimary;
    final caption =
        highlight ? foreground.withValues(alpha: 0.78) : AppTokens.fgTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppTokens.brLg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: caption,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.s3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- DEMOS

/// Turns a looping [AnimationController] into a monotonic clock.
///
/// [ParticleSystem] is built on the assumption that time only moves forward:
/// motes record a `bornAt`, live 14-40s, and are retired and respawned against
/// `_now`. An animation's value is not that — it repeats, so it snaps from 1
/// back to 0 and every age in the field goes negative at once, which
/// [ParticleSystem.fadeOf] clamps to zero and the whole field blinks out.
///
/// So the wrapped value drives the *music* (the beat grid, the playhead, the
/// cover pulse — all of which genuinely do loop) and this drives the
/// *simulation*, which keeps living across loop points exactly as it does on a
/// screen that has been playing for ten minutes.
class _DemoClock {
  _DemoClock(this._controller, this.secondsPerLoop) {
    _controller.addListener(_tick);
  }

  final AnimationController _controller;

  /// Real seconds one pass of the animation represents.
  final double secondsPerLoop;

  double _elapsed = 0;
  double _lastValue = 0;

  double get elapsed => _elapsed;

  void _tick() {
    final value = _controller.value;
    var delta = value - _lastValue;
    // Backwards means the animation looped rather than that time ran out.
    if (delta < 0) delta += 1;
    _elapsed += delta * secondsPerLoop;
    _lastValue = value;
  }

  void dispose() => _controller.removeListener(_tick);
}

/// Which effect a [_DemoPreview] stands in for.
enum _DemoKind { immersive, spectrum, particles, cover, waveform }

/// A silent, looping stand-in for one effect, so a toggle can show its
/// consequence while the user is still on the setup screen.
///
/// Deliberately not the real widgets: the player versions need a decoded file
/// and a live audio session, and the one thing a preview has to be is something
/// that can run before any of that exists. Switching the setting off freezes
/// the demo rather than hiding it — the difference between the two states is
/// the thing worth showing.
class _DemoPreview extends StatefulWidget {
  const _DemoPreview({
    required this.kind,
    required this.accent,
    required this.solids,
    required this.on,
    required this.live,
    this.reactive = true,
    this.height = _demoHeight,
    this.intensity = PlayerMotionIntensity.balanced,
    this.customIntensity = 0.5,
    this.clock,
  });

  /// When set, the demo reads its phase from this shared clock instead of its
  /// own, so a demo swapped out mid-loop picks up where the last one left off.
  final AnimationController? clock;

  final _DemoKind kind;
  final Color accent;
  final _Solids solids;
  final bool on;
  final double height;

  /// Whether the effect answers the beat, as opposed to only being present.
  /// The progress bar has two settings that both draw a waveform and only one
  /// of them moves, so [on] alone cannot tell the two apart.
  final bool reactive;

  /// The motion preset this preview should render at, so the intensity control
  /// directly under it is previewed rather than merely labelled.
  final PlayerMotionIntensity intensity;
  final double customIntensity;

  /// False while the appearance step is not the visible page.
  final bool live;

  @override
  State<_DemoPreview> createState() => _DemoPreviewState();
}

class _DemoPreviewState extends State<_DemoPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ownController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  );

  AnimationController get _controller => widget.clock ?? _ownController;

  /// Monotonic seconds for the simulation, deliberately not the animation's own
  /// value.
  ///
  /// The controller repeats, so its value wraps from 1 back to 0. Handing that
  /// to [ParticleSystem.update] is what made the field blink out a few seconds
  /// in: every mote records a `bornAt` from the *previous* pass, so after the
  /// wrap `age` comes back negative, [ParticleSystem.fadeOf] clamps it to zero
  /// and the whole field is invisible until the clock climbs past the old spawn
  /// times again. Motes live 14-40s here, so the field was never going to loop
  /// in 6s anyway — the music loops, the field keeps living.
  /// Lazily self-initialising rather than assigned in `initState`, so it also
  /// resolves for instances that already existed when this field was added —
  /// a hot reload does not re-run `initState`, and a plain `late final` would
  /// throw on every frame of an already-mounted preview.
  late final _DemoClock _clock = _DemoClock(_controller, 6);

  /// The real simulation, not a lookalike. A hand-rolled loop of dots drifting
  /// on a sine is what this preview used to be, and it could not match the
  /// field because most of what the field *is* lives in [ParticleSystem] — the
  /// curl flow field, per-mote depth and response, beat wavefronts that reach
  /// each mote at a different time. Reusing it keeps the preview honest for as
  /// long as the field is tuned.
  final ParticleSystem _particles = ParticleSystem();

  @override
  void initState() {
    super.initState();
    _ownController.value = 0.2;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _DemoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.on != widget.on || oldWidget.live != widget.live) _sync();
  }

  void _sync() {
    if (widget.clock != null) return;
    final running = widget.on && widget.live;
    if (running && !_ownController.isAnimating) {
      _ownController.repeat();
    } else if (!running && _ownController.isAnimating) {
      _ownController.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _ownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppTokens.brMd,
      child: ColoredBox(
        color: widget.solids.well(0.22),
        child: CustomPaint(
          painter: _DemoPainter(
            kind: widget.kind,
            accent: widget.accent,
            solids: widget.solids,
            on: widget.on,
            reactive: widget.reactive,
            particles: _particles,
            clock: _clock,
            spec: widget.intensity == PlayerMotionIntensity.custom
                ? MotionIntensitySpec.custom(widget.customIntensity)
                : MotionIntensitySpec.of(widget.intensity),
            t: _controller,
          ),
          size: Size(double.infinity, widget.height),
        ),
      ),
    );
  }
}

class _DemoPainter extends CustomPainter {
  _DemoPainter({
    required this.kind,
    required this.accent,
    required this.solids,
    required this.on,
    required this.reactive,
    required this.particles,
    required this.clock,
    required this.spec,
    required this.t,
  }) : super(repaint: t);

  final _DemoKind kind;
  final Color accent;
  final _Solids solids;
  final bool on;
  final bool reactive;

  /// Owned by the preview's state so motes persist across frames. A painter
  /// that built its own system would restart the field on every rebuild, which
  /// looks like the motes blinking.
  final ParticleSystem particles;

  /// Monotonic simulation time, read live rather than captured — `paint` runs
  /// off the repaint ticker without a rebuild.
  final _DemoClock clock;

  /// The motion preset being previewed. Passed in rather than computed in the
  /// painter so the intensity control under the demo and the demo itself cannot
  /// disagree.
  final MotionIntensitySpec spec;

  final Animation<double> t;

  /// Seconds on the shared loop. This one *is* meant to wrap, so the music
  /// stays in step with the waveform and cover previews beside it.
  double get _seconds => t.value * 6;

  /// Simulation time. Never wraps; see [_DemoClock].
  double get _elapsed => clock.elapsed;

  /// 0..1 on every beat: a hard attack and a slow tail, at a tempo the whole
  /// set shares so the waveform and the particles agree with each other. Zero
  /// when the effect is present but not beat-driven.
  double get _beat {
    if (!reactive) return 0;
    final phase = _seconds * 2 * math.pi * 2; // 120 BPM
    final impulse = math.max(0.0, math.sin(phase));
    return math.pow(impulse, 8).toDouble();
  }

  /// The beat grid the real field would be fed, rebuilt for this frame.
  ///
  /// The preview has no audio and no analysis, so the grid is synthesised: a
  /// fixed 120 BPM with a bar accent, and band energies that decay from each
  /// hit. [ParticleSystem] needs a `BeatFrame` carrying a `beatIndex` so it can
  /// tell one beat from the next and spawn a wavefront per beat — without it
  /// the field would have band envelopes to drift on but nothing to surge on,
  /// which is the half of the effect that reads.
  BeatFrame get _beatFrame {
    final period = 0.5; // 120 BPM
    final index = (_seconds / period).floor();
    final sinceBeat = _seconds - index * period;
    final isDownbeat = index % 4 == 0;
    final strength =
        (isDownbeat ? 1.0 : 0.62) * (1.0 + 0.12 * math.sin(index * 1.7));

    // Fast attack, exponential tail — the shape a real transient has.
    final attack = math.min(1.0, sinceBeat / 0.012);
    final decay = math.exp(-sinceBeat / 0.16);

    if (!reactive) {
      // Present but not driven: the field keeps its ambient life and simply
      // never hears a beat, which is exactly what the setting does.
      return BeatFrame(
        air: 0.22 + 0.1 * math.sin(_seconds * 2.2),
        breath: 0.30 + 0.22 * math.sin(_seconds * 1.4),
        bass: 0.18,
        mid: 0.22,
      );
    }

    // `strength` is the raw landing force and must NOT carry the envelope.
    // The field recruits motes with `wave.power >= particle.beatThreshold`
    // (0.15-0.9), and `power` is `frame.strength` captured the instant the
    // beat lands — where an enveloped value is ~0 by definition, so every
    // wavefront would spawn at zero power and no mote would ever be kicked.
    // `pulse` and the band energies are the enveloped ones.
    return BeatFrame(
      pulse: strength * attack * decay,
      rebound: -0.16 * strength * attack * decay,
      sway: math.sin(index * 2.39) * strength * attack * decay,
      bass: strength * attack * decay,
      mid: strength * attack * decay * 0.8,
      air: 0.18 + 0.12 * math.sin(_seconds * 2.2),
      breath: 0.28 + 0.2 * math.sin(_seconds * 1.4),
      beatIndex: index,
      isDownbeat: isDownbeat,
      strength: strength,
      hasBeat: true,
    );
  }

  Color get _strong => on ? accent : solids.accentWash(accent, 0.34);

  Color get _weak =>
      on ? solids.accentWash(accent, 0.34) : solids.accentWash(accent, 0.16);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    switch (kind) {
      case _DemoKind.spectrum:
        _paintSpectrum(canvas, size, paint);
      case _DemoKind.waveform:
        _paintWaveform(canvas, size, paint);
      case _DemoKind.particles:
        _paintParticles(canvas, size, paint);
      case _DemoKind.cover:
        _paintCover(canvas, size, paint);
      case _DemoKind.immersive:
        _paintImmersive(canvas, size, paint);
    }
  }

  void _paintSpectrum(Canvas canvas, Size size, Paint paint) {
    const count = 22;
    const gap = 3.0;
    final barWidth = math.max(2.0, (size.width - gap * (count - 1)) / count);
    final beat = _beat;

    for (var i = 0; i < count; i++) {
      final a = 0.5 + 0.5 * math.sin(_seconds * 4.1 + i * 0.55);
      final b = 0.5 + 0.5 * math.sin(_seconds * 2.3 - i * 31 / 100);
      final tilt = i / (count - 1);
      final height = size.height *
          (0.14 + 0.86 * (a * 0.65 + b * 0.35) * (a * 0.65 + b * 0.35)) *
          (0.55 + 0.45 * beat) *
          (1 - tilt * 0.35);
      paint.color = _strong.withValues(alpha: 0.45 + 0.55 * (1 - tilt));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              i * (barWidth + gap), size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  void _paintWaveform(Canvas canvas, Size size, Paint paint) {
    const count = 34;
    // Inset so the first and last bars do not sit on the edge of the well.
    const inset = 14.0;
    const gap = 2.5;
    final span = size.width - inset * 2;
    final barWidth = math.max(2.0, (span - gap * (count - 1)) / count);
    final maxHeight = size.height * 0.78;
    final progress = (t.value * 0.35) % 1.0;
    final beat = _beat;

    for (var i = 0; i < count; i++) {
      // A fixed silhouette rather than a rolling one: a demo that reshuffles
      // itself reads as noise, and the shape of the song is the whole point.
      final peak =
          0.3 + 0.7 * (math.sin(i * 0.62) * math.cos(i * 0.21 + 1.1)).abs();
      final at = (i + 0.5) / count;
      final played = at <= progress;
      // Bars under the playhead lift with the beat, which is the difference
      // between a waveform and a sound-reactive one.
      final near = math.max(0.0, 1 - (progress - at).abs() * 14);
      final height =
          maxHeight * peak * (0.72 + 0.28 * beat * near) * (played ? 1.0 : 0.6);
      paint.color = played ? _strong : _weak;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset + i * (barWidth + gap),
              (size.height - height) / 2, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  /// Draws the real [ParticleSystem], so the preview and the player agree.
  ///
  /// The simulation is advanced first, then each mote is drawn with the same
  /// terms the real painter uses: its own flare drives size and brightness,
  /// its own birth/death and edge fades gate visibility, near motes get the
  /// halo and the chromatic split. Anything hand-rolled here would drift out of
  /// step with the field the next time it is retuned.
  void _paintParticles(Canvas canvas, Size size, Paint paint) {
    // Off means the field still lives but is dimmed, not empty — the same
    // reading as the other previews, and it keeps the "what am I turning off"
    // comparison honest.
    if (!on) {
      paint.color = _weak;
      canvas.drawRect(Offset.zero & size, paint);
    }

    particles.update(
      elapsedSeconds: _elapsed,
      frame: _beatFrame,
      spec: spec,
      aspect: size.width / size.height,
    );

    if (spec.particleCount == 0 || spec.particleOpacity < 0.01) return;

    final tint = on ? _strong : solids.accentWash(accent, 0.30);
    final hsl = HSLColor.fromColor(accent);
    final warm = hsl.withHue((hsl.hue + 22) % 360).toColor();
    final cool = hsl.withHue((hsl.hue - 22 + 360) % 360).toColor();

    for (final particle in particles.particles) {
      final fade = particles.fadeOf(particle) * particles.edgeFadeOf(particle);
      if (fade < 0.01) continue;

      final n = particles.displacedPosition(particle);
      final position = Offset(n.dx * size.width, n.dy * size.height);

      final flare = particle.excitation;
      final radius = particle.baseRadius *
          (0.45 + 0.55 * particle.depth) *
          (1 + flare * 0.5);
      // The spec's opacity is tuned against a full-screen field over a blurred
      // cover. On a 72px strip it would be nearly invisible, so the preview
      // lifts it and keeps the relative depth ordering — without this the three
      // presets differ so little that the picker looks broken.
      final alpha = (spec.particleOpacity *
              3.2 *
              (0.3 + 0.7 * particle.depth) *
              particles.glowOf(particle) *
              (1 + flare * 0.9) *
              fade)
          .clamp(0.0, 1.0);
      if (alpha < 0.01) continue;

      if (particle.depth > 0.35) {
        paint.color = tint.withValues(alpha: alpha * 0.16);
        canvas.drawCircle(position, radius * 2.6, paint);
      }

      if (flare > 0.12 && particle.depth > 0.45) {
        final split = radius * 0.9 * flare;
        final dx = particle.splitCos * split;
        final dy = particle.splitSin * split;
        paint.color = warm.withValues(alpha: alpha * 0.55 * flare);
        canvas.drawCircle(position.translate(dx, dy), radius, paint);
        paint.color = cool.withValues(alpha: alpha * 0.55 * flare);
        canvas.drawCircle(position.translate(-dx, -dy), radius, paint);
      }

      paint.color = tint.withValues(alpha: alpha);
      canvas.drawCircle(position, radius, paint);
    }
  }

  void _paintCover(Canvas canvas, Size size, Paint paint) {
    final beat = _beat;
    // `coverPunch` is the preset's actual peak scale, so subtle and bold
    // visibly differ here the same way they do on the player.
    final side =
        math.min(size.width, size.height) * (0.60 + spec.coverPunch * beat);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = Radius.circular(side * 0.16);

    // A solid bloom opening behind the artwork, so the pulse is legible outside
    // the square as well as inside it. Sized to stay inside the strip at peak.
    final halo = side * (1.3 + 0.25 * beat);
    paint.color = _weak.withValues(alpha: 0.45 + 0.55 * beat);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: halo, height: halo),
        Radius.circular(side * 0.26),
      ),
      paint,
    );

    paint.color = _strong;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: side, height: side),
        radius,
      ),
      paint,
    );
  }

  /// A phone-shaped screen rather than a flat swatch: the whole point of the
  /// setting is *where* the artwork sits relative to the edges, and a plain
  /// block cannot show that.
  void _paintImmersive(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    Rect box(double x, double y, double bw, double bh) =>
        Rect.fromLTWH(x * w, y * h, bw * w, bh * h);

    // The strip is wide and short, so both layouts are drawn across its full
    // width. The only difference is whether the artwork touches the edges.
    if (!on) {
      final side = h * 0.56;
      paint.color = _strong;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((w - side) / 2, h * 0.1, side, side),
          const Radius.circular(10),
        ),
        paint,
      );
      paint.color = _weak;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.38, h * 0.74, w * 0.24, h * 0.035),
          const Radius.circular(3),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, h * 0.84, w * 0.6, h * 0.12),
          Radius.circular(h * 0.06),
        ),
        paint,
      );
      paint.color = _strong;
      canvas.drawCircle(Offset(w / 2, h * 0.9), h * 0.05, paint);
      return;
    }

    paint.color = _weak;
    canvas.drawRect(Offset.zero & size, paint);

    // Artwork fills the full width and dissolves into the backdrop through
    // solid bands, matching the player's fade rather than a gradient.
    paint.color = _strong;
    canvas.drawRect(box(0, 0, 1, 0.58), paint);
    for (var i = 1; i <= 3; i++) {
      paint.color = Color.lerp(_strong, _weak, i / 4)!;
      canvas.drawRect(box(0, 0.58 + (i - 1) * 0.035, 1, 0.035), paint);
    }

    paint.color = _strong;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box(0.3, 0.71, 0.4, 0.04),
        const Radius.circular(3),
      ),
      paint,
    );
    paint.color = _strong.withValues(alpha: 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box(0.36, 0.79, 0.28, 0.03),
        const Radius.circular(3),
      ),
      paint,
    );

    // Controls sit straight on the backdrop, with no card behind them.
    paint.color = _strong.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(w * 0.34, h * 0.9), h * 0.05, paint);
    canvas.drawCircle(Offset(w * 0.66, h * 0.9), h * 0.05, paint);
    paint.color = _strong;
    canvas.drawCircle(Offset(w / 2, h * 0.9), h * 0.09, paint);
  }

  @override
  bool shouldRepaint(_DemoPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.accent != accent ||
      oldDelegate.on != on ||
      oldDelegate.reactive != reactive ||
      oldDelegate.spec.particleCount != spec.particleCount ||
      oldDelegate.spec.particleImpulse != spec.particleImpulse ||
      oldDelegate.solids.canvas != solids.canvas;

  @override
  bool shouldRebuildSemantics(_DemoPainter oldDelegate) => false;
}
