import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../../services/debug_sandbox.dart';
import '../../services/update_service.dart';
import '../components/app_feedback.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../components/app_surface.dart';
import '../tokens/app_tokens.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

/// Where "contact me" goes. Bugs and feature requests belong in the issue
/// tracker; this is for the things that do not fit a template.
const String _contactUrl = 'https://gru0.dev/contact/';

class AboutSettingsScreen extends ConsumerWidget {
  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const AboutSettingsScreen({super.key, this.embedded = false});

  Future<void> _openLink(BuildContext context, String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } on Object catch (error) {
      debugPrint('About: could not open $url: $error');
      if (!context.mounted) return;
    }
    appSnack(context, context.l10n.aboutLinkFailed, tone: AppTone.danger);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateCheckProvider);
    final updateNotifier = ref.read(updateCheckProvider.notifier);
    final accent = AppTokens.accentOf(context, ref);
    final l10n = context.l10n;

    final statusTitle = updateState.isChecking
        ? l10n.aboutChecking
        : updateState.hasUpdate
            ? l10n.aboutUpdateAvailable(updateState.latestVersionLabel ?? '')
            : updateState.latestVersionLabel != null
                ? l10n.aboutUpToDate
                : l10n.aboutCheckForUpdates;

    final statusSubtitle = updateState.isChecking
        ? l10n.aboutCheckingSubtitle
        : updateState.hasUpdate
            ? l10n.aboutUpdateAvailableSubtitle
            : updateState.latestVersionLabel != null
                ? l10n.aboutLatestRelease(updateState.latestVersionLabel ?? '')
                : l10n.aboutTapToCheck;

    final content = AppSettingsList(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppTokens.s4),
          child: AppSurface(
            padding: const EdgeInsets.all(AppTokens.s5),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppTokens.brSm,
                  child: Image.asset(
                    ref.watch(settingsProvider).appIconStyle.previewAsset,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppTokens.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('wispie', style: AppTokens.screenTitle(context)),
                      const SizedBox(height: 2),
                      Text(
                        l10n.aboutVersion(updateState.currentVersion.isEmpty
                            ? l10n.aboutUnknown
                            : updateState.currentVersion),
                        style: AppTokens.meta(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.s3),
        AppSurface(
          padding: const EdgeInsets.all(AppTokens.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIcon(
                    updateState.hasUpdate
                        ? AppIcons.softwareUpdate
                        : AppIcons.verified,
                    color: accent,
                    size: 20,
                  ),
                  const SizedBox(width: AppTokens.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(statusTitle, style: AppTokens.rowTitle(context)),
                        const SizedBox(height: 2),
                        Text(statusSubtitle,
                            style: AppTokens.rowSubtitle(context)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.s4),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: updateState.isChecking
                          ? null
                          : () => updateNotifier.checkForUpdate(force: true),
                      style: AppTokens.tonalButton,
                      child: Text(l10n.aboutCheckNow),
                    ),
                  ),
                  if (updateState.hasUpdate) ...[
                    const SizedBox(width: AppTokens.s3),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => UpdateService().openLatestRelease(
                          url: updateState.releaseUrl,
                        ),
                        child: Text(l10n.aboutViewRelease),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s3),
        AppSettingsGroup(
          label: l10n.aboutSupportGroup,
          icon: AppIcons.info,
          children: [
            AppSettingsTile(
              icon: AppIcons.openInNew,
              title: l10n.aboutContactTitle,
              subtitle: l10n.aboutContactSubtitle,
              trailing: const AppIcon(AppIcons.openInNew,
                  size: AppTokens.iconSm, color: AppTokens.fgTertiary),
              onTap: () => _openLink(context, _contactUrl),
            ),
            AppSettingsTile(
              icon: AppIcons.dataObject,
              title: l10n.aboutIssuesTitle,
              subtitle: l10n.aboutIssuesSubtitle,
              trailing: const AppIcon(AppIcons.openInNew,
                  size: AppTokens.iconSm, color: AppTokens.fgTertiary),
              onTap: () => _openLink(context, UpdateService.issuesUrl),
            ),
          ],
        ),
        if (kDebugMode)
          AppSettingsGroup(
            label: l10n.aboutDebugGroup,
            icon: AppIcons.tune,
            children: [
              StatefulBuilder(
                builder: (context, setState) => AppSettingsSwitch(
                  icon: AppIcons.cloudUpload,
                  title: l10n.aboutPersistWrites,
                  subtitle: l10n.aboutPersistWritesSubtitle,
                  value: DebugSandbox.persistWrites,
                  onChanged: (val) async {
                    await DebugSandbox.setFlag('persist_writes', val);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
      ],
    );
    if (embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPageAboutTitle),
      body: content,
    );
  }
}
