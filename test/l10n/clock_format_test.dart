/// The clock-shape gate.
///
/// Every time the app displays is zero-padded 24-hour, in every shipped
/// language. This is the test that made that true: Spanish landed with the
/// CLDR pattern `H:mm`, so `08:00` rendered as `8:00` on the Today screen, in
/// the dose sheet, in the regimen editor and in the notification body, while
/// every neighbouring time kept its zero.
///
/// It loops over `supportedLocales` rather than a hand-written list, so a
/// language added later cannot slip in with a different clock shape.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:boostque/core/l10n/clock_format.dart';
import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/notifications/notification_copy.dart';

void main() {
  // `DateFormat` with an explicit locale needs that locale's symbols loaded.
  // In the app `flutter_localizations` does this when it loads a locale; in a
  // pure unit test nothing has, so the data is initialized here — the same
  // thing `notification_copy_test.dart` does for the same reason.
  setUpAll(() async {
    for (final locale in AppLocalizations.supportedLocales) {
      await initializeDateFormatting(locale.toString());
    }
  });

  /// Midnight, a single-digit morning hour, and the last minute of the day —
  /// the three places a padding or wrap bug shows up.
  const cases = <int, String>{0: '00:00', 480: '08:00', 1439: '23:59'};

  group('formatClockIn', () {
    for (final locale in AppLocalizations.supportedLocales) {
      test('${locale.languageCode} is zero-padded 24-hour', () {
        cases.forEach((minutes, expected) {
          expect(
            formatClockIn(locale, minutes),
            expected,
            reason: '$locale printed a time that does not match the shape '
                'every other locale prints. A ragged column of times is the '
                'visible symptom; the cause is asking CLDR for the locale\'s '
                'idea of 24-hour time instead of pinning the pattern.',
          );
        });
      });
    }
  });

  test('the notification body uses the same shape as the screen', () {
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        notificationBody(
          locale: locale,
          doseCount: 1,
          minutesFromMidnight: 480,
        ),
        contains(formatClockIn(locale, 480)),
        reason: '$locale: the lock screen and the app must print the same '
            'time for the same dose. Two formatters is two chances to '
            'disagree, and the user cannot compare them side by side.',
      );
    }
  });
}
