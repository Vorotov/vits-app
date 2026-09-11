/// The two properties of this phase worth proving by DRIVING the code rather
/// than by reading it: that no supplement name can reach a scheduled
/// notification, and that no stack size can breach the platform's pending
/// ceiling.
///
/// ## Why this file exists next to a source gate that already proves the same
/// thing structurally
///
/// `notification_channel_payload_test.dart` asserts that neither the pure plan
/// nor the platform adapter can reach `SupplementRepository`,
/// `stackEntriesProvider` or `supplementsStreamProvider`, and
/// `notification_copy.dart`'s own gate says the same of the copy layer. Those
/// gates prove a CAPABILITY is absent **today**. This file proves the PROPERTY
/// that capability protects, and it is the one that survives a future refactor
/// in which some innocuous-looking helper — a join, a debug label, a "richer"
/// reconcile key — starts carrying a name through a layer that is allowed to
/// see one.
///
/// So the container these tests build deliberately HAS the names in it: the
/// supplements stream is seeded with distinctively-named supplements, and the
/// regimens point at them by id. Everything the leak would need is present and
/// reachable; the assertion is that none of it arrives at the seam.
///
/// **This is a security control, not a copy preference.** These strings sit on
/// a lock screen, supplement names are health-adjacent data, and iOS exposes no
/// redaction placeholder through this plugin — which makes the TEXT ITSELF the
/// only privacy control available on that platform (07-UI-SPEC § 2, § 8
/// DECIDED-19, 07-RESEARCH § Security Domain V4, risk R-11).
///
/// ## The payload, and why it is asserted as a constant rather than as a
/// captured field
///
/// The seam's two scheduling methods take an id, a time, a title and a body —
/// and **no payload at all**. The payload is added inside the plugin adapter as
/// the single `doseTapPayload` constant, and 07-01's wire test asserts that
/// exact value crossing the platform channel. So there is no per-call payload
/// for a recorder to capture: the app cannot vary it even if it wanted to. The
/// assertions below therefore check the constant itself against every name,
/// which is the same claim about the same bytes, and additionally pin it to its
/// one known token so a future per-call payload cannot arrive unnoticed.
///
/// Everything runs against the mocked seam and mocked streams, never a real
/// database: what is under test is what the app hands the operating system.
library;

import 'dart:async';

import 'package:vitomy/core/domain/models.dart';
import 'package:vitomy/core/l10n/gen/app_localizations.dart';
import 'package:vitomy/core/notifications/notification_constants.dart';
import 'package:vitomy/core/notifications/notification_locale.dart';
import 'package:vitomy/core/notifications/notification_plan.dart';
import 'package:vitomy/core/notifications/notification_providers.dart';
import 'package:vitomy/core/notifications/notification_scheduler.dart';
import 'package:vitomy/core/notifications/notification_sync.dart';
import 'package:vitomy/core/providers.dart';
import 'package:vitomy/core/today_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'recording_scheduler.dart';

/// The day every fixture is anchored on, and a wall clock early enough that no
/// slot below is already past — a dropped slot would silently shrink the set
/// these tests assert over.
final _today = DateTime.utc(2026, 8, 17);
final _wallClock = DateTime(2026, 8, 17, 0, 5);

const _uk = Locale('uk');
const _en = Locale('en');

/// Supplement names chosen to be unmistakable in a haystack: none is a word, a
/// substring of a word, or a fragment of any rendered time or count. A hit is
/// therefore a real leak and never a coincidence — and both alphabets are
/// represented, because the copy layer is asked for text in whichever locale is
/// resolved and a leak might survive only one of them.
const _names = <String>[
  'Ашваганда-QX7',
  'Rhodiola-ZK2',
  'Мелатонін-VV9',
  'Creatine-77Q',
  'Ubiquinol-JJ4',
];

/// The calendar clock with its day pinned and its wall clock injected — the
/// same subclass idiom `notification_sync_test.dart` uses, so the sync reads the
/// SAME `now` seam production reads rather than a mock of it.
class _FixedToday extends TodayController {
  _FixedToday(this._day, {super.now});

  final DateTime _day;

  @override
  DateTime build() => _day;
}

/// A bootstrap whose readiness answer is fixed, so the precondition can be
/// driven without running the real one.
class _FixedBootstrap extends NotificationBootstrap {
  _FixedBootstrap({required this.ready});

  final bool ready;

  @override
  bool build() => ready;
}

DoseSlot _slot(int minutes) =>
    DoseSlot(id: 'sl-$minutes', minutesFromMidnight: minutes, doseLabel: '1');

Supplement _supplement(int index) => Supplement(
      id: 's$index',
      name: _names[index],
      doseText: '${_names[index]} 500 мг',
      colorValue: 0xFF000000,
      note: 'нотатка про ${_names[index]}',
    );

