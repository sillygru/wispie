import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'online_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'sleep_timer_screen.dart';
import '../routes/app_page_route.dart';
import '../widgets/now_playing_bar.dart';
import '../widgets/app_drawer.dart';
import '../motion/drawer_geometry.dart';
import '../../providers/providers.dart';
import '../../providers/open_files_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/sleep_timer_service.dart';
import '../../services/telemetry_service.dart';
import '../widgets/bulk_selection_bar.dart';
import '../widgets/ambient_background.dart';
import '../widgets/blurred_background.dart';
import '../components/app_icon.dart';
import '../components/pressable.dart';
import '../components/animated_removal.dart';
import '../components/app_nav_bar.dart';
import '../components/floating_dock.dart';
import '../components/tab_switch_transition.dart';
import '../motion/motion.dart';
import '../player_panel/player_panel.dart';
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
import '../../providers/browse_palette_provider.dart';
import '../../theme/app_theme.dart';
import '../../l10n/l10n.dart';

/// One shell destination: its screen, nav entry and scroll controller.
class _ShellTab {
  final String id;
  final ScrollController controller;
  final AppNavItem nav;
  final Widget screen;

  const _ShellTab({
    required this.id,
    required this.controller,
    required this.nav,
    required this.screen,
  });
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

  /// Destinations in display order. The online tab is optional, so this is
  /// built per frame instead of being a fixed four; ids keep the built-screen
  /// bookkeeping stable when the list changes length.
  List<_ShellTab> _tabs(BuildContext context, bool youtubeEnabled) {
    final l10n = context.l10n;
    return [
      _ShellTab(
        id: 'home',
        controller: _scrollControllers[0],
        nav: AppNavItem(
          icon: AppIcons.home,
          selectedIcon: AppIcons.home,
          label: l10n.shellNavHome,
        ),
        screen: HomeScreen(scrollController: _scrollControllers[0]),
      ),
      _ShellTab(
        id: 'library',
        controller: _scrollControllers[1],
        nav: AppNavItem(
          icon: AppIcons.library,
          selectedIcon: AppIcons.library,
          label: l10n.libraryTitle,
        ),
        screen: LibraryTabNavigator(scrollController: _scrollControllers[1]),
      ),
      if (youtubeEnabled)
        _ShellTab(
          id: 'online',
          controller: _scrollControllers[2],
          nav: AppNavItem(
            icon: AppIcons.musicNote,
            selectedIcon: AppIcons.musicNote,
            label: l10n.onlineTab,
          ),
          screen: OnlineScreen(scrollController: _scrollControllers[2]),
        ),
      _ShellTab(
        id: 'profile',
        controller: _scrollControllers[3],
        nav: AppNavItem(
          icon: AppIcons.person,
          selectedIcon: AppIcons.person,
          label: l10n.profileTitle,
        ),
        screen: ProfileScreen(scrollController: _scrollControllers[3]),
      ),
    ];
  }

  bool _isDrawerOpen = false;

  late AnimationController _drawerController;
  late final SnapEngine _drawerSnap;
  late final DrawerGeometry _drawerGeometry;

  bool _isDraggingDrawer = false;

  /// When the app went to the background, so a quick switch skips the rescan.
  DateTime? _backgroundedAt;

  /// The nav bar is 64 high plus whatever safe-area strip it paints itself, so
  /// this only needs a little slack above it — it used to carry the gap the
  /// floating dock left on either side of its inset.

  // Track which screens have been built to enable lazy loading, keyed by tab
  // id so toggling the online tab cannot make one screen stand in for another.
  final Set<String> _builtScreens = {'home'};

  /// The destinations for the current build, so tap handlers index the same
  /// list the dock and rail drew.
  List<_ShellTab> _visibleTabs = const [];

  /// True while the drawer is far enough open that chrome (scrim, panel) should
  /// stay mounted. A tiny leftover spring value must not keep a GestureDetector
  /// over the content — that is what killed vertical scroll after open/close.
  bool get _drawerChromeVisible =>
      _isDrawerOpen ||
      _isDraggingDrawer ||
      _drawerController.isAnimating ||
      _drawerController.value.abs() > 0.002;

  late final List<ScrollController> _scrollControllers;

