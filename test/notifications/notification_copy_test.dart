/// The text the operating system will render, and the locale it is built in
/// (07-UI-SPEC § 2, DECIDED-1..6, DECIDED-15; § Typography's two budgets).
///
/// Everything here is the phase's actual user-visible surface, and none of it
/// is drawn by a widget — so the usual gates (text scaler, directional padding,
/// a fixed-width container) do not apply and a LENGTH BUDGET replaces them: the
/// operating system truncates where a widget would have wrapped.
///
/// Two things this file deliberately asserts differently from
/// `notification_channel_payload_test.dart`, which already pins the same seven
/// Ukrainian plural fixtures against the ARB:
///
/// 1. The subject here is the COPY LAYER, not the ARB. The string asserted is
///    the one the copy layer hands to the platform, so it also pins the time
///    fragment, its position and the fact that the two are composed inside one
///    ARB value rather than concatenated in Dart.
/// 2. The budgets iterate the GENERATED locale list rather than an enumerated
///    pair, so a language added later is covered without anyone remembering
///    this file.
library;

import 'dart:io';

import 'package:boostque/core/l10n/gen/app_localizations.dart';
import 'package:boostque/core/notifications/notification_copy.dart';
import 'package:boostque/core/notifications/notification_locale.dart';
import 'package:boostque/core/notifications/notification_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'recording_scheduler.dart';