/// A course regimen: tier B by construction — a course can never be promoted to
/// a repeat — so it contributes one request per active day per slot.
Regimen _course({
  required String id,
  required String supplementId,
  required List<int> minutes,
  DateTime? end,
}) =>
    Regimen(
      id: id,
      supplementId: supplementId,
      kind: RegimenKind.course,
      startDate: _today,
      endDate: end ?? _today.add(const Duration(days: 2)),
      onDays: 0,
      offDays: 0,
      paused: false,
      slots: [for (final m in minutes) _slot(m)],
    );

/// A cyclic regimen with a BREAK in it: active on many days of the horizon and
/// therefore expensive, but never promotable, because a repeat carries one
/// frozen dose count and this one is not due every day.
Regimen _cycling({
  required String id,
  required String supplementId,
  required List<int> minutes,
}) =>
    Regimen(
      id: id,
      supplementId: supplementId,
      kind: RegimenKind.cyclic,
      startDate: _today,
      endDate: null,
      onDays: 5,
      offDays: 2,
      paused: false,
      slots: [for (final m in minutes) _slot(m)],
    );

/// A regimen that runs every day from today with no break — the one shape the
/// pure plan promotes to a single repeating request that never lapses.
Regimen _daily({
  required String id,
  required String supplementId,
  required List<int> minutes,
}) =>
    Regimen(
      id: id,
      supplementId: supplementId,
      kind: RegimenKind.cyclic,
      startDate: _today,
      endDate: null,
      onDays: 365,
      offDays: 0,
      paused: false,
      slots: [for (final m in minutes) _slot(m)],
    );