  Future<void> _closeDrawer() async {
    if (!_isDrawerOpen &&
        !_isDraggingDrawer &&
        !_drawerController.isAnimating &&
        _drawerController.value <= 0.001) {
      return;
    }
    if (_drawerController.value <= 0.001 ||
        MotionPolicy.read(context).reduceMotion) {
      _drawerSnap.jumpTo(0);
      _markDrawerClosed();
      return;
    }
    // State is marked closed only by the generation-guarded settle, so a drawer
    // grabbed again mid-close is not marked closed behind the finger.
    await _drawerSnap.springTo(
      0,
      spring: MotionSprings.settle,
      onSettled: _markDrawerClosed,
    );
  }

  void _markDrawerClosed() {
    if (!mounted) return;
    _drawerController.value = 0;
    setState(() {
      _isDrawerOpen = false;
      _isDraggingDrawer = false;
    });
  }

  void _onTabSelected(int index) {
    if (index < 0 || index >= _visibleTabs.length) return;
    final tab = _visibleTabs[index];
    if (index == _selectedIndex) {
      if (tab.controller.hasClients) {
        tab.controller.animateTo(
          0,
          duration: MotionPolicy.read(context).duration(MotionTokens.medium),
          curve: MotionTokens.standardCurve,
        );
      }
    } else {
      setState(() {
        _tabDirection = index > _selectedIndex ? 1 : -1;
        _selectedIndex = index;
        _builtScreens.add(tab.id);
      });
    }
  }

  void _onHorizontalDragStart(MotionDragStart start) {
    setState(() {
      _isDraggingDrawer = true;
      if (_drawerController.value > 0.002) _isDrawerOpen = true;
    });
    // Freeze any settle where it is; the drag continues from the drawn value.
    _drawerSnap.cancel();
  }

  void _onHorizontalDragUpdate(double delta) {
    if (!_isDraggingDrawer) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    var amount = delta / WideLayout.drawerWidth(screenWidth);
    final value = _drawerController.value;
    // Past open/closed the push gets progressively heavier, and pulling back
    // stays full-speed so the sheet never feels stuck in the overshoot.
    final scale = WideLayout.drawerOvershootDragScale(value);
    final outward = value >= 1 ? amount > 0 : (value <= 0 ? amount < 0 : false);
    if (outward) amount *= scale;
    _drawerController.value = (value + amount).clamp(
      -WideLayout.drawerOvershoot,
      1 + WideLayout.drawerOvershoot,
    );
  }

  void _onHorizontalDragEnd(MotionDragEnd end) {
    if (!_isDraggingDrawer) return;
    const tuning = SnapTuning(
      actuation: 0,
      flingVelocity: 250,
      commitRatio: 0.30,
    );
    // Already past open (or flinging further open): ease back — a hint of
    // spring, not a trampoline.
    final bool pullPastOpen = _drawerController.value >= 1.0 ||
        (_isDrawerOpen &&
            _drawerController.value > 0.95 &&
            end.velocity.dx > 120);
    if (pullPastOpen) {
      _settleDrawer(open: true, velocity: end.velocity.dx, bounceOpen: true);
      return;
    }
    final bool open = tuning.advances(
      progress: _drawerController.value.clamp(0.0, 1.0),
      velocity: end.velocity.dx,
      extent: MediaQuery.sizeOf(context).width,
    );
    _settleDrawer(open: open, velocity: end.velocity.dx);
  }

  void _onHorizontalDragCancel() {
    if (!_isDraggingDrawer) return;
    _settleDrawer(open: _drawerController.value >= 0.30);
  }

