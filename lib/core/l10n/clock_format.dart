/// The app's one on-screen clock format.
///
/// Every time this app displays is zero-padded 24-hour, in every language.
/// That is a design rule, not a locale preference, and it is why the three
/// display sites used to call
/// `MaterialLocalizations.formatTimeOfDay(..., alwaysUse24HourFormat: true)`.
///
/// That call is not enough. `alwaysUse24HourFormat` only chooses between the
/// 12- and 24-hour pattern that CLDR holds for the locale; it does not make
/// those patterns agree with each other. CLDR gives en, uk, fr, ar, hi and zh
/// the pattern `HH:mm`, and Spanish the pattern `H:mm` — so with Spanish
/// shipping, an 08:00 dose printed as `8:00` on the Today screen, in the dose
/// sheet and in the regimen editor, while every neighbouring time in the same
/// column still had its zero. The notification body had the identical defect
/// from `DateFormat.Hm` and is fixed the same way, in
/// `core/notifications/notification_copy.dart`.
///
/// So the pattern is pinned here rather than asked for. Locale still matters
/// and is still passed: a language whose default numbering system is not
/// Latin renders its own digits through this same call, which is correct —
/// what is fixed is the SHAPE, not the script.
///
/// One function, one rule, one place to change it. `clock_format_test.dart`
/// asserts the shape holds in every shipped locale, so adding a language
/// whose CLDR pattern disagrees fails a test instead of shipping a ragged
/// column.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formats [minutesFromMidnight] as zero-padded 24-hour time in the locale
/// [context] is currently rendering in.
String formatClock(BuildContext context, int minutesFromMidnight) =>
    formatClockIn(
      Localizations.localeOf(context),
      minutesFromMidnight,
    );

/// The locale-explicit form, for call sites that hold a [Locale] rather than a
/// [BuildContext].
///
/// The date is a fixed placeholder: only the time fields are read, and using a
/// UTC instant keeps this free of any DST edge, exactly as the date-only rule
/// does elsewhere in the app.
String formatClockIn(Locale locale, int minutesFromMidnight) =>
    DateFormat('HH:mm', locale.toString()).format(
      DateTime.utc(
        2000,
        1,
        1,
        minutesFromMidnight ~/ 60,
        minutesFromMidnight % 60,
      ),
    );
