import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:audio_session/audio_session.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show createDatabaseFactoryFfi, sqfliteFfiInit;
import 'dart:async';
import 'dart:io';
import 'presentation/components/popup_scroll_dismiss.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/setup_screen.dart';
import 'presentation/widgets/orientation_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/setup_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/providers.dart';
import 'services/cache_service.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'services/permission_service.dart';
import 'services/power_state_service.dart';
import 'services/color_extraction_service.dart';
import 'services/update_service.dart';
import 'services/passive_art_fetcher_service.dart';
import 'services/sync_service.dart';
import 'presentation/widgets/update_available_dialog.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Linux and Windows have no platform implementations for audio_session or
  // audio_service; playback goes through just_audio_media_kit instead, and
  // sqlite goes through sqflite_common_ffi.
  final isMediaKitDesktop = Platform.isLinux || Platform.isWindows;

  if (isMediaKitDesktop) {
    sqfliteFfiInit();
    // In-process ffi factory (no separate sqlite worker isolate).
    databaseFactory = createDatabaseFactoryFfi(noIsolate: true);
    JustAudioMediaKit.ensureInitialized();
  }

  // Parallel initialization
  await Future.wait([
    if (!isMediaKitDesktop) _setupAudioSession(),
    if (!isMediaKitDesktop) _setupJustAudioBackground(),
  ], eagerError: false);

  PaintingBinding.instance.imageCache.maximumSize = 250;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024;

  // Not awaited: nothing blocks on it, and a platform without the channel just
  // leaves it reporting "not saving power" forever.
  unawaited(PowerStateService.instance.initialize());

  final storage = StorageService();
  bool isSetupComplete = await storage.getIsSetupComplete();

  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username');

  // Single user mode: always init database
  await DatabaseService.instance.init();

  unawaited(SyncService.instance.init());

  await storage.setIsLocalMode(true);

  await _initDesktopWindow(prefs);

  runApp(ProviderScope(
    overrides: [
      setupProvider
          .overrideWith(() => InitializedSetupNotifier(isSetupComplete)),
      authProvider.overrideWith(() => PreloadedAuthNotifier(username)),
    ],
    child: const WispieApp(),
  ));
}

const _kWindowWidthKey = 'desktop_window_width_v1';
const _kWindowHeightKey = 'desktop_window_height_v1';
const _kWindowMaximizedKey = 'desktop_window_maximized_v1';

/// Launches maximized unless the user last left the window restored, in which
/// case the last restored size is used.
Future<void> _initDesktopWindow(SharedPreferences prefs) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  try {
    await windowManager.ensureInitialized();
    final width = prefs.getDouble(_kWindowWidthKey);
    final height = prefs.getDouble(_kWindowHeightKey);
    final maximized = prefs.getBool(_kWindowMaximizedKey) ?? true;
    final options = WindowOptions(
      minimumSize: const Size(360, 540),
      size: width != null && height != null
          ? Size(width, height)
          : const Size(1280, 800),
      center: true,
      title: 'Wispie',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (maximized) {
        try {
          await windowManager.maximize();
        } on Exception catch (e) {
          debugPrint('Desktop maximize failed: $e');
        }
      }
      await windowManager.show();
      await windowManager.focus();
    });
    windowManager.addListener(_WindowStateSaver(prefs));
  } on Exception catch (e) {
    debugPrint('Desktop window init failed: $e');
  }
}

class _WindowStateSaver with WindowListener {
  _WindowStateSaver(this._prefs);

  final SharedPreferences _prefs;

  Future<void> _save() async {
    try {
      if (await windowManager.isMaximized() ||
          await windowManager.isFullScreen()) {
        await _prefs.setBool(_kWindowMaximizedKey, true);
        return;
      }
      final size = await windowManager.getSize();
      await _prefs.setDouble(_kWindowWidthKey, size.width);
      await _prefs.setDouble(_kWindowHeightKey, size.height);
      await _prefs.setBool(_kWindowMaximizedKey, false);
    } on Exception catch (e) {
      debugPrint('Failed to persist window state: $e');
    }
  }

  @override
  void onWindowResized() => _save();

  @override
  void onWindowMaximize() => _save();

  @override
  void onWindowUnmaximize() => _save();

  @override
  void onWindowEnterFullScreen() => _save();

  @override
  void onWindowLeaveFullScreen() => _save();
}

Future<void> _setupAudioSession() async {
  try {
    await AudioSession.instance.then((session) =>
        session.configure(const AudioSessionConfiguration.music()));
  } catch (e) {
    debugPrint('Failed to initialize AudioSession: $e');
  }
}

Future<void> _setupJustAudioBackground() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.sillygru.wispie.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationChannelDescription: 'Playback controls',
      androidNotificationIcon: 'drawable/ic_stat_music_note',
      // Retain foreground state on pause so EMUI/Huawei power management does
      // not evict the media session or terminate media button routing.
      // androidNotificationOngoing is omitted (defaults to false) because
      // when androidStopForegroundOnPause is false, the active foreground service
      // keeps the notification ongoing and audio_service asserts
      // (!androidNotificationOngoing || androidStopForegroundOnPause).
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: true,
    );
  } catch (e) {
    // Never block startup on background-audio binding failures (e.g. missing
    // <service> declaration on a misbuilt APK). UI still opens; playback
    // degrades to foreground-only until the manifest is fixed.
    debugPrint('Failed to initialize JustAudioBackground: $e');
  }
}