  void _settleDrawer({
    required bool open,
    double velocity = 0,
    bool bounceOpen = false,
  }) {
    final width = WideLayout.drawerWidth(MediaQuery.sizeOf(context).width);
    setState(() {
      if (open) _isDrawerOpen = true;
    });
    if (MotionPolicy.read(context).reduceMotion) {
      _drawerSnap.jumpTo(open ? 1 : 0);
      setState(() {
        _isDrawerOpen = open;
        _isDraggingDrawer = false;
      });
      return;
    }
    // Opening rides [drawerOpen]: the sheet has room to swell past its seat,
    // so it crests into it and relaxes back instead of arriving at the
    // boundary dead. Pull-past-open is only a snappy return into place, and a
    // close is a settle. Release speed survives a flick, lightly damped so a
    // thrown drawer cannot wind the spring into a wobble.
    final spring = !open
        ? MotionSprings.settle
        : (bounceOpen ? MotionSprings.snappy : MotionSprings.drawerOpen);
    _drawerSnap.springTo(
      open ? 1 : 0,
      spring: spring,
      velocity: width > 0 ? (velocity / width).clamp(-6.0, 6.0) * 0.6 : 0,
      onSettled: () {
        if (!mounted) return;
        // Pin exactly so a leftover 1e-4 cannot keep the scrim GestureDetector
        // mounted over the content and kill vertical scroll.
        _drawerController.value = open ? 1.0 : 0.0;
        setState(() {
          _isDraggingDrawer = false;
          _isDrawerOpen = open;
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: MotionTokens.short,
      lowerBound: -WideLayout.drawerOvershoot,
      upperBound: 1 + WideLayout.drawerOvershoot,
    );
    _drawerSnap = SnapEngine(_drawerController);
    // Width is not readable until dependencies are in: the geometry starts
    // unbound and is given its first real width in didChangeDependencies.
    _drawerGeometry = DrawerGeometry(_drawerController, restWidth: 0);
    _scrollControllers = List.generate(4, (_) => ScrollController());
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The drawer geometry needs a real width before it can lay anything out,
    // and the window size is only readable once dependencies are in.
    if (!_drawerGeometry.isBound) {
      _drawerGeometry
        ..updateWidth(WideLayout.drawerWidth(MediaQuery.sizeOf(context).width))
        ..bind();
    }
  }

  @override
  void dispose() {
    _drawerGeometry.dispose();
    _drawerController.dispose();
    for (final c in _scrollControllers) {
      c.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _backgroundedAt = DateTime.now();
      return;
    }
    final DateTime? away = _backgroundedAt;
    _backgroundedAt = null;
    // A glance at another app should not rescan and back up on the way back.
    if (away != null && DateTime.now().difference(away).inSeconds < 30) {
      return;
    }
    // Past the resume frames, and staggered so they never share one.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      ref.read(songsProvider.notifier).refresh(isBackground: true);
    });
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      ref.read(autoBackupProvider.notifier).checkAndRunAutoBackup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final settings = ref.watch(settingsProvider);
    final sidePanelOpen = ref.watch(_sidePanelOpenProvider);

    final tabs = _visibleTabs = _tabs(context, settings.youtubeEnabled);
    // The online tab can disappear; whatever was last in the list is always a
    // valid landing spot for an index that no longer exists.
    if (_selectedIndex >= tabs.length) _selectedIndex = tabs.length - 1;

    ref.listen(settingsProvider.select((s) => s.youtubeEnabled),
        (previous, next) {
      if (previous == next || next) return;
      final current = _selectedIndex < _visibleTabs.length
          ? _visibleTabs[_selectedIndex].id
          : '';
      if (current != 'online') return;
      setState(() {
        _tabDirection = -1;
        _selectedIndex = 0;
      });
    });

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
      if (_selectedIndex != 1 || !_builtScreens.contains('library')) {
        setState(() {
          _tabDirection = 1 > _selectedIndex ? 1 : -1;
          _selectedIndex = 1;
          _builtScreens.add('library');
        });
      }
    });

