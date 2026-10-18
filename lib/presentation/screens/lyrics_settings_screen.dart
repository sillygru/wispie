import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../components/ambient_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/app_settings.dart';
import '../dialogs/lyrics_translation_sheet.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';

class LyricsSettingsScreen extends ConsumerStatefulWidget {
  /// Row to reveal when opened from settings search.
  final String? highlightId;

  /// When true, renders content only for the wide master-detail pane.
  final bool embedded;

  const LyricsSettingsScreen(
      {super.key, this.highlightId, this.embedded = false});

  @override
  ConsumerState<LyricsSettingsScreen> createState() =>
      _LyricsSettingsScreenState();
}

class _LyricsSettingsScreenState extends ConsumerState<LyricsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = context.l10n;

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: l10n.lyricsGroupDisplayTiming,
          icon: AppIcons.subtitles,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.autoAwesome,
              searchId: 'lyrics.rich_sync',
              title: l10n.lyricsSimulateWordSyncTitle,
              subtitle: l10n.lyricsSimulateWordSyncSubtitle,
              value: settings.lyricsSimulatedRichSyncEnabled,
              onChanged: notifier.setLyricsSimulatedRichSyncEnabled,
            ),
            if (WideLayout.isWide(context))
              AppSettingsSwitch(
                icon: AppIcons.queue,
                searchId: 'lyrics.desktop_sidebar',
                title: l10n.lyricsDesktopSidebarTitle,
                subtitle: l10n.lyricsDesktopSidebarSubtitle,
                value: settings.desktopSidebarEnabled,
                onChanged: notifier.setDesktopSidebarEnabled,
              ),
            // Screen-wakelock is a phone concern; desktops manage sleep
            // at the OS level.
            if (!WideLayout.isWide(context))
              AppSettingsSwitch(
                icon: AppIcons.screenLock,
                searchId: 'lyrics.keep_screen_awake',
                title: l10n.lyricsKeepScreenAwakeTitle,
                subtitle: l10n.lyricsKeepScreenAwakeSubtitle,
                value: settings.keepScreenAwakeOnLyrics,
                onChanged: notifier.setKeepScreenAwakeOnLyrics,
              ),
          ],
        ),
        AppSettingsGroup(
          label: l10n.lyricsGroupTranslation,
          icon: AppIcons.translate,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.translate,
              searchId: 'lyrics.auto_translate',
              title: l10n.lyricsAutoTranslateTitle,
              subtitle: l10n.lyricsAutoTranslateSubtitle,
              value: settings.lyricsAutoTranslate,
              onChanged: notifier.setLyricsAutoTranslate,
            ),
            AppSettingsAnchor(
              id: 'lyrics.target_lang',
              child: AppListRow(
                dense: true,
                leading: AppRowIcon(
                  icon: AppIcons.translate,
                  color: AppTokens.accentOf(context, ref),
                  size: 40,
                ),
                title: l10n.lyricsTargetLanguageTitle,
                subtitle: localizedLanguageName(
                  l10n,
                  settings.lyricsTargetLanguage,
                ),
                trailing: DropdownButton<String>(
                  value: kSupportedTranslationLanguages
                          .contains(settings.lyricsTargetLanguage)
                      ? settings.lyricsTargetLanguage
                      : 'es',
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  items: kSupportedTranslationLanguages
                      .map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: Text(localizedLanguageName(l10n, code)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) notifier.setLyricsTargetLanguage(val);
                  },
                ),
              ),
            ),
            AppSettingsAnchor(
              id: 'lyrics.translation_mode',
              child: AppListRow(
                dense: true,
                leading: AppRowIcon(
                  icon: AppIcons.subtitles,
                  color: AppTokens.accentOf(context, ref),
                  size: 40,
                ),
                title: l10n.lyricsTranslationDisplayTitle,
                subtitle: settings.lyricsTranslationMode == 'replace'
                    ? l10n.lyricsTranslationModeReplaceSubtitle
                    : l10n.lyricsTranslationModeSubtextSubtitle,
                trailing: DropdownButton<String>(
                  value: settings.lyricsTranslationMode,
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  items: [
                    DropdownMenuItem(
                      value: 'subtext',
                      child: Text(l10n.lyricsModeSubtext),
                    ),
                    DropdownMenuItem(
                      value: 'replace',
                      child: Text(l10n.lyricsModeReplace),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setLyricsTranslationMode(val);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
    if (widget.embedded) return content;
    return AmbientScaffold(
      appBar: AppTopBar(title: l10n.settingsPageLyricsTitle),
      body: content,
    );
  }
}
