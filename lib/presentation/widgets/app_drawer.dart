import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../components/app_section_header.dart';
import '../routes/player_route.dart';
import '../screens/play_history_screen.dart';
import '../screens/playlists_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sleep_timer_screen.dart';
import '../screens/song_list_screen.dart';
import '../screens/unified_player_screen.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';

/// The slide-out navigation panel.
///
/// It used to carry nine cached gradients, a blur, a drop shadow and a
/// different accent colour per row. All of that is gone: the panel is one flat
/// surface and the rows are [AppListRow]s, so it looks like the screens it
/// navigates to.
class AppDrawer extends ConsumerStatefulWidget {
  final Future<void> Function() onClose;
  final double drawerPosition;

  const AppDrawer({
    super.key,
    required this.onClose,
    required this.drawerPosition,
  });

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  static const _panelRadius = BorderRadius.only(
    topRight: Radius.circular(AppTokens.rSm),
    bottomRight: Radius.circular(AppTokens.rSm),
  );

  Future<void> _closeDrawer() async {
    await widget.onClose();
  }

  void _navigateTo(Widget screen) {
    _closeDrawer().then((_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      }
    });
  }

  /// Queue history lives inside the unified player's Queue pane, so this opens
  /// the player straight onto that segment rather than a standalone screen.
  void _openQueueHistory() {
    _closeDrawer().then((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        PlayerPageRoute(
          initialPane: PlayerPane.queue,
          queueShowsHistory: true,
        ),
      );
    });
  }

  /// Jump to the Library bottom-nav tab on Artists / Albums instead of pushing
  /// a second LibraryScreen that lacks the shell chrome.
  void _openLibrarySubTab(int subTabIndex) {
    _closeDrawer().then((_) {
      if (!mounted) return;
      ref.read(libraryNavigationProvider.notifier).openSubTab(subTabIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accentOf(context, ref);

    final updateAvailable = ref.watch(
      updateCheckProvider.select((state) => state.hasUpdate),
    );

    // Entrance: slide in from off-screen left — no opacity animation, so the
    // background is always opaque and there is no gray-flash before the panel.
    final animationValue = widget.drawerPosition;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // One formula with the slide animation and the edge-drag math, capped on
    // wide windows and floored on narrow ones.
    final drawerWidth = WideLayout.drawerWidth(screenWidth);
    final slideInOffset = (1.0 - animationValue) * -drawerWidth;

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: drawerWidth,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final currentWidth = constraints.maxWidth;
            final iconSize = (currentWidth * 0.17).clamp(24.0, 40.0);
            final headerIconSize = (currentWidth * 0.17).clamp(24.0, 40.0);
            final textFontSize = (currentWidth * 0.085).clamp(13.0, 18.0);
            final headerFontSize = (currentWidth * 0.11).clamp(16.0, 24.0);

            return RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppTokens.surface(1),
                    Theme.of(context).scaffoldBackgroundColor,
                  ),
                  borderRadius: _panelRadius,
                ),
                child: Transform.translate(
                  offset: Offset(slideInOffset, 0),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          context,
                          accent,
                          iconSize: headerIconSize,
                          fontSize: headerFontSize,
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppTokens.s1,
                              0,
                              AppTokens.s1,
                              AppTokens.s3,
                            ),
                            children: [
                              const AppSectionHeader(
                                label: 'Library',
                                padding: EdgeInsets.fromLTRB(
                                  AppTokens.s2,
                                  AppTokens.s2,
                                  AppTokens.s2,
                                  0,
                                ),
                              ),
                              _buildNavItem(
                                icon: AppIcons.favorite,
                                label: 'Favorites',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () async {
                                  final songs =
                                      await ref.read(songsProvider.future);
                                  final userDataState =
                                      ref.read(userDataProvider);
                                  final favSongs = songs
                                      .where((s) =>
                                          userDataState.isFavorite(s.filename))
                                      .toList();
                                  if (context.mounted) {
                                    _navigateTo(SongListScreen(
                                      title: 'Favorites',
                                      songs: favSongs,
                                    ));
                                  }
                                },
                              ),
                              _buildNavItem(
                                icon: AppIcons.queue,
                                label: 'Playlists',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () =>
                                    _navigateTo(const PlaylistsScreen()),
                              ),
                              _buildNavItem(
                                icon: AppIcons.album,
                                label: 'Albums',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () => _openLibrarySubTab(2),
                              ),
                              _buildNavItem(
                                icon: AppIcons.person,
                                label: 'Artists',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () => _openLibrarySubTab(1),
                              ),
                              const AppSectionHeader(
                                label: 'History',
                                padding: EdgeInsets.fromLTRB(
                                  AppTokens.s2,
                                  AppTokens.s3,
                                  AppTokens.s2,
                                  0,
                                ),
                              ),
                              _buildNavItem(
                                icon: AppIcons.clock,
                                label: 'Song History',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () =>
                                    _navigateTo(const PlayHistoryScreen()),
                              ),
                              _buildNavItem(
                                icon: AppIcons.queuePlayNext,
                                label: 'Session History',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () =>
                                    _navigateTo(const SessionHistoryScreen()),
                              ),
                              _buildNavItem(
                                icon: AppIcons.queue,
                                label: 'Queue History',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: _openQueueHistory,
                              ),
                              const AppSectionHeader(
                                label: 'Tools',
                                padding: EdgeInsets.fromLTRB(
                                  AppTokens.s2,
                                  AppTokens.s3,
                                  AppTokens.s2,
                                  0,
                                ),
                              ),
                              _buildNavItem(
                                icon: AppIcons.bedtime,
                                label: 'Sleep Timer',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () =>
                                    _navigateTo(const SleepTimerScreen()),
                              ),
                              const AppSectionHeader(
                                label: 'App',
                                padding: EdgeInsets.fromLTRB(
                                  AppTokens.s2,
                                  AppTokens.s3,
                                  AppTokens.s2,
                                  0,
                                ),
                              ),
                              _buildNavItem(
                                icon: AppIcons.settings,
                                label: 'Settings',
                                iconSize: iconSize,
                                fontSize: textFontSize,
                                onTap: () =>
                                    _navigateTo(const SettingsScreen()),
                                showBadge: updateAvailable,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color accent, {
    required double iconSize,
    required double fontSize,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s3,
        AppTokens.s3,
        AppTokens.s2,
        AppTokens.s2,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppTokens.brSm,
            child: SizedBox(
              width: iconSize,
              height: iconSize,
              child: Image.asset(
                'assets/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: accent.withValues(alpha: AppTokens.accentWashAlpha),
                  child: AppIcon(
                    AppIcons.musicNote,
                    color: accent,
                    size: iconSize * 0.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTokens.s2),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Wispie',
                style:
                    AppTokens.paneTitle(context).copyWith(fontSize: fontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Glyphs here all carry the cover accent — these rows are destinations, so
  /// none of them is ever "active", and a uniform tint is the point rather than
  /// a signal. The red dot is the one thing that means something.
  Widget _buildNavItem({
    required AppIconData icon,
    required String label,
    required VoidCallback? onTap,
    required double iconSize,
    required double fontSize,
    bool showBadge = false,
  }) {
    return AppListRow(
      title: label,
      titleWidget: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: AppTokens.rowTitle(context).copyWith(fontSize: fontSize),
        ),
      ),
      onTap: onTap,
      dense: true,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          AppRowIcon(icon: icon, size: iconSize),
          if (showBadge)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTokens.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