    // Wide windows (tablet/desktop landscape) earn the desktop arrangement.
    // Phones stay portrait-locked at the OS level, so this keys off size.
    final isWide = WideLayout.isWide(context);
    final libraryActive = _selectedIndex == 1;
    if (ref.read(browseTabActiveProvider) != libraryActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(browseTabActiveProvider.notifier).set(libraryActive);
        }
      });
    }
    final accent = AppTokens.accentOf(context, ref);
    // The geometry holds the one rest width the panel and the scrim both read.
    _drawerGeometry.updateWidth(
      WideLayout.drawerWidth(mediaQuery.size.width),
    );

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
                children: tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  if (!_builtScreens.contains(tab.id)) {
                    // Only build if this screen has been selected before
                    return const SizedBox.shrink();
                  }
                  return TabSwitchTransition(
                    active: index == _selectedIndex,
                    direction: _tabDirection,
                    child: tab.screen,
                  );
                }).toList(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: isSelectionMode
                ? const BulkSelectionBar()
                : isWide
                    ? const NowPlayingBar(
                        padding: EdgeInsets.zero,
                        docked: true,
                        leadingInset: 76,
                      )
                    : FloatingDock(
                        selectedIndex: _selectedIndex,
                        onSelected: _onTabSelected,
                        items: [for (final tab in tabs) tab.nav],
                        key: _dockKey,
                        autoCollapse: settings.autoHideBottomBarOnScroll,
                      ),
          ),
        ],
      );
    }

    Widget buildDrawerSlider({required Widget child}) {
      return AnimatedBuilder(
        animation: _drawerGeometry,
        builder: (context, child) {
          // The dim deepens through the elastic swell, along with the push.
          final scrimAlpha =
              (0.45 * _drawerGeometry.scrimProgress.clamp(0.0, 1.0) +
                      0.55 * _drawerGeometry.swellFraction)
                  .clamp(0.0, 0.6);
          final showScrim = _drawerChromeVisible && scrimAlpha > 0.001;
          return Stack(
            children: [
              Transform.translate(
                // The content rides out with the drawer, and follows its crest.
                offset: Offset(_drawerGeometry.contentOffset, 0),
                // Boundary under the transform: the slide moves a cached raster.
                child: FreezeWhileMoving(
                  animation: _drawerController,
                  dragging: _isDraggingDrawer,
                  child: RepaintBoundary(child: child!),
                ),
              ),
              // Outside the translate: the dim covers the window, and a tap on
              // it closes the drawer.
              if (showScrim)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeDrawer,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: scrimAlpha),
                    ),
                  ),
                ),
            ],
          );
        },
        child: child,
      );
    }

    Widget buildShellBody() {
      return MotionDragArea(
        axis: Axis.horizontal,
        // Desktop has the nav rail; a trackpad's sideways scroll would
        // otherwise drag the whole shell, bottom bar included.
        enabled: !isWide,
        // Only matters while the drawer is shut; once it is open the strip
        // would pull taps on its own buttons into a swipe.
        edgePriorityWidth: _isDrawerOpen ? 0 : WideLayout.drawerEdgeWidth,
        onStart: _onHorizontalDragStart,
        onUpdate: _onHorizontalDragUpdate,
        onEnd: _onHorizontalDragEnd,
        onCancel: _onHorizontalDragCancel,
        // The surface wraps the drawer as well as the content: the panel is a
        // sibling above it, so a drag started on the sheet never reached the
        // content's own surface and the drawer could only be pushed open.
        child: Stack(
          children: [
            // Content first, drawer above it: the content slides aside by the
            // panel's resting width, so the drawer is uncovered either way.
            buildDrawerSlider(child: buildContentStack()),
            AnimatedBuilder(
              animation: _drawerGeometry,
              child: Positioned.fill(
                child: AppDrawer(
                  onClose: _closeDrawer,
                  drawerPosition: _drawerController,
                  geometry: _drawerGeometry,
                ),
              ),
              builder: (context, child) {
                if (!_drawerChromeVisible) return const SizedBox.shrink();
                return child!;
              },
            ),
          ],
        ),
      );
    }

    if (isWide && !isSelectionMode) {
      void openSearch() => context.pushApp(const SearchScreen());
      void openSettings() => context.pushApp(const SettingsScreen());
      void openSleepTimer() => context.pushApp(const SleepTimerScreen());
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
            child: Stack(
              children: [
                Row(
                  children: [
                    _WideNavRail(
                      selectedIndex: _selectedIndex,
                      onSelected: _onTabSelected,
                      items: [for (final tab in tabs) tab.nav],
                      accent: accent,
                      onSearch: openSearch,
                      onSettings: openSettings,
                      onSleepTimer: openSleepTimer,
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          buildShellBody(),
                          // Above the content: the hover zone and its pill only
                          // work if nothing under them absorbs the pointer.
                          if (mediaQuery.size.width >= _sidePanelBreakpoint &&
                              settings.desktopSidebarEnabled &&
                              !sidePanelOpen)
                            const Positioned.fill(child: _SidebarEdgeReveal()),
                        ],
                      ),
                    ),
                    if (mediaQuery.size.width >= _sidePanelBreakpoint)
                      _AnimatedSidePanel(open: sidePanelOpen),
                  ],
                ),
                // The player is mounted here, not pushed: opening it is the
                // same motion a drag makes.
                const PlayerPanelHost(),
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
        child: Stack(
          children: [
            buildShellBody(),
            // The player is mounted here, not pushed: opening it is the same
            // motion a drag makes, so back is its own PopScope, not a route.
            const PlayerPanelHost(),
          ],
        ),
      ),
      // The floating dock is drawn inside the content stack so pages scroll
      // underneath it; no Scaffold bottom bar.
    );
  }
}

