import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/providers.dart';

/// Persists the user's manual language override (SharedPreferences key
/// `app_locale`, per D-10).
///
/// State semantics: `null` = follow the system locale. MaterialApp resolves a
/// system locale against `AppLocalizations.supportedLocales`, whose order —
/// and therefore whose fallback — is DECLARED by `preferred-supported-locales`
/// in `l10n.yaml`, so any unsupported system language falls back to English
/// (L10N-02, PF-1).
class LocaleController extends Notifier<Locale?> {
  static const _prefsKey = 'app_locale';

  /// Language codes the app ships translations for — DERIVED from the ARB
  /// files via the generated list, never enumerated here. Adding
  /// `app_pl.arb` regenerates `supportedLocales` and this set follows with no
  /// edit in this file (L10N-04, criterion 4).
  static final Set<String> supportedLanguageCodes = {
    for (final locale in AppLocalizations.supportedLocales) locale.languageCode,
  };

  @override
  Locale? build() {
    // Synchronous seed: the stored override is applied on frame 1, so a user
    // who set one never sees a system-language frame first (P-4 Option A).
    //
    // `get` (Object?), never `getString`: `getString` is an unguarded
    // `as String?` downcast (shared_preferences 2.5.x), so a non-String value
    // under this key throws a TypeError HERE — inside the build that
    // `BoostqueApp` watches, which parks the provider in a permanent error
    // state and bricks the launch across restarts. The type of untrusted
    // storage is as untrusted as its content, so both are checked (CR-01).
    final stored = ref.watch(sharedPreferencesProvider).get(_prefsKey);
    final code = stored is String ? stored : null;
    // Stored value is untrusted local input (threat T-01-07): SharedPreferences
    // can be edited outside the app (rooted device, backup edit). Only
    // supported language codes are accepted; anything else means follow
    // system — never crash locale resolution on bad storage. Because the
    // allowlist follows the ARB files, a code whose ARB was removed in a later
    // build degrades to "follow system" rather than reaching the generated
    // `lookupAppLocalizations` throw, which would be an unrecoverable launch
    // crash (T-05-01, T-05-02). Do not weaken this to a passthrough.
    return (code != null && supportedLanguageCodes.contains(code))
        ? Locale(code)
        : null;
  }

  /// Sets the manual override. `null` clears the override (follow system).
  Future<void> setLocale(Locale? locale) async {
    // State FIRST, disk after: persisting first would put a platform-channel
    // round-trip and a disk write in front of the repaint, which makes
    // criterion 3's "applies instantly" a lie (PF-3). The in-memory state is
    // the truth for the session; a failed write costs the NEXT launch only,
    // and is deliberately not surfaced (DECIDED-8).
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }
}

/// App-lifetime state — intentionally NOT autoDispose. The phase-wide
/// Riverpod dispose policy is documented in the core providers file (D-23).
final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
