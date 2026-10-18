import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const _kLocaleKey = 'app_locale';
const _fallback = Locale('en');

// Native names, never translated, so users can always find their language.
const Map<String, String> _languageNames = {
  'en': 'English',
};

String languageDisplayName(Locale locale) =>
    _languageNames[locale.languageCode] ?? locale.toLanguageTag();

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return _fallback;
  }

  Future<void> _load() async {
    final code = (await SharedPreferences.getInstance()).getString(_kLocaleKey);
    final match = AppLocalizations.supportedLocales
        .where((l) => l.languageCode == code)
        .firstOrNull;
    if (match != null && match != state) state = match;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await (await SharedPreferences.getInstance())
        .setString(_kLocaleKey, locale.languageCode);
  }
}
