import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../l10n/l10n.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../components/app_icon.dart';
import '../components/app_section_header.dart';
import '../components/pressable.dart';
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

/// The slide-out navigation panel.
///
/// Destinations are tonal [Pressable] buttons rather than flat sheet rows, so
/// each entry reads as a control you tap, not a line of text on a page.
class AppDrawer extends ConsumerStatefulWidget {
  final Future<void> Function() onClose;

  final double width;

  const AppDrawer({
    super.key,
    required this.onClose,
    required this.width,
  });

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
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
    final updateAvailable = ref.watch(
      updateCheckProvider.select((state) => state.hasUpdate),
    );
    final l10n = context.l10n;
    final drawerWidth = widget.width;
    final iconSize = (drawerWidth * 0.12).clamp(20.0, 28.0);
    final headerIconSize = (drawerWidth * 0.17).clamp(24.0, 40.0);
    final textFontSize = (drawerWidth * 0.078).clamp(13.0, 16.0);
    final headerFontSize = (drawerWidth * 0.11).clamp(16.0, 24.0);

    return SafeArea(
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
                    final songsByFilename = {
                      for (final song in songs) song.filename: song,
                      ...userDataState.remoteSongs,
                    };
                    final favSongs = userDataState.favorites
                        .map((filename) => songsByFilename[filename])
                        .whereType<Song>()
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
                context.l10n.appName,
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