class InitializedSetupNotifier extends SetupNotifier {
  final bool initialValue;
  InitializedSetupNotifier(this.initialValue);
  @override
  bool build() => initialValue;
}

class WispieApp extends ConsumerStatefulWidget {
  const WispieApp({super.key});

  @override
  ConsumerState<WispieApp> createState() => _WispieAppState();
}

class _WispieAppState extends ConsumerState<WispieApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _updateDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(CacheService.instance.init());
      unawaited(ColorExtractionService.init());
      unawaited(CacheService.instance.scheduleStartupMaintenance());
      PassiveArtFetcherService.instance.init(ref);
      // POST_NOTIFICATIONS is required on Android 13+ for the media
      // notification to appear. Fire-and-forget so startup is not blocked;
      // on older Android it is a no-op (auto-granted).
      unawaited(PermissionService.instance.ensureNotificationPermission());
      unawaited(
        ref.read(updateCheckProvider.notifier).prime().then((_) {
          if (mounted) _checkAndShowUpdateDialog();
        }).catchError((_) {}),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAndShowUpdateDialog() async {
    if (_updateDialogShown) return;
    // Don't interrupt the setup flow.
    if (!ref.read(setupProvider)) return;

    final state = ref.read(updateCheckProvider);
    if (!state.hasUpdate) return;

    try {
      final dismissed =
          await UpdateService.isVersionDismissed(state.latestTag!);
      if (!mounted || _updateDialogShown || dismissed) return;

      _updateDialogShown = true;
      final dialogContext = _navigatorKey.currentContext;
      if (dialogContext == null || !dialogContext.mounted) return;
      showUpdateAvailableDialog(
        dialogContext,
        currentVersion: state.currentVersion,
        newVersion: state.latestVersionLabel ?? state.latestTag!,
        dismissalTag: state.latestTag!,
        releaseUrl:
            state.releaseUrl ?? Uri.parse(UpdateService.latestReleaseUrl),
      );
    } catch (_) {
      // Fail silently — update dialogs are best-effort.
    }
  }

  @override
  void didHaveMemoryPressure() {
    ref.read(audioPlayerManagerProvider).onMemoryPressure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isIOS && state != AppLifecycleState.resumed) {
      unawaited(ref.read(audioPlayerManagerProvider).forceFlushCurrentStats());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_onAppForeground());
    }
  }

  Future<void> _onAppForeground() async {
    try {
      final sync = SyncService.instance;
      if (!sync.isSignedIn) return;
      if (sync.isSyncing) return;
      final settings = ref.read(settingsProvider);
      if (!settings.autoSyncEnabled) return;

      final lastSyncedAt = await sync.getLastSyncTimestamp();
      if (lastSyncedAt != null) {
        final nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
        if (nowSec - lastSyncedAt < 900) {
          return;
        }
      }

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      if (sync.isSyncing) return;

      unawaited(ref.read(syncProvider.notifier).sync(
            syncSettings: settings.syncSettingsEnabled,
          ));
    } catch (_) {}
  }

  static final bool _isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Map<ShortcutActivator, VoidCallback> _playbackShortcuts() {
    final player = ref.read(audioPlayerManagerProvider);
    // Plain keys must not steal typing from text fields.
    VoidCallback guarded(VoidCallback action) => () {
          final focused = FocusManager.instance.primaryFocus?.context;
          if (focused?.widget is EditableText ||
              focused?.findAncestorWidgetOfExactType<EditableText>() != null) {
            return;
          }
          action();
        };
    void seekBy(Duration delta) {
      final target = player.player.position + delta;
      player.player.seek(target < Duration.zero ? Duration.zero : target);
    }

    void adjustVolume(double delta) {
      final v = (player.player.volume + delta).clamp(0.0, 1.0);
      player.player.setVolume(v);
    }

    final playPause = player.togglePlayPause;
    return {
      const SingleActivator(LogicalKeyboardKey.space): guarded(playPause),
      const SingleActivator(LogicalKeyboardKey.mediaPlayPause): playPause,
      const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
          player.player.seekToNext(),
      const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
          player.player.seekToPrevious(),
      for (final meta in [true, false]) ...{
        SingleActivator(LogicalKeyboardKey.arrowRight,
            meta: meta, control: !meta): guarded(player.player.seekToNext),
        SingleActivator(LogicalKeyboardKey.arrowLeft,
            meta: meta, control: !meta): guarded(player.player.seekToPrevious),
      },
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
          guarded(() => seekBy(const Duration(seconds: 10))),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
          guarded(() => seekBy(const Duration(seconds: -10))),
      const SingleActivator(LogicalKeyboardKey.arrowUp, control: true): () =>
          adjustVolume(0.05),
      const SingleActivator(LogicalKeyboardKey.arrowDown, control: true): () =>
          adjustVolume(-0.05),
    };
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isSetupComplete = ref.watch(setupProvider);
    final themeState = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Wispie',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      navigatorObservers: [PopupScrollDismiss.observer],
      builder: (context, child) {
        final content =
            PopupScrollDismiss(child: child ?? const SizedBox.shrink());
        if (!_isDesktop) return content;
        return CallbackShortcuts(
          bindings: _playbackShortcuts(),
          child: Focus(autofocus: true, child: content),
        );
      },
      theme: AppTheme.getTheme(themeState),
      home: OrientationPolicy(
        child: AnimatedTheme(
          data: AppTheme.getTheme(themeState),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: (!isSetupComplete || !authState.isAuthenticated)
              ? const SetupScreen()
              : const MainScreen(),
        ),
      ),
    );
  }
}
