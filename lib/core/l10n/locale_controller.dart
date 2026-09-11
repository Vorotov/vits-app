import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vitomy/core/l10n/gen/app_localizations.dart';
import 'package:vitomy/core/providers.dart';

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

  /// The shipped locales, indexed by the BCP-47 tag they are persisted as —
  /// DERIVED from the ARB files via the generated list, never enumerated here.
  /// Adding `app_pl.arb` regenerates `supportedLocales` and this map follows
  /// with no edit in this file (L10N-04, criterion 4).
  ///
  /// Keyed on the FULL locale, never on the language subtag: the ARB file
  /// pattern both gates accept admits region-qualified files, and collapsing
  /// `app_pt.arb` + `app_pt_BR.arb` to `'pt'` would silently downgrade a user
  /// who picked Brazilian Portuguese on the next launch, and check TWO rows in
  /// a picker whose whole contract is that exactly one is checked (WR-05).
  static final Map<String, Locale> _localesByTag = {
    for (final locale in AppLocalizations.supportedLocales)
      locale.toLanguageTag(): locale,
  };

  /// The tags a stored override may hold — the sanitization allowlist, and
  /// exactly what [setLocale] writes.
  static Set<String> get supportedLocaleTags => _localesByTag.keys.toSet();

  @override
  Locale? build() {
    // Synchronous seed: the stored override is applied on frame 1, so a user
    // who set one never sees a system-language frame first (P-4 Option A).
    //
    // `get` (Object?), never `getString`: `getString` is an unguarded
    // `as String?` downcast (shared_preferences 2.5.x), so a non-String value
    // under this key throws a TypeError HERE — inside the build that
    // `VitomyApp` watches, which parks the provider in a permanent error
    // state and bricks the launch across restarts. The type of untrusted
    // storage is as untrusted as its content, so both are checked (CR-01).
    //
    // A `null` store is a store that could not be opened at all (CR-02): there
    // is no override to read, which is the same state an empty store leaves —
    // follow the system.
    final stored = ref.watch(sharedPreferencesProvider)?.get(_prefsKey);
    final tag = stored is String ? stored : null;
    // Stored value is untrusted local input (threat T-01-07): SharedPreferences
    // can be edited outside the app (rooted device, backup edit). Only tags
    // that name a SHIPPED locale are accepted; anything else means follow
    // system — never crash locale resolution on bad storage. Because the map
    // follows the ARB files, a tag whose ARB was removed in a later build
    // degrades to "follow system" rather than reaching the generated
    // `lookupAppLocalizations` throw, which would be an unrecoverable launch
    // crash (T-05-01, T-05-02). Do not weaken this to a passthrough.
    //
    // The value returned is the generated locale ITSELF, so the state can
    // never be a locale the app does not ship, and comparisons against
    // `supportedLocales` (the picker's checked row) hold by identity.
    return tag == null ? null : _localesByTag[tag];
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
    // No store to write to (it could not be opened on this launch, CR-02): the
    // language still applies for the whole session and only the NEXT launch
    // cannot remember it — the exact cost DECIDED-8 already accepts for a
    // write that fails.
    if (prefs == null) return;
    // DECIDED-8's "deliberately not surfaced" means SWALLOWED HERE, not left
    // to the zone. The call site fires this future and forgets it, so an
    // escaping `PlatformException` (a full or read-only store, a channel
    // failure) would become an unhandled root-zone error: printed in release,
    // an outright failure in any test that happens to be pumping — the exact
    // opposite of silent (WR-04). `setString`/`remove` also answer `false` for
    // a rejected write, which has the same consequence as a throw and is
    // therefore reported the same way.
    try {
      final persisted = locale == null
          ? await prefs.remove(_prefsKey)
          // The FULL tag, never `languageCode`: persisting the subtag alone
          // would restore `pt` for a user who chose `pt-BR` (WR-05).
          : await prefs.setString(_prefsKey, locale.toLanguageTag());
      if (!persisted) {
        throw StateError('the language store rejected the write');
      }
    } catch (error, stack) {
      // Reported for the crash logger, never to the user: the language
      // visibly DID take effect, so an error banner about it would be more
      // confusing than the silent, self-correcting behaviour (DECIDED-8). The
      // cost is one launch of amnesia.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'vitomy',
          context: ErrorDescription('persisting the language override'),
        ),
      );
    }
  }
}

/// App-lifetime state — intentionally NOT autoDispose. The phase-wide
/// Riverpod dispose policy is documented in the core providers file (D-23).
final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
