import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const _kLocaleKey = 'app_locale';

// Every locale the build ships, straight from the generated list, so adding a
// language or a regional variant is one new app_<tag>.arb file with its own
// languageNativeName. Sorted by tag to put a base language before its variants
// whatever order the generator emitted.
final List<Locale> selectableLocales = [
  ...AppLocalizations.supportedLocales,
]..sort((a, b) => a.toLanguageTag().compareTo(b.toLanguageTag()));

// Each locale names itself, so the picker stays readable in any language.
String languageDisplayName(Locale locale) =>
    lookupAppLocalizations(locale).languageNativeName;

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
    final tag = (await SharedPreferences.getInstance()).getString(_kLocaleKey);
    if (tag == null) return;
    // Tags saved by older builds may name a region this build no longer ships
    // (pt-BR before Portuguese split in two), so fall back to the language.
    final languageCode = tag.split('-').first;
    final supported = AppLocalizations.supportedLocales;
    final match =
        supported.where((l) => l.toLanguageTag() == tag).firstOrNull ??
            supported.where((l) => l.languageCode == languageCode).firstOrNull;
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
