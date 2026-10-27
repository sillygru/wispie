import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/settings_provider.dart';
import '../components/ambient_scaffold.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../routes/app_page_route.dart';
import '../tokens/app_icons.dart';
import 'youtube_account_screen.dart';

/// Settings for the online (YouTube) catalogue.
///
/// The whole catalogue is optional: turning it off removes the tab and the
/// account entry points, and nothing in the app calls YouTube afterwards.
class OnlineSettingsScreen extends ConsumerStatefulWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const OnlineSettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  @override
  ConsumerState<OnlineSettingsScreen> createState() =>
      _OnlineSettingsScreenState();
}

class _OnlineSettingsScreenState extends ConsumerState<OnlineSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.onlineSettingsGroup,
          icon: AppIcons.musicNote,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.musicNote,
              searchId: 'online.enabled',
              title: l10n.settingsYoutubeEnabledTitle,
              subtitle: l10n.settingsYoutubeEnabledSubtitle,
              value: settings.youtubeEnabled,
              onChanged: notifier.setYoutubeEnabled,
            ),
            if (settings.youtubeEnabled)
              AppSettingsTile(
                icon: AppIcons.person,
                searchId: 'online.account',
                title: l10n.youtubeAccountTitle,
                subtitle: l10n.settingsYoutubeAccountSubtitle,
                onTap: () => context.pushApp(const YouTubeAccountScreen()),
              ),
          ],
        ),
      ],
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPageOnlineTitle),
      body: content,
    );
  }
}
