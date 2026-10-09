import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../routes/app_page_route.dart';
import '../widgets/now_playing_bar.dart';
import '../widgets/app_drawer.dart';
import '../../providers/providers.dart';
import '../../providers/open_files_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/telemetry_service.dart';
import '../widgets/bulk_selection_bar.dart';
import '../widgets/external_open_banner.dart';
import '../widgets/ambient_background.dart';
import '../widgets/auto_backup_indicator.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_nav_bar.dart';
import '../components/floating_dock.dart';
import '../components/tab_switch_transition.dart';
import '../tokens/app_tokens.dart';
import '../tokens/app_icons.dart';
import '../utils/wide_layout.dart';
import '../widgets/album_art_image.dart';
import '../tokens/player_tokens.dart';
import '../../models/queue_item.dart';
import '../../services/audio_player_manager.dart';
import 'player/lyrics_pane.dart';

import '../../models/song.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadataState = ref.watch(metadataSaveProvider);

    if (metadataState.status == MetadataSaveStatus.idle) {
      return const SizedBox.shrink();
    }

    final (String text, AppTone tone, AppIconData icon, bool busy) =
        switch (metadataState.status) {
      MetadataSaveStatus.saving => (
          metadataState.message,
          AppTone.warning,
          AppIcons.edit,
          true,
        ),
      MetadataSaveStatus.success => (
          metadataState.message,
          AppTone.success,
          AppIcons.checkCircle,
          false,
        ),
      _ => (
          metadataState.message,
          AppTone.danger,
          AppIcons.error,
          false,
        ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: AppTokens.s2),
        child: AppStatusBanner(
          message: text,
          tone: tone,
          icon: icon,
          busy: busy,
        ),
      ),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _tabDirection = 1;
  final GlobalKey<FloatingDockState> _dockKey = GlobalKey<FloatingDockState>();

  static const List<AppNavItem> _navItems = [
    AppNavItem(
      icon: AppIcons.home,
      selectedIcon: AppIcons.home,
      label: 'Home',
    ),
    AppNavItem(
      icon: AppIcons.library,
      selectedIcon: AppIcons.library,
      label: 'Library',
    ),
    AppNavItem(
      icon: AppIcons.person,
      selectedIcon: AppIcons.person,
      label: 'Profile',
    ),
  ];
  bool _isDrawerOpen = false;

  late AnimationController _drawerController;

  bool _isDraggingDrawer = false;

  /// The nav bar is 64 high plus whatever safe-area strip it paints itself, so
  /// this only needs a little slack above it — it used to carry the gap the
  /// floating dock left on either side of its inset.

  // Gesture detection for drawer
  static const double _edgeDragWidth = 60.0;

  // Track which screens have been built to enable lazy loading
  final Set<int> _builtScreens = {0};

  late final List<ScrollController> _scrollControllers;

  List<Widget> get _screens => [
        HomeScreen(scrollController: _scrollControllers[0]),
        LibraryTabNavigator(scrollController: _scrollControllers[1]),
        ProfileScreen(scrollController: _scrollControllers[2]),
      ];

  Future<void> _closeDrawer() async {
    if (!_isDrawerOpen && !_drawerController.isAnimating) return;
    await _drawerController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutQuart,
    );
    if (mounted) {
      setState(() {
        _isDrawerOpen = false;
      });
    }
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) {
      if (_scrollControllers[index].hasClients) {
        _scrollControllers[index].animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      setState(() {
        _tabDirection = index > _selectedIndex ? 1 : -1;
        _selectedIndex = index;
        _builtScreens.add(index);
      });
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isDrawerOpen || details.globalPosition.dx <= _edgeDragWidth) {
      setState(() {
        _isDraggingDrawer = true;
      });
      _drawerController.stop();
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingDrawer) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final delta = details.delta.dx / WideLayout.drawerWidth(screenWidth);

    _drawerController.value = (_drawerController.value + delta).clamp(0.0, 1.0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDraggingDrawer) return;

    final vx = details.velocity.pixelsPerSecond.dx;

    bool open;
    if (vx.abs() > 250) {
      open = vx > 0;
    } else {
      open = _drawerController.value > 0.30;
    }

    final target = open ? 1.0 : 0.0;
    final remaining = (target - _drawerController.value).abs();

    final velocityFraction = (vx.abs() / 1200).clamp(0.0, 1.0);
    final baseDurationMs = (remaining * 200).round();
    final durationMs = (baseDurationMs * (1.0 - 0.45 * velocityFraction))
        .round()
        .clamp(90, 200);

    setState(() {
      _isDraggingDrawer = false;
      if (open) _isDrawerOpen = true;
    });

    _drawerController
        .animateTo(
      target,
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutQuart,
    )
        .then((_) {
      if (mounted && !open) {
        setState(() => _isDrawerOpen = false);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scrollControllers = List.generate(3, (_) => ScrollController());
    WidgetsBinding.instance.addObserver(this);
    // Report app launch telemetry
    unawaited(TelemetryService.instance.reportLaunch());

    // Check and run auto-backup on initial app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(autoBackupProvider.notifier).checkAndRunAutoBackup();
      // Picks up files opened via Android Open-with / Share, cold or warm.
      unawaited(ref.read(openFilesProvider.notifier).initialize());
    });
  }

  @override
  void dispose() {
    _drawerController.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Trigger background refresh when app returns to foreground
      ref.read(songsProvider.notifier).refresh(isBackground: true);

      // Check and run auto-backup if needed
      ref.read(autoBackupProvider.notifier).checkAndRunAutoBackup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final settings = ref.watch(settingsProvider);
    final topPadding = mediaQuery.padding.top;
    final androidSystemBottomInset = mediaQuery.padding.bottom;
    final bottomDockState = ref.watch(bottomDockVisibilityProvider);
    final bottomDockVisibility =
        settings.autoHideBottomBarOnScroll ? bottomDockState.visibility : 1.0;
    final isBottomDockHidden = bottomDockVisibility <= 0.001;

    final nowPlayingBottomPadding = settings.autoHideBottomBarOnScroll &&
            isBottomDockHidden &&
            androidSystemBottomInset > 0
        ? Platform.isIOS
            ? 12.0
            : 8.0 + androidSystemBottomInset
        : settings.autoHideBottomBarOnScroll && isBottomDockHidden
            ? Platform.isIOS
                ? 16.0
                : 20.0
            : 12.0;

    final isSelectionMode =
        ref.watch(selectionProvider.select((s) => s.isSelectionMode));
    ref.listen(
      settingsProvider.select((value) => value.autoHideBottomBarOnScroll),
      (previous, next) {
        if (!next) {
          ref.read(bottomDockVisibilityProvider.notifier).show();
        }
      },
    );

    ref.listen(songsProvider, (previous, next) {
      if (next is AsyncData && next.hasValue && next.value!.isNotEmpty) {
        ref.read(userDataProvider.notifier).onLibraryChanged(next.value!);
      }
    });

    ref.listen(homeNavigationProvider, (previous, next) {
      if (next == null) return;
      // Home is bottom-nav index 0.
      if (_selectedIndex != 0) {
        setState(() {
          _tabDirection = 0 > _selectedIndex ? 1 : -1;
          _selectedIndex = 0;
        });
      }
    });

    ref.listen(libraryNavigationProvider, (previous, next) {
      if (next == null) return;
      // Library is bottom-nav index 1.
      if (_selectedIndex != 1 || !_builtScreens.contains(1)) {
        setState(() {
          _tabDirection = 1 > _selectedIndex ? 1 : -1;
          _selectedIndex = 1;
          _builtScreens.add(1);
        });
      }
    });

    // Wide windows (tablet/desktop landscape) earn the desktop arrangement.
    // Phones stay portrait-locked at the OS level, so this keys off size.
    final isWide = WideLayout.isWide(context);
    final accent = AppTokens.accentOf(context, ref);
    final drawerSlideMax = WideLayout.drawerWidth(mediaQuery.size.width);

    Widget buildContentStack() {
      return Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              _dockKey.currentState?.handleScroll(n);
              return false;
            },
            child: AmbientBackground(
              child: Stack(
                children: _screens.asMap().entries.map((entry) {
                  final index = entry.key;
                  final screen = entry.value;
                  if (!_builtScreens.contains(index)) {
                    // Only build if this screen has been selected before
                    return const SizedBox.shrink();
                  }
                  return TabSwitchTransition(
                    active: index == _selectedIndex,
                    direction: _tabDirection,
                    child: screen,
                  );
                }).toList(),
              ),
            ),
          ),
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            child: const SyncIndicator(),
          ),
          Positioned(
            top: topPadding + 40,
            left: 0,
            right: 0,
            child: const AutoBackupIndicator(),
          ),
          Positioned(
            top: topPadding + 80,
            left: 0,
            right: 0,
            child: const ExternalOpenBanner(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: isSelectionMode
                ? const BulkSelectionBar()
                : isWide
                    ? Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: WideLayout.maxContentWidth,
                          ),
                          child: NowPlayingBar(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              nowPlayingBottomPadding,
                            ),
                          ),
                        ),
                      )
                    : FloatingDock(
                        selectedIndex: _selectedIndex,
                        onSelected: _onTabSelected,
                        items: _navItems,
                        key: _dockKey,
                        autoCollapse: settings.autoHideBottomBarOnScroll,
                      ),
          ),
        ],
      );
    }

    Widget buildDrawerSlider({required Widget child}) {
      return AnimatedBuilder(
        animation: _drawerController,
        builder: (context, child) {
          final slideX = _drawerController.value * drawerSlideMax;
          final showScrim = _isDrawerOpen ||
              _isDraggingDrawer ||
              _drawerController.isAnimating ||
              _drawerController.value > 0;
          return RepaintBoundary(
            child: Transform.translate(
              offset: Offset(slideX, 0),
              child: Stack(
                children: [
                  child!,
                  // Scrim dims the content when drawer is open
                  if (showScrim)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _closeDrawer,
                        child: Container(
                          color: Colors.black.withValues(
                            alpha: 0.45 * _drawerController.value,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        child: child,
      );
    }

    Widget buildShellBody() {
      return GestureDetector(
        // Desktop has the nav rail; a trackpad's sideways scroll would
        // otherwise drag the whole shell, bottom bar included.
        onHorizontalDragStart: isWide ? null : _onHorizontalDragStart,
        onHorizontalDragUpdate: isWide ? null : _onHorizontalDragUpdate,
        onHorizontalDragEnd: isWide ? null : _onHorizontalDragEnd,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Drawer sits underneath the main content
            AnimatedBuilder(
              animation: _drawerController,
              builder: (context, child) {
                final shouldShow = _isDrawerOpen ||
                    _isDraggingDrawer ||
                    _drawerController.isAnimating ||
                    _drawerController.value > 0;
                if (!shouldShow) return const SizedBox.shrink();
                return Positioned.fill(
                  child: AppDrawer(
                    onClose: _closeDrawer,
                    drawerPosition: _drawerController.value,
                  ),
                );
              },
            ),
            // Main content slides right to reveal the drawer
            buildDrawerSlider(child: buildContentStack()),
          ],
        ),
      );
    }

    if (isWide && !isSelectionMode) {
      void openSearch() => context.pushApp(const SearchScreen());
      void openSettings() => context.pushApp(const SettingsScreen());
      return Scaffold(
        body: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                openSearch,
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                openSearch,
          },
          child: PopScope(
            canPop: !isSelectionMode,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (isSelectionMode) {
                ref.read(selectionProvider.notifier).exitSelectionMode();
              }
            },
            child: Row(
              children: [
                _WideNavRail(
                  selectedIndex: _selectedIndex,
                  onSelected: _onTabSelected,
                  accent: accent,
                  onSearch: openSearch,
                  onSettings: openSettings,
                ),
                Expanded(child: buildShellBody()),
                if (settings.desktopSidebarEnabled &&
                    mediaQuery.size.width >= _sidePanelBreakpoint)
                  const _WideSidePanel(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: PopScope(
        canPop: !isSelectionMode,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (isSelectionMode) {
            ref.read(selectionProvider.notifier).exitSelectionMode();
          }
        },
        child: buildShellBody(),
      ),
      // The floating dock is drawn inside the content stack so pages scroll
      // underneath it; no Scaffold bottom bar.
    );
  }
}

/// Side rail for wide windows: the same three destinations as [AppNavBar],
/// laid out vertically desktop-style rather than as a bottom dock.
class _WideNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accent;
  final VoidCallback? onSearch;
  final VoidCallback? onSettings;

  const _WideNavRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.accent,
    this.onSearch,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final dockColor = Color.alphaBlend(
      AppTokens.floatingFill,
      Theme.of(context).colorScheme.surface,
    );
    return Container(
      width: 76,
      color: dockColor,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: AppTokens.s4),
            for (var i = 0; i < 3; i++)
              _WideNavDestination(
                index: i,
                selected: i == selectedIndex,
                accent: accent,
                onTap: () => onSelected(i),
              ),
            const Spacer(),
            if (onSearch != null)
              _WideNavAction(
                icon: AppIcons.search,
                label: 'Search',
                tooltip: 'Search (Ctrl+K)',
                accent: accent,
                onTap: onSearch!,
              ),
            if (onSettings != null)
              _WideNavAction(
                icon: AppIcons.misc,
                label: 'Settings',
                tooltip: 'Settings',
                accent: accent,
                onTap: onSettings!,
              ),
            const SizedBox(height: AppTokens.s3),
          ],
        ),
      ),
    );
  }
}