/// Side rail for wide windows: the same destinations as [AppNavBar],
/// laid out vertically desktop-style rather than as a bottom dock.
class _WideNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<AppNavItem> items;
  final Color accent;
  final VoidCallback? onSearch;
  final VoidCallback? onSettings;
  final VoidCallback? onSleepTimer;

  const _WideNavRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.accent,
    this.onSearch,
    this.onSettings,
    this.onSleepTimer,
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
            for (var i = 0; i < items.length; i++)
              _WideNavDestination(
                item: items[i],
                selected: i == selectedIndex,
                accent: accent,
                onTap: () => onSelected(i),
              ),
            const Spacer(),
            if (onSleepTimer != null)
              // The drawer is the only sleep timer entry on a phone, so a wide
              // window needs one here. It lights up while a timer is armed.
              ListenableBuilder(
                listenable: SleepTimerService.instance,
                builder: (context, _) => _WideNavAction(
                  icon: AppIcons.bedtime,
                  label: context.l10n.sleepTimerTitle,
                  tooltip: context.l10n.sleepTimerTitle,
                  accent: accent,
                  active: SleepTimerService.instance.isActive,
                  onTap: onSleepTimer!,
                ),
              ),
            if (onSearch != null)
              _WideNavAction(
                icon: AppIcons.search,
                label: context.l10n.actionSearch,
                tooltip: context.l10n.shellSearchTooltip,
                accent: accent,
                onTap: onSearch!,
              ),
            if (onSettings != null)
              _WideNavAction(
                icon: AppIcons.misc,
                label: context.l10n.settingsTitle,
                tooltip: context.l10n.settingsTitle,
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

  /// A live state worth showing, e.g. an armed sleep timer.
  final bool active;

  const _WideNavAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = active ? accent : AppTokens.fg(AppTokens.aTertiary);
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
                color: active
                    ? accent.withValues(alpha: AppTokens.accentWashAlpha)
                    : Colors.transparent,
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
  final AppNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _WideNavDestination({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                item.icon,
                size: AppTokens.iconMd,
                color: iconColor,
                strokeWidth: selected
                    ? AppTokens.iconStrokeEmphasis
                    : AppTokens.iconStroke,
              ),
            ),
            const SizedBox(height: AppTokens.s1),
            Text(
              item.label,
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

/// Hover zone on the right edge that reveals the hidden sidebar handle. The
/// handle tracks the pointer's y with a lagging ease, and x stays pinned.
class _SidebarEdgeReveal extends StatefulWidget {
  const _SidebarEdgeReveal();

  @override
  State<_SidebarEdgeReveal> createState() => _SidebarEdgeRevealState();
}

class _SidebarEdgeRevealState extends State<_SidebarEdgeReveal> {
  static const _zoneWidth = 96.0;
  static const _handleHeight = 56.0;
  static const _topDeadZone = _handleHeight / 2 * 2.5 * 1.2;
  static const _bottomDeadZone = _handleHeight / 2 * 2.5 * 1.8;

  double _y = 0;
  bool _inZone = false;

  void _onHover(PointerHoverEvent event) {
    final size = context.size;
    if (size == null) return;
    final dy = event.localPosition.dy;
    final nearVerticalEdge =
        dy < _topDeadZone || dy > size.height - _bottomDeadZone;
    final inZone =
        !nearVerticalEdge && event.localPosition.dx >= size.width - _zoneWidth;
    final y = (dy - _handleHeight / 2)
        .clamp(0.0, size.height - _handleHeight)
        .toDouble();
    if (inZone == _inZone && (!inZone || y == _y)) return;
    setState(() {
      _inZone = inZone;
      if (inZone) _y = y;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onExit: (_) {
        if (_inZone) setState(() => _inZone = false);
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: _onHover,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: MotionPolicy.of(context).duration(MotionTokens.slow),
              curve: MotionTokens.standardCurve,
              top: _y,
              right: PlayerTokens.s1,
              child: AnimatedOpacity(
                duration: MotionPolicy.of(context).duration(MotionTokens.fast),
                opacity: _inZone ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_inZone,
                  child: const _WideSidePanelHandle(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill that restores the hidden right sidebar in one click.
class _WideSidePanelHandle extends ConsumerWidget {
  const _WideSidePanelHandle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: context.l10n.shellShowSidebar,
      child: Pressable(
        onTap: () => ref.read(_sidePanelOpenProvider.notifier).set(true),
        child: Container(
          width: 28,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.floatingFill,
            borderRadius: AppTokens.brSm,
          ),
          child: const AppIcon(AppIcons.arrowBack, size: 16),
        ),
      ),
    );
  }
}

/// Whether the desktop Lyrics/Queue sidebar is shown. Session-only: the
/// settings toggle controls the expand handle, not this.
class _SidePanelOpenNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool open) => state = open;
}

final _sidePanelOpenProvider =
    NotifierProvider<_SidePanelOpenNotifier, bool>(_SidePanelOpenNotifier.new);

/// Window width at which the shell docks Lyrics/Queue on the right instead of
/// leaving the extra width empty.
const double _sidePanelBreakpoint = 1200;

/// Desktop right column, slid open and closed on a spring. The panel stays
/// mounted so lyrics and queue state survive a toggle.
class _AnimatedSidePanel extends StatefulWidget {
  final bool open;

  const _AnimatedSidePanel({required this.open});

  @override
  State<_AnimatedSidePanel> createState() => _AnimatedSidePanelState();
}

class _AnimatedSidePanelState extends State<_AnimatedSidePanel>
    with TickerProviderStateMixin {
  /// How far the pane has been revealed. Its width cannot overshoot — the
  /// window edge is the end of the travel — so the bounce lives elsewhere.
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 1 : 0,
  );
  late final SnapEngine _snap = SnapEngine(_c);

  /// The column's own spring, 1 at the trailing edge and 0 at home. It gives
  /// the content its own soft landing on top of the pane's width, so the open
  /// is a layered move rather than one surface arriving flat.
  late final AnimationController _trailC = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionPolicy.of(context).reduceMotion) {
      _snap.jumpTo(widget.open ? 1 : 0);
      _trailC.value = widget.open ? 0 : 1;
    }
  }

  @override
  void didUpdateWidget(_AnimatedSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open == widget.open) return;
    final double target = widget.open ? 1 : 0;
    if (MotionPolicy.read(context).reduceMotion) {
      _snap.jumpTo(target);
      _trailC.value = target == 1 ? 0 : 1;
      return;
    }
    if (widget.open) {
      // Only reset the trailing edge when the pane was fully closed; a re-open
      // mid-close carries on from where the column already is.
      if (_c.value <= 0.001) _trailC.value = 1;
      MotionSprings.driveTo(_trailC, 0, spring: MotionSprings.gentle);
    }
    // The pane's own travel ends at the window edge, so an overshooting spring
    // would freeze against it; the bounce lives in the column instead.
    _snap.springTo(
      target,
      spring: widget.open ? MotionSprings.panel : MotionSprings.settle,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _trailC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double width = _WideSidePanel.widthFor(context);
    return AnimatedBuilder(
      animation: _c,
      // Its own layer: the spring then clips the panel instead of repainting
      // its cover and lyrics on every frame.
      child: RepaintBoundary(
        child: _WideSidePanel(contentSpring: _trailC),
      ),
      builder: (context, child) {
        final double progress = _c.value;
        final double reveal = (width * progress).clamp(0.0, width);
        final bool visible = progress > 0.002;
        // A closed panel is offstage rather than clipped to nothing: its tree
        // keeps its state but stops ticking, laying out and painting, which is
        // what a clipped-but-live lyrics/queue column was costing.
        return SizedBox(
          width: reveal,
          child: Offstage(
            offstage: !visible,
            child: TickerMode(
              enabled: visible,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: width,
                  maxWidth: width,
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Desktop right column, Spotify-style: one scroll of now playing art, a
/// lyrics block and the upcoming queue. No tabs; everything is visible at once.
class _WideSidePanel extends ConsumerStatefulWidget {
  const _WideSidePanel({this.contentSpring});

  /// 1 at the trailing edge, 0 at home. The column rides it so the pane can
  /// settle with a bounce the window edge would otherwise swallow.
  final ValueListenable<double>? contentSpring;

  /// The pane's own width at the current window size. The shell reserves it.
  static double widthFor(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * 0.24).clamp(320.0, 420.0);

  /// How far the column starts behind its place, in logical pixels.
  static const double contentTrail = 44;

  @override
  ConsumerState<_WideSidePanel> createState() => _WideSidePanelState();
}

class _WideSidePanelState extends ConsumerState<_WideSidePanel> {
  /// Used when the pane is not moving; keeps the builder below unconditional.
  static final ValueNotifier<double> _still = ValueNotifier<double>(0);

  // The panel is always on screen when built, so lyrics always sync.
  final ValueNotifier<bool> _lyricsVisible = ValueNotifier(true);

  /// Drives the arrival pop on the row most recently moved to the top.
  String? _movedId;
  DateTime? _movedAt;

  @override
  void dispose() {
    _lyricsVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final accent = AppTokens.accentOf(context, ref);
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final width = _WideSidePanel.widthFor(context);

    return Theme(
      data: AppTheme.getPlayerTheme(themeState, accent),
      child: Container(
        width: width,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<Song?>(
              valueListenable: audioManager.currentSongNotifier,
              builder: (context, song, _) => song == null
                  ? const SizedBox.shrink()
                  : BlurredBackground(
                      url: song.coverUrl ?? '',
                      filename: song.filename,
                      gradientColors: [
                        Color.alphaBlend(
                          accent.withValues(alpha: 0.18),
                          Colors.black.withValues(alpha: 0.68),
                        ),
                        Colors.black.withValues(alpha: 0.94),
                      ],
                    ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: widget.contentSpring ?? _still,
              child: RepaintBoundary(
                child: SafeArea(
                  left: false,
                  child: ValueListenableBuilder<Song?>(
                    valueListenable: audioManager.currentSongNotifier,
                    builder: (context, song, _) {
                      if (song == null) {
                        return Center(
                          child: Text(
                            context.l10n.playerNothingPlaying,
                            style: PlayerTokens.meta(context),
                          ),
                        );
                      }
                      return ValueListenableBuilder<List<QueueItem>>(
                        valueListenable: audioManager.queueNotifier,
                        builder: (context, queue, _) => StreamBuilder<int?>(
                          stream: audioManager.settledCurrentIndexStream,
                          initialData: audioManager.player.currentIndex,
                          builder: (context, snapshot) {
                            final current = snapshot.data ?? -1;
                            final upcoming = current >= 0
                                ? queue.skip(current + 1).toList()
                                : queue;
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
              builder: (context, shift, child) => Transform.translate(
                offset: Offset(_WideSidePanel.contentTrail * shift, 0),
                child: child,
              ),
            ),
          ],
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
              IconButton(
                tooltip: context.l10n.shellHideSidebar,
                onPressed: () =>
                    ref.read(_sidePanelOpenProvider.notifier).set(false),
                icon: const AppIcon(AppIcons.chevronRight),
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
            upcoming.isEmpty
                ? context.l10n.shellNothingUpNext
                : context.l10n.shellNextInQueue,
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
              return RemovableEntry(
                key: ValueKey(item.queueId),
                id: 'side_${item.queueId}',
                child: MotionPop(
                  trigger: _movedId == item.queueId ? _movedAt : null,
                  child: _SideQueueRow(
                    item: item,
                    accent: accent,
                    onTap: () => audioManager.jumpToQueueItem(item.queueId),
                    onMoveToTop: i == 0
                        ? null
                        : () async {
                            await audioManager.moveUpcomingToTop(item.queueId);
                            if (!mounted) return;
                            setState(() {
                              _movedId = item.queueId;
                              _movedAt = DateTime.now();
                            });
                          },
                    onRemove: () {
                      AnimatedRemoval.run(
                        'side_${item.queueId}',
                        () async {
                          final index = audioManager.queueNotifier.value
                              .indexWhere((q) => q.queueId == item.queueId);
                          if (index >= 0) {
                            await audioManager.removeFromQueue(index);
                          }
                        },
                        exit: MotionPolicy.read(context)
                            .duration(MotionTokens.slow),
                      );
                    },
                  ),
                ),
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
                    tooltip: context.l10n.shellPlayNext,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    color: muted,
                    icon: const Icon(Icons.vertical_align_top_rounded),
                    onPressed: widget.onMoveToTop,
                  ),
                IconButton(
                  tooltip: context.l10n.queueRemoveFromQueueTooltip,
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