void main() {
  // Without this the locale's own formatting symbols are never loaded and the
  // formatter silently falls back to the default locale — every locale-specific
  // assertion below would then be testing English while claiming otherwise.
  // The month-name test carries the same set-up for the same reason.
  setUpAll(() async {
    for (final locale in AppLocalizations.supportedLocales) {
      await initializeDateFormatting(locale.toString());
    }
  });

  const uk = Locale('uk');
  const en = Locale('en');
  const eightAm = 480;

  group('the body, pinned character for character', () {
    // Exact equality, never a `contains` or a shape check. The whole point of
    // this fixture set is that ELEVEN takes the genitive plural through the
    // 11-14 exception while TWENTY-ONE takes the nominative singular; only
    // exact equality catches a form that is right for the wrong reason.
    test('Ukrainian at every boundary the CLDR rules distinguish', () {
      String body(int count) =>
          notificationBody(locale: uk, doseCount: count, minutesFromMidnight: eightAm);

      expect(body(1), '08:00 · 1 прийом'); // one
      expect(body(2), '08:00 · 2 прийоми'); // few
      expect(body(5), '08:00 · 5 прийомів'); // many
      expect(body(11), '08:00 · 11 прийомів'); // many — the 11-14 exception
      expect(body(21), '08:00 · 21 прийом'); // one — i%10=1, i%100!=11
      expect(body(22), '08:00 · 22 прийоми'); // few
      expect(body(25), '08:00 · 25 прийомів'); // many
    });

    test('English at one and at two', () {
      expect(
        notificationBody(locale: en, doseCount: 1, minutesFromMidnight: eightAm),
        '08:00 · 1 dose',
      );
      expect(
        notificationBody(locale: en, doseCount: 2, minutesFromMidnight: eightAm),
        '08:00 · 2 doses',
      );
    });

    test('the time fragment is the body\'s own, at whatever minute it is asked '
        'for', () {
      expect(
        notificationBody(locale: uk, doseCount: 1, minutesFromMidnight: 1290),
        '21:30 · 1 прийом',
      );
    });
  });

  group('the title', () {
    test('carries no digit, no time, and not the app\'s own name, in every '
        'shipped locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final title = notificationTitle(locale);
        final copy = lookupAppLocalizations(locale);
        expect(
          title,
          isNot(matches(RegExp(r'[0-9]'))),
          reason: '$locale: a title that changes on every delivery loses the '
              'one thing a title is for — instant, pre-reading recognition. '
              'The count and the time both live in the body (DECIDED-1).',
        );
        expect(
          title.contains(':'),
          isFalse,
          reason: '$locale: the time belongs in the body.',
        );
        expect(
          title.contains(copy.appTitle),
          isFalse,
          reason: '$locale: both platforms already print the app name in '
              'chrome the app does not control, so a title repeating it spends '
              'the most valuable line restating a free fact.',
        );
      }
    });

    test('is the constant the contract fixes, in both languages today', () {
      expect(notificationTitle(uk), 'Час прийому');
      expect(notificationTitle(en), 'Time for your doses');
    });
  });

  group('the length budgets, over the generated locale list', () {
    // Derived from AppLocalizations.supportedLocales rather than an enumerated
    // pair, so a language file added later is covered the day it lands.
    test('the title fits 24 characters in every shipped locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final title = notificationTitle(locale);
        expect(
          title.length,
          lessThanOrEqualTo(24),
          reason: '$locale: "$title" is ${title.length} characters. The '
              'operating system TRUNCATES rather than wraps, and iOS truncates '
              'the title more aggressively than the body — an over-budget '
              'title is cut mid-word on a lock screen at a large system text '
              'size.',
        );
      }
    });

    test('the body at a count of 999 fits 32 characters in every shipped '
        'locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final body = notificationBody(
          locale: locale,
          doseCount: 999,
          minutesFromMidnight: eightAm,
        );
        expect(
          body.length,
          lessThanOrEqualTo(32),
          reason: '$locale: "$body" is ${body.length} characters. The '
              'operating system truncates rather than wraps, so an over-budget '
              'body loses its COUNT on a lock screen at a large system text '
              'size — and a truncated count is worse than no count at all.',
        );
      }
    });
  });

  group('the single time formatter', () {
    test('is 24-hour and zero-padded at midnight, in the morning and at the '
        'last minute of the day', () {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(formatReminderTime(locale: locale, minutesFromMidnight: 0),
            '00:00', reason: '$locale');
        expect(formatReminderTime(locale: locale, minutesFromMidnight: 540),
            '09:00', reason: '$locale');
        expect(formatReminderTime(locale: locale, minutesFromMidnight: 1439),
            '23:59', reason: '$locale');
      }
    });
  });

  group('the channel copy', () {
    test('comes back from the same locale as the title and the body', () {
      expect(notificationChannelName(uk), 'Нагадування про прийом');
      expect(notificationChannelDescription(uk),
          'Одне нагадування на кожен час прийому у вашому розкладі.');
      expect(notificationChannelName(en), 'Dose reminders');
      expect(notificationChannelDescription(en),
          'One reminder for each dose time in your schedule.');
    });
  });

  group('the resolved locale — observed, never re-derived', () {
    test('starts null, and a null resolved locale means no text is ever built',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(notificationLocaleProvider, (_, _) {});
      addTearDown(sub.close);

      expect(
        container.read(notificationLocaleProvider),
        isNull,
        reason: 'a tree that is not the real app observes nothing, so nothing '
            'is scheduled — which is the right behaviour, not a gap.',
      );
    });

    testWidgets('reports the locale the interface is actually rendering in, and '
        'the new one after a language change', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(notificationLocaleProvider, (_, _) {});
      addTearDown(sub.close);

      Future<void> pumpIn(Locale locale) => tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: const NotificationLocaleObserver(
                  child: SizedBox.shrink(),
                ),
              ),
            ),
          );

      await pumpIn(uk);
      await tester.pumpAndSettle();
      expect(container.read(notificationLocaleProvider), uk);

      await pumpIn(en);
      await tester.pumpAndSettle();
      expect(
        container.read(notificationLocaleProvider),
        en,
        reason: 'a scheduled notification carries text frozen at scheduling '
            'time, so a language change that never reaches this provider '
            'leaves the old language armed for the whole horizon (DECIDED-16).',
      );
    });

    testWidgets('the observer renders its child and nothing else',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: uk,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const NotificationLocaleObserver(child: Text('child')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('child'), findsOneWidget);
    });
  });

  group('the channel follows the observed locale', () {
    ProviderContainer bootstrapped(RecordingScheduler scheduler) {
      final container = ProviderContainer(
        overrides: [
          notificationSchedulerProvider.overrideWithValue(scheduler),
          timeZoneLoaderProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(notificationBootstrapProvider, (_, _) {});
      addTearDown(sub.close);
      return container;
    }

    testWidgets('a resolved locale drives the bootstrap, and a language change '
        'rewrites the channel copy in place', (tester) async {
      final scheduler = RecordingScheduler();
      final container = bootstrapped(scheduler);

      container.read(notificationLocaleProvider.notifier).report(uk);
      await tester.pumpAndSettle();

      expect(
        scheduler.calls.map((c) => c.method).toList(),
        <String>[initializeCall, ensureChannelCall],
      );
      expect(scheduler.calls.last.name, notificationChannelName(uk));
      expect(
        scheduler.calls.last.description,
        notificationChannelDescription(uk),
      );

      container.read(notificationLocaleProvider.notifier).report(en);
      await tester.pumpAndSettle();

      expect(
        scheduler.calls.map((c) => c.method).toList(),
        <String>[initializeCall, ensureChannelCall, ensureChannelCall],
        reason: 'the platform UPDATES an existing channel\'s name and '
            'description, so a language change is a rewrite in place. The id is '
            'never re-versioned to relocalize: that would create a second '
            'channel in the operating system\'s settings list and orphan '
            'whatever the user customized on the first (DECIDED-14).',
      );
      expect(scheduler.calls.last.name, notificationChannelName(en));
      expect(
        scheduler.calls.last.description,
        notificationChannelDescription(en),
      );
    });

    testWidgets('nothing is bootstrapped while no locale has been observed',
        (tester) async {
      final scheduler = RecordingScheduler();
      bootstrapped(scheduler);
      await tester.pumpAndSettle();

      expect(
        scheduler.calls,
        isEmpty,
        reason: 'a bare container observes no locale, so there is no language '
            'to write the channel copy in and nothing at all is done.',
      );
    });
  });

  group('the root app widget mounts the observer', () {
    // A source gate rather than a pump: the property is that the ONE
    // observation point lives inside the localizations it observes, and that
    // the app does not re-derive a locale beside it.
    test('lib/main.dart wraps the tree in the observer and re-derives nothing',
        () {
      final source = File('lib/main.dart').readAsStringSync();
      final stripped = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        stripped.contains('NotificationLocaleObserver('),
        isTrue,
        reason: 'the notification text must be built in the locale the '
            'interface is actually rendering in, and the only way to know that '
            'is to observe it from the tree (DECIDED-15).',
      );
      expect(
        stripped.contains('basicLocaleListResolution'),
        isFalse,
        reason: 're-deriving the resolved locale would be a second copy of a '
            'resolution rule whose correctness depends on nobody ever adding a '
            'resolution callback — the PF-1 defect shape.',
      );
    });
  });
}
