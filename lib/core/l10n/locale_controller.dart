import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's manual language override (SharedPreferences key
/// `app_locale`, per D-10).
///
/// State semantics: `null` = follow the system locale. MaterialApp (wired in
/// plan 01-06) resolves a system locale of uk/en against
/// `supportedLocales: [en, uk]` (en first), so any other system language
/// falls back to English.
class LocaleController extends Notifier<Locale?> {
  static const _prefsKey = 'app_locale';

  /// Language codes the app ships translations for.
  static const supportedLanguageCodes = {'en', 'uk'};

  @override
  Locale? build() {
    _load();
    return null; // null = follow system until the async load settles
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    // Stored value is untrusted local input (threat T-01-07): SharedPreferences
    // can be edited outside the app (rooted device, backup edit). Only
    // supported language codes are accepted; anything else means follow
    // system — never crash locale resolution on bad storage.
    if (code != null && supportedLanguageCodes.contains(code)) {
      state = Locale(code);
    }
  }

  /// Sets the manual override. `null` clears the override (follow system).
  Future<void> setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
    state = locale;
  }
}

/// App-lifetime state — intentionally NOT autoDispose. The phase-wide
/// Riverpod dispose policy is documented in the core providers file (D-23).
final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
