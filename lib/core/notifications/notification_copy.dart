/// The text the operating system renders — and the one place the app's 24-hour
/// rule lives outside a widget (07-UI-SPEC § 2, DECIDED-1..6).
///
/// **This file cannot learn a supplement name, and must never be able to.** It
/// takes a dose COUNT and a MINUTE of day; there is no parameter, no import and
/// no provider here through which a name could arrive. That is a security
/// control and not a style preference: these strings sit on a lock screen, and
/// iOS exposes no redaction placeholder through this plugin, which makes the
/// text itself the only privacy control available on that platform. A
/// capability that does not exist cannot leak.
///
/// The text is reached through the generated top-level SYNCHRONOUS lookup, never
/// through a build context — the scheduler has none and must not be given one
/// (07-RESEARCH § 8.5). Everything here is a pure function of a locale and two
/// numbers, so all of it is testable without pumping a widget.
library;

import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

import 'package:boostque/core/l10n/gen/app_localizations.dart';

/// The reminder's title in [locale].
///
/// Constant within a locale: it takes no count and no time, so "the title is
/// the same on every delivery" is structural rather than a claim a test has to
/// re-check. It carries no app name either — both platforms already print that
/// in chrome the app does not control.
String notificationTitle(Locale locale) =>
    lookupAppLocalizations(locale).doseReminderTitle;

/// The reminder's body in [locale]: the scheduled time, then how many doses are
/// due at it.
///
/// [doseCount] counts DOSES due at that one time of day — never supplements in
/// the stack, never doses left in the day. It is never zero: the pure plan emits
/// nothing at all for a time with no active doses, so there is no zero-state
/// copy and there must not be one.
///
/// The two fragments are composed inside ONE localized value, so an RTL or
/// verb-final locale can reorder them without a code change. Nothing here
/// concatenates localized pieces.
String notificationBody({
  required Locale locale,
  required int doseCount,
  required int minutesFromMidnight,
}) =>
    lookupAppLocalizations(locale).doseReminderBody(
      doseCount,
      formatReminderTime(
        locale: locale,
        minutesFromMidnight: minutesFromMidnight,
      ),
    );

/// The Android channel's user-visible name in [locale].
///
/// Rendered by the operating system in its own settings list, so it is localized
/// like every other string the user reads.
String notificationChannelName(Locale locale) =>
    lookupAppLocalizations(locale).doseChannelName;

/// The Android channel's user-visible description in [locale].
String notificationChannelDescription(Locale locale) =>
    lookupAppLocalizations(locale).doseChannelDescription;

/// [minutesFromMidnight] as a 24-hour, zero-padded `HH:mm` fragment in [locale].
///
/// **The ONE time formatter in the app outside a build context, deliberately.**
/// Every in-app time is forced to 24-hour by the framework's own formatter with
/// `alwaysUse24HourFormat: true`; the hour-and-minute skeleton used here is
/// 24-hour by definition in every locale, so a reminder can never disagree with
/// a clock inside the app. Keeping it in one named helper puts that rule in
/// exactly one place.
///
/// This is also why the localized value takes a pre-formatted STRING rather than
/// a date with a per-locale format directive: the directive would let a future
/// translator introduce a 12-hour clock into the notification, silently, with no
/// test able to see the intent (DECIDED-5).
///
/// **Recorded alternative:** switch the placeholder to a date type with an
/// hour-and-minute format and delete this helper. Do that only if the 24-hour
/// house rule is being relaxed app-wide.
///
/// **Deviation from UI-SPEC § 7.1, decided and recorded here.** The contract
/// names a BCP-47 language tag as the locale argument. Every other formatter
/// call site in this app passes the locale's `toString()` form instead, and the
/// formatting package canonicalizes underscores rather than hyphens. For the two
/// locales shipped today the two forms are identical, so this is a latent
/// difference rather than a live bug — but a region-qualified locale would
/// diverge, and one call site disagreeing with every other is how a fallback to
/// the default locale becomes invisible.
///
/// The date the fragment is read off is a fixed UTC day, never today: only the
/// hour and the minute are rendered, and a real day would drag a daylight-saving
/// transition into a function that has nothing to do with one.
///
/// **One dependency worth naming, because it is invisible until it breaks.** The
/// formatting symbols for [locale] must already be loaded, or this throws. In
/// the app that is free and it is not a coincidence: the resolved locale is only
/// ever reported by a tree that has ALREADY loaded that locale's material
/// localizations, and loading them is exactly what initializes the symbols. It
/// stops being free if the global localizations delegate is ever removed from
/// the delegate list — and the sync's own guard would then turn every reminder
/// into a crash report rather than a crash. A bare unit test must load them
/// itself.
String formatReminderTime({
  required Locale locale,
  required int minutesFromMidnight,
}) =>
    DateFormat.Hm(locale.toString()).format(
      DateTime.utc(
        2000,
        1,
        1,
        minutesFromMidnight ~/ 60,
        minutesFromMidnight % 60,
      ),
    );
