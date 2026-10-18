import 'package:flutter/material.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../routes/app_page_route.dart';
import 'quick_actions_settings_screen.dart';
import '../tokens/app_icons.dart';

class HomeSettingsScreen extends ConsumerStatefulWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const HomeSettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  @override
  ConsumerState<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends ConsumerState<HomeSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: 'Lists & Navigation',
          icon: AppIcons.viewList,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.timer,
              searchId: 'appearance.song_duration',
              title: 'Show Song Duration',
              subtitle: 'Display duration in song lists',
              value: settings.showSongDuration,
              onChanged: notifier.setShowSongDuration,
            ),
            AppSettingsSwitch(
              icon: AppIcons.swapVert,
              searchId: 'appearance.auto_hide_bars',
              title: 'Auto-Hide Bars',
              subtitle:
                  'Header and bottom dock hide on downward scroll, restore on upward scroll',
              value: settings.autoHideBottomBarOnScroll,
              onChanged: notifier.setAutoHideBottomBarOnScroll,
            ),
            AppSettingsTile(
              icon: AppIcons.flashOn,
              searchId: 'appearance.quick_actions',
              title: 'Quick Actions',
              subtitle: 'Customize long-press actions',
              onTap: () => context.pushApp(const QuickActionsSettingsScreen()),
            ),
          ],
        ),
        AppSettingsGroup(
          label: 'Home screen',
          icon: AppIcons.home,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.autoAwesome,
              searchId: 'appearance.quick_picks',
              title: 'Quick Picks',
              subtitle: 'Show quick pick recommendations',
              value: settings.showQuickPicks,
              onChanged: notifier.setShowQuickPicks,
            ),
            AppSettingsSwitch(
              icon: AppIcons.clock,
              searchId: 'appearance.recent_queues',
              title: 'Recent Queues',
              subtitle: 'Show recently played queues',
              value: settings.showRecentQueues,
              onChanged: notifier.setShowRecentQueues,
            ),
            AppSettingsSwitch(
              icon: AppIcons.explore,
              searchId: 'appearance.for_you',
              title: 'For You',
              subtitle: 'Show recommended playlists',
              value: settings.showForYou,
              onChanged: notifier.setShowForYou,
            ),
          ],
        ),
      ],
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: const AppTopBar(title: 'Home & Navigation'),
      body: content,
    );
  }
}
