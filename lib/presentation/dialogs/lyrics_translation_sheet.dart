import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/settings_provider.dart';
import '../components/app_icon.dart';
import '../components/app_sheet.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';

class LyricsTranslationConfig {
  final String targetLanguage;
  final String displayMode;
  final bool autoTranslate;
  final bool translateNow;
  final bool clearCache;

  const LyricsTranslationConfig({
    required this.targetLanguage,
    required this.displayMode,
    required this.autoTranslate,
    this.translateNow = false,
    this.clearCache = false,
  });
}

const List<String> kSupportedTranslationLanguages = [
  'es',
  'en',
  'fr',
  'de',
  'it',
  'ja',
  'zh',
  'ko',
  'pt',
  'ru',
  'hi',
  'ar',
  'nl',
  'pl',
  'tr',
  'vi',
  'uk',
  'sv',
  'id',
  'th',
  'cs',
  'el',
  'hu',
  'ro',
  'da',
  'fi',
  'no',
];

String localizedLanguageName(AppLocalizations l10n, String code) =>
    switch (code) {
      'es' => l10n.languageSpanish,
      'en' => l10n.languageEnglish,
      'fr' => l10n.languageFrench,
      'de' => l10n.languageGerman,
      'it' => l10n.languageItalian,
      'ja' => l10n.languageJapanese,
      'zh' => l10n.languageChinese,
      'ko' => l10n.languageKorean,
      'pt' => l10n.languagePortuguese,
      'ru' => l10n.languageRussian,
      'hi' => l10n.languageHindi,
      'ar' => l10n.languageArabic,
      'nl' => l10n.languageDutch,
      'pl' => l10n.languagePolish,
      'tr' => l10n.languageTurkish,
      'vi' => l10n.languageVietnamese,
      'uk' => l10n.languageUkrainian,
      'sv' => l10n.languageSwedish,
      'id' => l10n.languageIndonesian,
      'th' => l10n.languageThai,
      'cs' => l10n.languageCzech,
      'el' => l10n.languageGreek,
      'hu' => l10n.languageHungarian,
      'ro' => l10n.languageRomanian,
      'da' => l10n.languageDanish,
      'fi' => l10n.languageFinnish,
      'no' => l10n.languageNorwegian,
      _ => code.toUpperCase(),
    };

Future<LyricsTranslationConfig?> showLyricsTranslationSheet(
  BuildContext context, {
  required String currentSongTitle,
  required bool hasCachedTranslation,
}) {
  return showAppSheet<LyricsTranslationConfig>(
    context,
    title: context.l10n.lyricsTranslateTitle,
    builder: (context) => _LyricsTranslationSheet(
      hasCachedTranslation: hasCachedTranslation,
    ),
  );
}

class _LyricsTranslationSheet extends ConsumerStatefulWidget {
  final bool hasCachedTranslation;

  const _LyricsTranslationSheet({
    required this.hasCachedTranslation,
  });

  @override
  ConsumerState<_LyricsTranslationSheet> createState() =>
      _LyricsTranslationSheetState();
}

class _LyricsTranslationSheetState
    extends ConsumerState<_LyricsTranslationSheet> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedLanguage;
  late String _displayMode;
  late bool _autoTranslate;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _selectedLanguage = settings.lyricsTargetLanguage;
    _displayMode = settings.lyricsTranslationMode;
    _autoTranslate = settings.lyricsAutoTranslate;

    _searchController.addListener(() {
      setState(() {
        _filterQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _saveAndClose({bool translateNow = true, bool clearCache = false}) {
    if (!mounted) return;
    final notifier = ref.read(settingsProvider.notifier);
    notifier.setLyricsTargetLanguage(_selectedLanguage);
    notifier.setLyricsTranslationMode(_displayMode);
    notifier.setLyricsAutoTranslate(_autoTranslate);

    Navigator.of(context).pop(
      LyricsTranslationConfig(
        targetLanguage: _selectedLanguage,
        displayMode: _displayMode,
        autoTranslate: _autoTranslate,
        translateNow: translateNow,
        clearCache: clearCache,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filteredLangs = kSupportedTranslationLanguages.where((code) {
      if (_filterQuery.isEmpty) return true;
      return localizedLanguageName(l10n, code)
              .toLowerCase()
              .contains(_filterQuery) ||
          code.toLowerCase().contains(_filterQuery);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppTokens.s4,
        right: AppTokens.s4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTokens.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Display Mode Selector
          Text(
            l10n.lyricsDisplayMode,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppTokens.s2),
          Row(
            children: [
              Expanded(
                child: _buildModeTile(
                  title: l10n.lyricsModeSubtext,
                  subtitle: l10n.lyricsModeSubtextDescription,
                  value: 'subtext',
                  icon: AppIcons.subtitles,
                ),
              ),
              const SizedBox(width: AppTokens.s3),
              Expanded(
                child: _buildModeTile(
                  title: l10n.lyricsModeReplace,
                  subtitle: l10n.lyricsModeReplaceDescription,
                  value: 'replace',
                  icon: AppIcons.swapHoriz,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s4),

          // Auto-translate toggle
          SwitchListTile(
            value: _autoTranslate,
            onChanged: (val) {
              setState(() {
                _autoTranslate = val;
              });
            },
            title: Text(
              l10n.lyricsAutoTranslateAllTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              l10n.lyricsAutoTranslateAllSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppTokens.s3),

          // Target Language Picker Section
          Text(
            l10n.lyricsTargetLanguageLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppTokens.s2),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.lyricsSearchLanguageHint,
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12.0),
                child: AppIcon(AppIcons.search, size: 20),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s3,
                vertical: AppTokens.s2,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.s2),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // Material carries both the fill and the ink canvas, so the
              // language ListTiles below paint their splashes on top of it
              // instead of under a ColoredBox.
              child: Material(
                color: Colors.white.withValues(alpha: 0.04),
                child: ListView.builder(
                  itemCount: filteredLangs.length,
                  itemBuilder: (context, index) {
                    final code = filteredLangs[index];
                    final isSelected = code == _selectedLanguage;

                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      title: Text(
                        localizedLanguageName(l10n, code),
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      subtitle: Text(
                        code.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: isSelected
                          ? AppIcon(
                              AppIcons.checkCircle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedLanguage = code;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.s4),

          // Action Buttons
          Row(
            children: [
              if (widget.hasCachedTranslation) ...[
                OutlinedButton.icon(
                  onPressed: () =>
                      _saveAndClose(translateNow: false, clearCache: true),
                  icon: const AppIcon(AppIcons.delete, size: 18),
                  label: Text(l10n.lyricsClearCache),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide.none,
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(width: AppTokens.s3),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _saveAndClose(translateNow: true),
                  icon: const AppIcon(AppIcons.translate, size: 18),
                  label: Text(l10n.lyricsTranslateNow),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s4),
        ],
      ),
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required String value,
    required AppIconData icon,
  }) {
    final isSelected = _displayMode == value;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        setState(() {
          _displayMode = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppTokens.s3),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? primary
                      : Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppTokens.s2),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
