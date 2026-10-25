import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../components/app_icon.dart';
import '../components/app_section_header.dart';
import '../components/pressable.dart';
import '../motion/drawer_geometry.dart';
import '../motion/motion.dart';
import '../player_panel/player_panel.dart';
import '../screens/play_history_screen.dart';
import '../screens/playlists_screen.dart';
import '../screens/session_history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/sleep_timer_screen.dart';
import '../screens/song_list_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/unified_player_screen.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';

/// The slide-out navigation panel.
///
/// Destinations are tonal [Pressable] buttons rather than flat sheet rows, so
/// each entry reads as a control you tap, not a line of text on a page.
class AppDrawer extends ConsumerStatefulWidget {
  final Future<void> Function() onClose;

  /// The drawer's single progress driver. Rest width and reveal both come from
  /// [geometry]; the raw value is to know when the driver is moving.
  final Animation<double> drawerPosition;
  final DrawerGeometry geometry;

  const AppDrawer({
    super.key,
    required this.onClose,
    required this.drawerPosition,
    required this.geometry,
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
      PlayerPanel.open(
        initialPane: PlayerPane.queue,
        queueShowsHistory: true,
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
    final l10n = context.l10n;

    final updateAvailable = ref.watch(
      updateCheckProvider.select((state) => state.hasUpdate),
    );

    // Entrance: slide in from off-screen left — no opacity animation, so the
    // background is always opaque and there is no gray-flash before the panel.
    final screenWidth = MediaQuery.sizeOf(context).width;
    // One formula with the slide animation and the edge-drag math, capped on
    // wide windows and floored on narrow ones.
    final drawerWidth = WideLayout.drawerWidth(screenWidth);

    // Layout sizes stay locked to the resting drawer width so buttons never
    // reflow or spill during overshoot — only the sheet chrome stretches.
    final iconSize = (drawerWidth * 0.12).clamp(20.0, 28.0);
    final headerIconSize = (drawerWidth * 0.17).clamp(24.0, 40.0);
    final textFontSize = (drawerWidth * 0.078).clamp(13.0, 16.0);
    final headerFontSize = (drawerWidth * 0.11).clamp(16.0, 24.0);

    final body = SafeArea(
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
              // Own physics, own layer: the shell's open gesture no longer
              // wraps this list, so scroll should not wait on a competing
              // horizontal arena.
              physics: const MotionBouncingPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s3,
                0,
                AppTokens.s3,
                AppTokens.s4,
              ),
              children: [
                AppSectionHeader(
                  label: l10n.libraryTitle,
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.s1,
                    AppTokens.s2,
                    AppTokens.s1,
                    AppTokens.s2,
                  ),
                ),
                _buildNavButton(
                  icon: AppIcons.favorite,
                  label: l10n.libraryFavorites,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () async {
                    final songs = await ref.read(songsProvider.future);
                    final userDataState = ref.read(userDataProvider);
                    final favSongs = songs
                        .where((s) => userDataState.isFavorite(s.filename))
                        .toList();
                    if (context.mounted) {
                      _navigateTo(SongListScreen(
                        title: l10n.libraryFavorites,
                        songs: favSongs,
                      ));
                    }
                  },
                ),
                _buildNavButton(
                  icon: AppIcons.queue,
                  label: l10n.playlistsTitle,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _navigateTo(const PlaylistsScreen()),
                ),
                _buildNavButton(
                  icon: AppIcons.album,
                  label: l10n.gradientDetailAlbums,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _openLibrarySubTab(2),
                ),
                _buildNavButton(
                  icon: AppIcons.person,
                  label: l10n.searchFilterArtists,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _openLibrarySubTab(1),
                ),
                AppSectionHeader(
                  label: l10n.queueTabHistory,
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.s1,
                    AppTokens.s4,
                    AppTokens.s1,
                    AppTokens.s2,
                  ),
                ),
                _buildNavButton(
                  icon: AppIcons.analytics,
                  label: l10n.statsTitle,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _navigateTo(const StatsScreen()),
                ),
                _buildNavButton(
                  icon: AppIcons.clock,
                  label: l10n.playHistoryTitle,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _navigateTo(const PlayHistoryScreen()),
                ),
                _buildNavButton(
                  icon: AppIcons.queuePlayNext,
                  label: l10n.sessionHistoryTitle,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _navigateTo(const SessionHistoryScreen()),
                ),
                _buildNavButton(
                  icon: AppIcons.queue,
                  label: l10n.drawerQueueHistory,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: _openQueueHistory,
                ),
                AppSectionHeader(
                  label: l10n.drawerTools,
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.s1,
                    AppTokens.s4,
                    AppTokens.s1,
                    AppTokens.s2,
                  ),
                ),
                _buildNavButton(
                  icon: AppIcons.bedtime,
                  label: l10n.sleepTimerTitle,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _navigateTo(const SleepTimerScreen()),
                ),
                AppSectionHeader(
                  label: l10n.settingsGroupApp,
                  padding: EdgeInsets.fromLTRB(
                    AppTokens.s1,
                    AppTokens.s4,
                    AppTokens.s1,
                    AppTokens.s2,
                  ),
                ),
                _buildNavButton(
                  icon: AppIcons.settings,
                  label: l10n.settingsTitle,
                  iconSize: iconSize,
                  fontSize: textFontSize,
                  accent: accent,
                  onTap: () => _navigateTo(const SettingsScreen()),
                  showBadge: updateAvailable,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: RepaintBoundary(
        child: _DrawerSheet(
          position: widget.drawerPosition,
          geometry: widget.geometry,
          panelRadius: _panelRadius,
          color: Color.alphaBlend(
            AppTokens.surface(1),
            Theme.of(context).scaffoldBackgroundColor,
          ),
          child: body,
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
                ref.watch(settingsProvider).appIconStyle.previewAsset,
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
                'wispie',
                style:
                    AppTokens.paneTitle(context).copyWith(fontSize: fontSize),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tonal button tile — filled surface + press spring, not a sheet list row.
  Widget _buildNavButton({
    required AppIconData icon,
    required String label,
    required VoidCallback? onTap,
    required double iconSize,
    required double fontSize,
    required Color accent,
    bool showBadge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s2),
      child: Pressable(
        onTap: onTap,
        haptic: PressHaptic.selection,
        alignment: Alignment.centerLeft,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s3,
            vertical: AppTokens.s3,
          ),
          decoration: BoxDecoration(
            color: AppTokens.surface(2),
            borderRadius: AppTokens.brMd,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppIcon(
                    icon,
                    size: iconSize,
                    color: accent,
                  ),
                  if (showBadge)
                    Positioned(
                      right: -2,
                      top: -2,
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
              const SizedBox(width: AppTokens.s3),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.rowTitle(context).copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grows open out of the window edge, then swells past open instead of shoving
/// the buttons off the panel.
///
/// The sheet never slides across the screen, so the background underneath holds
/// still. Its near edge stays on the window edge and its trailing edge does all
/// the travelling; the content keeps its resting width, so the buttons stay put
/// and the sheet reveals more of them rather than dragging them along.
class _DrawerSheet extends StatelessWidget {
  final Animation<double> position;
  final DrawerGeometry geometry;
  final BorderRadius panelRadius;
  final Color color;
  final Widget child;

  const _DrawerSheet({
    required this.position,
    required this.geometry,
    required this.panelRadius,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([position, geometry]),
      child: child,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: panelRadius,
          child: ColoredBox(
            color: color,
            child: SizedBox(
              width: geometry.panelWidth,
              // Laid out at its resting width and clipped: a growing sheet
              // uncovers more panel rather than squeezing or rescaling the
              // content inside it.
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: geometry.restWidth,
                maxWidth: geometry.restWidth,
                child: Transform.translate(
                  offset: Offset(geometry.contentDrift, 0),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