class _WideNavAction extends StatelessWidget {
  final AppIconData icon;
  final String label;
  final String? tooltip;
  final Color accent;
  final VoidCallback onTap;

  const _WideNavAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = AppTokens.fg(AppTokens.aTertiary);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppTokens.dFast,
              curve: AppTokens.cStandard,
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: AppTokens.brPill,
              ),
              alignment: Alignment.center,
              child: AppIcon(
                icon,
                size: AppTokens.iconMd,
                color: iconColor,
              ),
            ),
            const SizedBox(height: AppTokens.s1),
            Text(
              label,
              style: AppTokens.meta(context).copyWith(
                color: iconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
    final tip = tooltip;
    if (tip == null || tip.isEmpty) return content;
    return Tooltip(message: tip, child: content);
  }
}

class _WideNavDestination extends StatelessWidget {
  final int index;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _WideNavDestination({
    required this.index,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = switch (index) {
      0 => (AppIcons.home, 'Home'),
      1 => (AppIcons.library, 'Library'),
      _ => (AppIcons.person, 'Profile'),
    };
    final iconColor = selected ? accent : AppTokens.fg(AppTokens.aTertiary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.s2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppTokens.dFast,
              curve: AppTokens.cStandard,
              width: 52,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: AppTokens.accentWashAlpha)
                    : Colors.transparent,
                borderRadius: AppTokens.brPill,
              ),
              alignment: Alignment.center,
              child: AppIcon(
                data.$1,
                size: AppTokens.iconMd,
                color: iconColor,
                strokeWidth: selected
                    ? AppTokens.iconStrokeEmphasis
                    : AppTokens.iconStroke,
              ),
            ),
            const SizedBox(height: AppTokens.s1),
            Text(
              data.$2,
              style: AppTokens.meta(context).copyWith(
                color: iconColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Window width at which the shell docks Lyrics/Queue on the right instead of
/// leaving the extra width empty.
const double _sidePanelBreakpoint = 1200;

/// Desktop right column: Lyrics and Queue for whatever is playing, so neither
/// Desktop right column, Spotify-style: one scroll of now playing art, a
/// lyrics block and the upcoming queue. No tabs; everything is visible at once.
class _WideSidePanel extends ConsumerStatefulWidget {
  const _WideSidePanel();

  @override
  ConsumerState<_WideSidePanel> createState() => _WideSidePanelState();
}

class _WideSidePanelState extends ConsumerState<_WideSidePanel> {
  // The panel is always on screen when built, so lyrics always sync.
  final ValueNotifier<bool> _lyricsVisible = ValueNotifier(true);

  @override
  void dispose() {
    _lyricsVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accent =
        themeState.extractedColor ?? Theme.of(context).colorScheme.primary;
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final width = (MediaQuery.sizeOf(context).width * 0.24).clamp(320.0, 420.0);

    return Theme(
      data: AppTheme.getPlayerTheme(themeState, accent),
      child: Container(
        width: width,
        color: Colors.black,
        child: SafeArea(
          left: false,
          child: ValueListenableBuilder<Song?>(
            valueListenable: audioManager.currentSongNotifier,
            builder: (context, song, _) {
              if (song == null) {
                return Center(
                  child: Text(
                    'Nothing playing',
                    style: PlayerTokens.meta(context),
                  ),
                );
              }
              return ValueListenableBuilder<List<QueueItem>>(
                valueListenable: audioManager.queueNotifier,
                builder: (context, queue, _) => StreamBuilder<int?>(
                  stream: audioManager.player.currentIndexStream,
                  initialData: audioManager.player.currentIndex,
                  builder: (context, snapshot) {
                    final current = snapshot.data ?? -1;
                    final upcoming =
                        current >= 0 ? queue.skip(current + 1).toList() : queue;
                    return _buildScroll(
                      context,
                      song,
                      accent,
                      audioManager,
                      queue,
                      upcoming,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Fixed layout, no outer scroll: header, lyrics and queue are all visible
  /// at once, and each region scrolls only itself so a wheel over the queue
  /// can never move the lyrics.
  Widget _buildScroll(
    BuildContext context,
    Song song,
    Color accent,
    AudioPlayerManager audioManager,
    List<QueueItem> queue,
    List<QueueItem> upcoming,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PlayerTokens.s4,
            PlayerTokens.s4,
            PlayerTokens.s4,
            PlayerTokens.s2,
          ),
          child: Row(
            children: [
              AlbumArtImage(
                url: song.coverUrl ?? '',
                filename: song.filename,
                cacheVersion: song.mtime,
                width: 56,
                height: 56,
                borderRadius: PlayerTokens.s2,
                memCacheWidth: 168,
              ),
              const SizedBox(width: PlayerTokens.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayerTokens.trackTitle(context),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayerTokens.trackSubtitle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PlayerTokens.s2),
            child: LyricsPane(
              song: song,
              accent: accent,
              paneVisible: _lyricsVisible,
              compact: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PlayerTokens.s4,
            PlayerTokens.s3,
            PlayerTokens.s4,
            PlayerTokens.s1,
          ),
          child: Text(
            upcoming.isEmpty ? 'Nothing up next' : 'Next in queue',
            style: PlayerTokens.sectionLabel(context),
          ),
        ),
        Expanded(
          flex: 4,
          child: ListView.builder(
            padding: const EdgeInsets.only(
              bottom: AppTokens.scrollBottomInset,
            ),
            itemCount: upcoming.length,
            itemBuilder: (context, i) {
              final item = upcoming[i];
              return _SideQueueRow(
                key: ValueKey(item.queueId),
                item: item,
                accent: accent,
                onTap: () => audioManager.jumpToQueueItem(item.queueId),
                onMoveToTop: i == 0
                    ? null
                    : () => audioManager.moveUpcomingToTop(item.queueId),
                onRemove: () {
                  final absolute =
                      queue.indexWhere((q) => q.queueId == item.queueId);
                  if (absolute >= 0) audioManager.removeFromQueue(absolute);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Compact queue row; actions appear on hover so the list stays quiet.
class _SideQueueRow extends StatefulWidget {
  final QueueItem item;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onMoveToTop;
  final VoidCallback onRemove;

  const _SideQueueRow({
    super.key,
    required this.item,
    required this.accent,
    required this.onTap,
    required this.onMoveToTop,
    required this.onRemove,
  });

  @override
  State<_SideQueueRow> createState() => _SideQueueRowState();
}

class _SideQueueRowState extends State<_SideQueueRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.item.song;
    final muted = Colors.white.withValues(alpha: PlayerTokens.aSecondary);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: PlayerTokens.dFast,
          curve: PlayerTokens.cStandard,
          margin: const EdgeInsets.symmetric(horizontal: PlayerTokens.s2),
          padding: const EdgeInsets.symmetric(
            horizontal: PlayerTokens.s2,
            vertical: PlayerTokens.s1 + 2,
          ),
          decoration: BoxDecoration(
            color: _hover ? AppTokens.surface(2) : Colors.transparent,
            borderRadius: PlayerTokens.brSm,
          ),
          child: Row(
            children: [
              AlbumArtImage(
                url: song.coverUrl ?? '',
                filename: song.filename,
                cacheVersion: song.mtime,
                width: 44,
                height: 44,
                borderRadius: PlayerTokens.s1,
                memCacheWidth: 132,
              ),
              const SizedBox(width: PlayerTokens.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PlayerTokens.meta(context),
                    ),
                  ],
                ),
              ),
              if (_hover) ...[
                if (widget.onMoveToTop != null)
                  IconButton(
                    tooltip: 'Play next',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: muted,
                    icon: const Icon(Icons.vertical_align_top_rounded),
                    onPressed: widget.onMoveToTop,
                  ),
                IconButton(
                  tooltip: 'Remove from queue',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: muted,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onRemove,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
