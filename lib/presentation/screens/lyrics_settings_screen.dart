import 'package:flutter/material.dart';
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

    final content = AppSettingsList(
      highlightId: widget.highlightId,
      children: [
        AppSettingsGroup(
          label: 'Display & Timing',
          icon: AppIcons.subtitles,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.autoAwesome,
              searchId: 'lyrics.rich_sync',
              title: 'Simulate Word Sync',
              subtitle:
                  'Generate word-level timing from line-synced lyrics using prosodic estimation',
              value: settings.lyricsSimulatedRichSyncEnabled,
              onChanged: notifier.setLyricsSimulatedRichSyncEnabled,
            ),
            if (WideLayout.isWide(context))
              AppSettingsSwitch(
                icon: AppIcons.queue,
                searchId: 'lyrics.desktop_sidebar',
                title: 'Lyrics & Queue Sidebar',
                subtitle:
                    'Show the hover expand handle to reopen the lyrics and queue sidebar once hidden',
                value: settings.desktopSidebarEnabled,
                onChanged: notifier.setDesktopSidebarEnabled,
              ),
            // Screen-wakelock is a phone concern; desktops manage sleep
            // at the OS level.
            if (!WideLayout.isWide(context))
              AppSettingsSwitch(
                icon: AppIcons.screenLock,
                searchId: 'lyrics.keep_screen_awake',
                title: 'Keep Screen Awake on Lyrics',
                subtitle: 'Prevent sleep while the lyrics pane is open',
                value: settings.keepScreenAwakeOnLyrics,
                onChanged: notifier.setKeepScreenAwakeOnLyrics,
              ),
          ],
        ),
        AppSettingsGroup(
          label: 'Translation',
          icon: AppIcons.translate,
          children: [
            AppSettingsSwitch(
              icon: AppIcons.translate,
              searchId: 'lyrics.auto_translate',
              title: 'Auto-Translate Lyrics',
              subtitle:
                  'Automatically translate lyrics using selected target language',
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
                title: 'Target Language',
                subtitle: kSupportedTranslationLanguages[
                        settings.lyricsTargetLanguage] ??
                    settings.lyricsTargetLanguage.toUpperCase(),
                trailing: DropdownButton<String>(
                  value: kSupportedTranslationLanguages
                          .containsKey(settings.lyricsTargetLanguage)
                      ? settings.lyricsTargetLanguage
                      : 'es',
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  items: kSupportedTranslationLanguages.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
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
                title: 'Translation Display',
                subtitle: settings.lyricsTranslationMode == 'replace'
                    ? 'Replace base lyrics'
                    : 'Show subtext below lyrics',
                trailing: DropdownButton<String>(
                  value: settings.lyricsTranslationMode,
                  underline: const SizedBox.shrink(),
                  borderRadius: AppTokens.brMd,
                  items: const [
                    DropdownMenuItem(
                      value: 'subtext',
                      child: Text('Subtext below'),
                    ),
                    DropdownMenuItem(
                      value: 'replace',
                      child: Text('Replace base'),
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
      appBar: const AppTopBar(title: 'Lyrics'),
      body: content,
    );
  }
}