void main() {
  late RecordingScheduler scheduler;
  late ProviderContainer container;
  late void Function(List<Regimen>) emit;

  // The copy layer formats the time fragment, and a locale's formatting symbols
  // must be loaded before it can. In the app that is free — the resolved locale
  // is only ever reported by a tree that has ALREADY loaded that locale's
  // material localizations, and loading them is what initializes the symbols —
  // but a container test loads no localizations, so it does it here.
  setUpAll(() async {
    for (final locale in AppLocalizations.supportedLocales) {
      await initializeDateFormatting(locale.toString());
    }
  });

  setUp(() => scheduler = RecordingScheduler());
  tearDown(() => container.dispose());

  /// Advances past the debounce window and drains the application.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(notificationSyncDebounce);
    await tester.pump();
  }

  /// Mounts a container holding [supplements] and [regimens], keeps the sync
  /// alive the way the root app widget does, reports [locale], and settles.
  ///
  /// The supplements are seeded even though nothing in the notification layer
  /// may read them: that is exactly the point of the privacy proof below — the
  /// names are PRESENT and reachable in the graph, and the claim is that they
  /// do not arrive at the seam.
  Future<void> start(
    WidgetTester tester, {
    required List<Supplement> supplements,
    required List<Regimen> regimens,
    Locale locale = _uk,
  }) async {
    late final StreamController<List<Regimen>> regimenStream;
    regimenStream = StreamController<List<Regimen>>.broadcast();
    // A FRESH list per emission, because a Drift query builds one per result
    // and Riverpod collapses an equal re-emission into no notification at all.
    emit = (list) => regimenStream.add(List<Regimen>.of(list));
    container = ProviderContainer(
      overrides: [
        notificationSchedulerProvider.overrideWithValue(scheduler),
        timeZoneLoaderProvider.overrideWithValue(() async {}),
        todayProvider.overrideWith(() => _FixedToday(_today, now: () => _wallClock)),
        supplementsStreamProvider.overrideWith((ref) => Stream.value(supplements)),
        regimensStreamProvider.overrideWith((ref) {
          ref.onDispose(regimenStream.close);
          return regimenStream.stream;
        }),
        notificationBootstrapProvider.overrideWith(() => _FixedBootstrap(ready: true)),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );
    // An unlistened provider is PAUSED in this version of Riverpod, so the
    // sync's trigger listeners would never be registered at all.
    container.listen(notificationSyncProvider, (_, _) {});
    // Listened rather than merely read later, for the same reason: a provider
    // nothing is listening to is paused, and the reachability assertion in the
    // privacy proof would then observe a stream that had never started.
    container.listen(supplementsStreamProvider, (_, _) {});
    container.read(notificationLocaleProvider.notifier).report(locale);
    emit(regimens);
    await settle(tester);
  }

  /// Every call that armed a reminder.
  List<SchedulerCall> scheduled() => scheduler.calls
      .where((c) => c.method == scheduleOnceCall || c.method == scheduleDailyCall)
      .toList(growable: false);

  group('no supplement name can reach a scheduled notification (T-07-32)', () {
    /// Five supplements, each with a regimen carrying several slots, all active
    /// today and for the whole of a three-day course — so the assertion below
    /// runs over a genuinely populated set rather than over nothing.
    (List<Supplement>, List<Regimen>) stack() => (
          [for (var i = 0; i < _names.length; i++) _supplement(i)],
          [
            for (var i = 0; i < _names.length; i++)
              _course(
                id: 'r$i',
                supplementId: 's$i',
                minutes: [480 + i, 780 + i, 1260 + i],
              ),
          ],
        );

    for (final locale in const [_uk, _en]) {
      testWidgets(
        'not in any title, any body or the payload, in ${locale.languageCode}',
        (tester) async {
          final (supplements, regimens) = stack();
          await start(
            tester,
            supplements: supplements,
            regimens: regimens,
            locale: locale,
          );

          final calls = scheduled();
          // Non-vacuity first, and stated as a floor rather than an exact
          // count: an assertion loop over an empty list is green, and a green
          // privacy proof that measured nothing is worse than none at all.
          expect(
            calls.length,
            greaterThanOrEqualTo(_names.length * 3),
            reason: 'the stack has ${_names.length} regimens with three slots '
                'each, all active today — if fewer reminders than that were '
                'armed, the loop below is asserting over a set the sync never '
                'built, and would pass no matter what the copy layer did',
          );
          // The names really are in the container, so the leak this test
          // forbids is reachable rather than hypothetical.
          final List<String> reachable;
          switch (container.read(supplementsStreamProvider)) {
            case AsyncData(value: final data):
              reachable = [for (final s in data) s.name];
            case _:
              reachable = const <String>[];
          }
          expect(
            reachable,
            _names,
            reason: 'every name must be resolvable in this very container — '
                'otherwise the test proves only that absent data cannot leak, '
                'which is not the property. The notification layer is not '
                'ALLOWED to read this provider; that it could not even if the '
                'rule were broken is what the source gate asserts, and what '
                'this test deliberately does not rely on.',
          );

          for (final name in _names) {
            expect(
              doseTapPayload.contains(name),
              isFalse,
              reason: 'the tap payload carries "$name". The operating system '
                  'PERSISTS a payload across app updates and can replay it, so '
                  'a name there outlives the reminder that carried it.',
            );
            for (final call in calls) {
              expect(
                call.title!.contains(name),
                isFalse,
                reason: 'the TITLE of the reminder at '
                    '${call.minutesFromMidnight} carries the supplement name '
                    '"$name": "${call.title}". This string is rendered by the '
                    'operating system on a lock screen, and on iOS the text '
                    'itself is the only privacy control that exists — the '
                    'plugin exposes no redaction placeholder.',
              );
              expect(
                call.body!.contains(name),
                isFalse,
                reason: 'the BODY of the reminder at '
                    '${call.minutesFromMidnight} carries the supplement name '
                    '"$name": "${call.body}". The count-only body is a '
                    'security control and not a copy choice (07-UI-SPEC § 2).',
              );
            }
          }
        },
      );
    }

    testWidgets('the payload of every scheduled notification is the one known '
        'token and nothing else', (tester) async {
      final (supplements, regimens) = stack();
      await start(tester, supplements: supplements, regimens: regimens);

      expect(scheduled(), isNotEmpty);
      expect(
        doseTapPayload,
        'today',
        reason: 'exactly one payload token exists in the whole app, which is '
            'what lets the check on the way back in be a single equality and '
            'what keeps a dose time out of a string the OS persists '
            '(DECIDED-13). The seam carries no per-call payload parameter at '
            'all, so this constant IS the payload of every call above.',
      );
      expect(
        isKnownNotificationPayload(doseTapPayload),
        isTrue,
        reason: 'the token the app writes must be the token the whitelist '
            'accepts — otherwise every delivered reminder routes nowhere.',
      );
    });
  });

  group('the pending-request budget holds END TO END, not only in the pure '
      'plan (T-07-36)', () {
    /// A stack several times the ceiling: six cycling regimens with a break, six
    /// slots each, active across most of a thirty-day horizon — plus two daily
    /// regimens whose minutes are promoted to repeats.
    List<Regimen> oversized() => [
          for (var i = 0; i < 6; i++)
            _cycling(
              id: 'big$i',
              supplementId: 's${i % _names.length}',
              minutes: [400 + i, 500 + i, 600 + i, 700 + i, 800 + i, 900 + i],
            ),
          _daily(id: 'rep0', supplementId: 's0', minutes: const [1290]),
          _daily(id: 'rep1', supplementId: 's1', minutes: const [1350]),
        ];

    testWidgets('an oversized stack produces at most the budget\'s worth of '
        'schedule calls in one application', (tester) async {
      final regimens = oversized();

      // What the SAME stack would produce with no ceiling at all — measured
      // here rather than asserted from memory, so "several times the budget" is
      // a number this run actually observed.
      final unbudgeted = planNotifications(
        regimens: regimens,
        today: _today,
        nowMinutesFromMidnight: _wallClock.hour * 60 + _wallClock.minute,
        horizonDays: notificationHorizonDays,
        budget: 1000000,
      );
      expect(
        unbudgeted.length,
        greaterThan(notificationBudget * 3),
        reason: 'the fixture is meant to be several times the ceiling; at '
            '${unbudgeted.length} entries against a budget of '
            '$notificationBudget it no longer tests truncation at all',
      );

      await start(
        tester,
        supplements: [for (var i = 0; i < _names.length; i++) _supplement(i)],
        regimens: regimens,
      );

      expect(
        scheduled().length,
        lessThanOrEqualTo(notificationBudget),
        reason: 'the pure plan\'s own tests already prove the ceiling holds '
            'inside the function. This proves nothing DOWNSTREAM re-expands '
            'it: not the copy layer, not the reconciler, not the sync. iOS '
            'keeps at most 64 pending requests per app and the two credible '
            'descriptions of what it evicts past that ceiling disagree with '
            'each other — the app is built so as never to find out which is '
            'right, and that is only true if the number of CALLS is bounded, '
            'not merely the number of planned entries.',
      );
    });

    testWidgets('every daily repeat survives the truncation — the entries that '
        'never lapse are not the ones dropped', (tester) async {
      await start(
        tester,
        supplements: [for (var i = 0; i < _names.length; i++) _supplement(i)],
        regimens: oversized(),
      );

      final repeats = scheduler.calls
          .where((c) => c.method == scheduleDailyCall)
          .map((c) => c.id)
          .toSet();
      expect(
        repeats,
        {
          notificationIdFor(day: null, minutesFromMidnight: 1290),
          notificationIdFor(day: null, minutesFromMidnight: 1350),
        },
        reason: 'a repeat costs one pending request forever and NEVER lapses, '
            'while a one-shot in the far future is a reminder that simply '
            'stops. Ordering the repeats first is the only mechanism '
            'protecting them from the budget, and a truncation that quietly '
            'ate them would leave the app looking correct while its '
            'longest-lived reminders had gone — with the whole suite green.',
      );
    });
  });

  group('a deleted supplement contributes nothing (criterion 2\'s '
      'repository half)', () {
    testWidgets('the regimen the cascade soft-deleted is cancelled, and '
        'nothing is armed for it again', (tester) async {
      final supplements = [_supplement(0), _supplement(1)];
      final kept = _course(id: 'keep', supplementId: 's0', minutes: const [600]);
      final deleted =
          _course(id: 'gone', supplementId: 's1', minutes: const [660]);

      await start(
        tester,
        supplements: supplements,
        regimens: [kept, deleted],
      );

      final armedForDeleted = scheduled()
          .where((c) => c.minutesFromMidnight == 660)
          .map((c) => c.id!)
          .toSet();
      expect(armedForDeleted, isNotEmpty,
          reason: 'the deleted regimen must have been armed BEFORE the delete, '
              'or the cancellation below is asserting over nothing');

      // What the platform is now holding, so the next application reconciles
      // against reality rather than against an empty set.
      scheduler.held = [
        for (final call in scheduled())
          PendingNotification(
            id: call.id!,
            title: call.title,
            body: call.body,
            payload: doseTapPayload,
          ),
      ];
      scheduler.calls.clear();

      // Soft-deleting a supplement CASCADES to its regimen, so the stream the
      // sync watches simply stops reporting it. There is no delete path in the
      // notification layer at all — which is the property under test.
      emit([kept]);
      await settle(tester);

      expect(
        scheduler.calls.where((c) => c.method == cancelCall).map((c) => c.id).toSet(),
        armedForDeleted,
        reason: 'a supplement the user deleted must stop reminding them, and '
            'it must stop by INDIVIDUAL cancellation: a blanket clear would '
            'also dismiss delivered reminders for the supplements they kept.',
      );
      expect(
        scheduled().where((c) => c.minutesFromMidnight == 660),
        isEmpty,
        reason: 'nothing may be re-armed for a regimen that is no longer in '
            'the stream.',
      );
      expect(
        scheduled().where((c) => c.minutesFromMidnight == 600),
        isEmpty,
        reason: 'the surviving regimen\'s reminders are already correct in the '
            'pending set, so reconciliation must leave them alone rather than '
            'cancelling and re-arming them — a re-issue is a window in which '
            'nothing is scheduled.',
      );
    });
  });
}
