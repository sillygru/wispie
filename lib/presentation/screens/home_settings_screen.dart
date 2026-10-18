import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.homeSettingsGroupLists,
          icon: AppIcons.viewList,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.timer,
              searchId: 'appearance.song_duration',
              title: l10n.settingsSearchSongDurationTitle,
              subtitle: l10n.settingsSearchSongDurationSubtitle,
              value: settings.showSongDuration,
              onChanged: notifier.setShowSongDuration,
            ),
            AppSettingsSwitch(
              icon: AppIcons.swapVert,
              searchId: 'appearance.auto_hide_bars',
              title: l10n.settingsSearchAutoHideBarsTitle,
              subtitle: l10n.homeSettingsAutoHideBarsSubtitle,
              value: settings.autoHideBottomBarOnScroll,
              onChanged: notifier.setAutoHideBottomBarOnScroll,
            ),
            AppSettingsTile(
              icon: AppIcons.flashOn,
              searchId: 'appearance.quick_actions',
              title: l10n.quickActionsTitle,
              subtitle: l10n.settingsSearchQuickActionsSubtitle,
              onTap: () => context.pushApp(const QuickActionsSettingsScreen()),
            ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.homeSettingsGroupHome,
          icon: AppIcons.home,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.autoAwesome,
              searchId: 'appearance.quick_picks',
              title: l10n.homeQuickPicks,
              subtitle: l10n.settingsSearchQuickPicksSubtitle,
              value: settings.showQuickPicks,
              onChanged: notifier.setShowQuickPicks,
            ),
            AppSettingsSwitch(
              icon: AppIcons.clock,
              searchId: 'appearance.recent_queues',
              title: l10n.homeRecentQueues,
              subtitle: l10n.settingsSearchRecentQueuesSubtitle,
              value: settings.showRecentQueues,
              onChanged: notifier.setShowRecentQueues,
            ),
            AppSettingsSwitch(
              icon: AppIcons.explore,
              searchId: 'appearance.for_you',
              title: l10n.homeForYou,
              subtitle: l10n.settingsSearchForYouSubtitle,
              value: settings.showForYou,
              onChanged: notifier.setShowForYou,
            ),
          ],
        ),
      ],
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPageHomeNavigationTitle),
      body: content,
    );
  }
}
