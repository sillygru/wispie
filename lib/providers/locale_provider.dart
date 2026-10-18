import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const _kLocaleKey = 'app_locale';

// Native names
const Map<String, String> _languageNames = {
  'en': 'English',
  'pt': 'Português',
};

String languageDisplayName(Locale locale) =>
    _languageNames[locale.toLanguageTag()] ?? locale.toLanguageTag();

final List<Locale> selectableLocales = AppLocalizations.supportedLocales
    .where((l) => _languageNames.containsKey(l.toLanguageTag()))
    .toList();

// Null follows the device language.
final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    var tag = (await SharedPreferences.getInstance()).getString(_kLocaleKey);
    if (tag == null) return;
    // Saved preferences from when Portuguese had regional variants.
    if (tag.startsWith('pt-')) tag = 'pt';
    final match = AppLocalizations.supportedLocales
        .where((l) => l.toLanguageTag() == tag)
        .firstOrNull;
    if (match != null && match != state) state = match;
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_kLocaleKey);
    } else {
      await prefs.setString(_kLocaleKey, locale.toLanguageTag());
    }
  }
}
