/// Phase 7's absence gates: every claim the dose-reminder contract makes about
/// what this phase does NOT do, as an assertion with a named consequence.
///
/// Most of this phase's user-visible surface is drawn by the operating system,
/// which means most of its guarantees are about what the app refrains from
/// doing — no supplement name on a lock screen, no interface added, no
/// privileged permission, no blanket clear, none of the chrome the contract
/// decided against. An absence has no runtime surface to pump, so it is gated
/// as a SOURCE fact, over a glob rather than a hardcoded file list: a file a
/// later phase adds is covered the day it lands, with nobody having to remember
/// this file exists.
///
/// Three rules this file follows, all of them learned expensively in this
/// repository:
///
/// 1. **Every group proves its glob first.** A gate over an empty file set is
///    worse than no gate, because it is green.
/// 2. **Every scan strips comments.** Several files in this phase deliberately
///    name in a doc comment the exact thing they refuse to do
///    (`notification_service.dart:188` names both privileged alarm requests so
///    nobody adds them). A gate that trips on its own documentation is a gate a
///    team deletes instead of the defect — four of plan 07-01's acceptance
///    greps were wrong in exactly this way.
/// 3. **Every forbidden needle carries its own reason**, naming the
///    user-visible or policy cost rather than restating the assertion.
///
/// ## Deliberate duplication of three file-level gates
///
/// The Darwin permission flags, the private lock-screen visibility and the two
/// privileged alarm requests are ALREADY gated inside
/// `notification_channel_payload_test.dart`, scoped to
/// `notification_service.dart`. They are gated again here at PHASE level, over
/// every file under `lib/`, and the duplication is the point: each protects a
/// property that a single careless line in a future phase could break, in a
/// file the narrower gate does not watch. A second Darwin initialization, a
/// second Android detail object or a privileged request added from a new file
/// would leave the file-level gates green.
///
/// ## Two of the contract's sign-off conditions are NOT mechanical, and are
/// deliberately not encoded here
///
/// Stated so a later reader does not conclude they were forgotten:
///
/// - Anything of the form "the notification READS correctly on a lock screen"
///   (legibility at the largest system text size, the rendering of the title
///   over the body, the channel row in Android's own settings) is a device
///   observation. Nothing inside the app can see it. Those live in
///   `.planning/phases/07-dose-reminders/07-UAT.md`.
/// - The cold-start concern behind the pre-`runApp` restriction is already a
///   COUNTED-await gate (`notification_routing_test.dart`, plan 07-03) rather
///   than a timing budget. The existing cold-start guarantee counts FRAMES and
///   therefore cannot see an added `await`; counting the awaits is the check
///   that can. Re-expressing it here as a millisecond budget would be a weaker
///   claim wearing a stronger number.
///
/// ## One advisory check an executor runs by hand, not asserted here
///
/// A name-only diff over the whole phase's commits
/// (`git diff --name-only <phase-base>..HEAD -- lib/core/theme/ lib/core/widgets/`)
/// showing no file added or modified under the theme or shared-widget
/// directories. It is advisory because the commit range is not derivable from
/// inside a test, and because the three assertions in the "no interface" group
/// below are the load-bearing half: they hold whatever the diff says.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips Dart line and block comments.
///
/// The idiom is `test/platform_config_test.dart`'s `_stripCodeComments`, copied
/// verbatim rather than imported: that file is itself a gate file, and editing
/// a gate in order to share a helper is how a gate stops being one (the same
/// reason `recording_scheduler.dart` leaves plan 07-01's smaller recorder
/// alone). The name is kept identical so a reader who has met one meets the
/// other.
String _stripCodeComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Every Dart file under [dir], comment-stripped, keyed by path.
///
/// The generated localizations are IN scope deliberately, exactly as
/// `shell_invariants_test.dart` keeps them: a key surviving there after an ARB
/// change would mean `flutter gen-l10n` was never re-run, which is the
/// half-finished state a gate exists to catch.
Map<String, String> _strippedSourcesUnder(String dir) {
  final root = Directory(dir);
  if (!root.existsSync()) return const <String, String>{};
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return {
    for (final file in files) file.path: _stripCodeComments(file.readAsStringSync()),
  };
}

/// How many times [needle] occurs across [sources], with comments already gone.
int _occurrences(Map<String, String> sources, String needle) =>
    sources.values.fold(0, (sum, source) => sum + needle.allMatches(source).length);

/// The files in [sources] that name [needle].
List<String> _filesNaming(Map<String, String> sources, String needle) => [
      for (final entry in sources.entries)
        if (entry.value.contains(needle)) entry.key,
    ];

void main() {
  late Map<String, String> lib;
  late Map<String, String> notifications;
  late Map<String, String> features;

  setUpAll(() {
    lib = _strippedSourcesUnder('lib');
    notifications = _strippedSourcesUnder('lib/core/notifications');
    features = _strippedSourcesUnder('lib/features');
  });

  group('the globs resolve — a gate over an empty file set is worse than no '
      'gate', () {
    test('lib/ resolves the whole app', () {
      expect(lib, isNotEmpty);
      expect(lib.length, greaterThanOrEqualTo(20),
          reason: 'lib/ holds well over twenty Dart files; a smaller set means '
              'the glob stopped matching and every phase-level gate below '
              'became vacuous');
      expect(lib.keys.any((p) => p.endsWith('main.dart')), isTrue,
          reason: 'main.dart must be in the scanned set — the scheduler-override '
              'gate is about that file and nothing else installs the override');
    });

    test('lib/core/notifications/ resolves the phase\'s own directory', () {
      expect(notifications.length, greaterThanOrEqualTo(8),
          reason: 'the phase left ten files in lib/core/notifications/; a '
              'smaller set means the directory moved and the "no interface" '
              'gates below stopped scanning anything');
      expect(
        notifications.keys.any((p) => p.endsWith('notification_service.dart')),
        isTrue,
        reason: 'the one file that imports the plugin must be in the set',
      );
    });

    test('lib/features/ resolves the feature tree', () {
      expect(features.length, greaterThanOrEqualTo(10),
          reason: 'the feature tree holds well over ten Dart files; a smaller '
              'set means the permission-primitive gate below became vacuous');
      expect(
        features.keys.any((p) => p.endsWith('settings_screen.dart')),
        isTrue,
        reason: 'the Settings screen is the ONE place under lib/features/ that '
            'touches this phase at all (DECIDED-9a), so it is the file the '
            'primitive gate is really about',
      );
    });
  });

  group('no interface was added (07-UI-SPEC sign-off 25/26)', () {
    test('no file under lib/core/notifications/ reads a design token', () {
      const tokens = <String, String>{
        'BqColors.': 'a colour token. Nothing in this phase renders a pixel: '
            'every string it authors is drawn by the operating system in its '
            'own type, spacing and colour, and no TextStyle or colour in this '
            'app can reach any of it. A token read here would mean a widget '
            'had appeared where the contract says there is none',
        'BqSpace.': 'a spacing token — this phase lays out nothing at all',
        'BqRadii.': 'a radius token — this phase draws no surface to round',
        'BqText.': 'a type token — notification type is the operating '
            'system\'s and the app must not try to set it',
      };
      final hits = <String>[];
      tokens.forEach((needle, why) {
        for (final path in _filesNaming(notifications, needle)) {
          hits.add('$path reads $needle ($why)');
        }
      });
      expect(hits, isEmpty,
          reason: 'the design system is ESTABLISHED and this phase consumes '
              'none of it. Offenders: $hits');
    });

    test('no file under lib/core/notifications/ imports the theme', () {
      final hits = _filesNaming(notifications, 'core/theme/');
      expect(hits, isEmpty,
          reason: 'an import of lib/core/theme/ from the notification layer is '
              'the reachability half of the token gate above: the tokens are '
              'absent today, and this is what stops them arriving one import '
              'at a time. Offenders: $hits');
    });

    test('no file under lib/features/ is a notification file', () {
      final hits = [
        for (final path in features.keys)
          if (path.toLowerCase().contains('notif')) path,
      ];
      expect(hits, isEmpty,
          reason: 'the one place feature code touches this phase is a PRIVATE '
              'widget inside the existing Settings screen (DECIDED-9a), and '
              'that screen\'s own glob gate independently asserts the feature '
              'still holds exactly two Dart files. A new notification file '
              'under lib/features/ would be the interface this phase promised '
              'not to add. Offenders: $hits');
    });
  });

  group('no ARB key of this phase is rendered by a widget', () {
    // The unusual invariant this contract creates, and the reason nothing else
    // in the repository detects it: all four keys are rendered by the OPERATING
    // SYSTEM. A widget naming one would mean a screen had started restating a
    // notification — which is not a layout bug a golden test could catch, and
    // not an unused key a linter could catch either.
    const keys = <String>[
      'doseReminderTitle',
      'doseReminderBody',
      'doseChannelName',
      'doseChannelDescription',
    ];

    test('none of the four keys resolves anywhere under lib/features/', () {
      final hits = <String>[];
      for (final key in keys) {
        for (final path in _filesNaming(features, key)) {
          hits.add('$path names $key');
        }
      }
      expect(hits, isEmpty,
          reason: 'these four strings are drawn by the operating system on a '
              'lock screen and in Android\'s own settings list. A screen '
              'rendering one would be restating a notification inside the app, '
              'which is a surface this phase explicitly does not add. '
              'Offenders: $hits');
    });

    test('their only consumer outside the l10n plumbing is the notifications '
        'directory', () {
      final hits = <String>[];
      for (final key in keys) {
        for (final path in _filesNaming(lib, key)) {
          if (path.contains('/l10n/')) continue; // the ARB and its generated code
          if (path.startsWith('lib/core/notifications/')) continue;
          hits.add('$path names $key');
        }
      }
      expect(hits, isEmpty,
          reason: 'the copy layer is the only consumer; anything else naming a '
              'key would be a second opinion about text the app never renders. '
              'Offenders: $hits');
    });
  });

  group('private lock-screen visibility, on EVERY Android detail object '
      '(DECIDED-19, research correction C-1)', () {
    test('the count of detail objects and the count of private visibility '
        'match exactly, app-wide', () {
      final details = _occurrences(lib, 'AndroidNotificationDetails(');
      final private = _occurrences(lib, 'NotificationVisibility.private');
      expect(details, greaterThanOrEqualTo(1),
          reason: 'no Android detail object is constructed anywhere in lib/ — '
              'either the notification layer is gone or this gate stopped '
              'matching, and either way it is now vacuous');
      expect(
        private,
        details,
        reason: 'AndroidNotificationChannel carries NO visibility parameter at '
            'all, so visibility must be set per notification; a "set it once on '
            'the channel" shortcut produces PUBLIC lock-screen content. An '
            'EXACT count match rather than a presence check, because a second '
            'detail object added later without the setting would show its '
            'content in full on a lock screen while the first object\'s '
            'presence kept a weaker gate green. Detail objects: $details, '
            'private visibility: $private.',
      );
    });
  });

  group('none of the chrome the contract decided against (DECIDED-18)', () {
    test('no badge, no group, no thread identifier, no interruption level, '
        'anywhere in lib/', () {
      const forbidden = <String, String>{
        'badgeNumber': 'a badge number. This app has no unread concept, so a '
            'badge only clears when the user opens the app — a persistent '
            'nagging surface, and inconsistent with requestBadgePermission: '
            'false, which means the app never even asked for the right to draw '
            'one',
        'groupKey': 'an Android notification group. Both platforms already '
            'bundle an app\'s own notifications; an explicit group additionally '
            'wants a SUMMARY notification, which is a second differently-worded '
            'message and another pending request spent on nothing',
        'threadIdentifier': 'an iOS thread identifier — iOS groups by app by '
            'default, so this buys the same nothing the Android group does',
        'interruptionLevel': 'an iOS interruption level. The only two worth '
            'setting are privileged: timeSensitive needs an entitlement and '
            'critical needs Apple\'s approval, and a supplement reminder has no '
            'business requesting either',
      };
      final hits = <String>[];
      forbidden.forEach((needle, why) {
        for (final path in _filesNaming(lib, needle)) {
          hits.add('$path sets $needle — $why');
        }
      });
      expect(hits, isEmpty,
          reason: 'each of these is a DECIDED absence with a stated reason, and '
              'the point of writing them down was to stop one being added '
              'defensively. Offenders: $hits');
    });

    test('no accent colour is set on a notification', () {
      // Scoped to the notification layer, and the scope is exactly the reason:
      // `color:` is ordinary and correct everywhere else in the app, so an
      // app-wide needle here would flag every legitimate widget in lib/ and be
      // deleted within a week. What must not exist is a colour crossing the
      // platform boundary.
      final hits = _filesNaming(notifications, 'color:');
      expect(hits, isEmpty,
          reason: 'the app\'s accent budget is an exhaustive six-item IN-APP '
              'list. A notification is not an app surface, so tinting the '
              'operating system\'s chrome would add a seventh accent usage that '
              'no in-app contract governs and no widget test can see. '
              'Offenders: $hits');
    });
  });

  group('the three iOS permission-request flags are literal false '
      '(07-RESEARCH Pitfall 1)', () {
    // Duplicated from the file-level gate in
    // `notification_channel_payload_test.dart` ON PURPOSE, and widened to every
    // file under lib/. Under `flutter test` defaultTargetPlatform is forced to
    // android, so only the Android initialization settings ever cross the
    // channel and these three flags are unobservable on ANY wire from a host
    // test — a source gate is the only instrument that exists. The file-level
    // gate would stay green for a SECOND Darwin initialization added elsewhere.
    const flags = <String>[
      'requestAlertPermission',
      'requestSoundPermission',
      'requestBadgePermission',
    ];

    test('every Darwin initialization sets all three to false, and none of the '
        'three appears in any other form', () {
      final initializations = _occurrences(lib, 'DarwinInitializationSettings(');
      expect(initializations, greaterThanOrEqualTo(1),
          reason: 'no Darwin initialization is constructed anywhere in lib/, so '
              'this gate is measuring nothing');
      for (final flag in flags) {
        expect(
          _occurrences(lib, '$flag: false'),
          initializations,
          reason: '$flag is not literal false in every '
              'DarwinInitializationSettings under lib/. Each of the three '
              'DEFAULTS TO TRUE, and any one left at its default fires the '
              'one-and-only iOS system prompt at initialize() — that is, at '
              'LAUNCH — which breaks "asked at first regimen save, never at '
              'launch" silently and with no second chance on that device ever. '
              'They sit in the same constructor as the five defaultPresent* '
              'flags, which keep their true defaults deliberately and mean the '
              'opposite thing; that adjacency is the whole reason this gate '
              'exists.',
        );
        expect(
          _occurrences(lib, flag),
          _occurrences(lib, '$flag: false'),
          reason: '$flag appears somewhere in lib/ in a form that is not '
              '"$flag: false" — a variable, a conditional or a true. The value '
              'must be a LITERAL false a reader can see at the constructor, '
              'because there is no second chance to get it right on a device '
              'that has already been prompted.',
        );
      }
    });
  });

  group('no privileged alarm request, no blanket clear, no re-derived locale '
      'resolution', () {
    test('none of the four resolves anywhere in lib/', () {
      const forbidden = <String, String>{
        'requestExactAlarmsPermission': 'the exact-alarm permission request. It '
            'sits on the same platform class as the methods this app does call, '
            'and exact alarms are a Play-policy landmine for an app whose '
            'reminders are explicitly inexact — the scheduling mode this app '
            'uses needs no permission at all',
        'requestFullScreenIntentPermission': 'the full-screen-intent permission '
            'request, on that same class. A dose reminder is not an alarm '
            'clock, and the permission is review-gated',
        'cancelAll': 'a blanket clear. It also dismisses reminders that were '
            'DELIVERED and that the user has not acted on yet, and it leaves a '
            'window in which nothing at all is scheduled. The reconciler exists '
            'precisely so that a blanket clear is never needed: an empty '
            'desired set against a large pending set produces individual '
            'cancellations',
        'basicLocaleListResolution': 'the framework\'s own locale-resolution '
            'helper. Its appearance anywhere would mean the notification '
            'language had become a SECOND copy of a resolution rule whose '
            'correctness depends on main.dart never passing a '
            'localeResolutionCallback. The locale is OBSERVED from the tree '
            'that is actually rendering, for the same reason this codebase '
            'keeps exactly one activity decision point',
      };
      final hits = <String>[];
      forbidden.forEach((needle, why) {
        for (final path in _filesNaming(lib, needle)) {
          hits.add('$path names $needle — $why');
        }
      });
      expect(hits, isEmpty,
          reason: 'comments are stripped before this scan precisely because '
              'notification_service.dart NAMES the two alarm requests in a doc '
              'comment in order to forbid them. Offenders: $hits');
    });
  });

  group('the permission primitives are unreachable from feature code '
      '(DECIDED-9a)', () {
    test('none of the five plugin primitives resolves under lib/features/', () {
      const primitives = <String, String>{
        'areNotificationsEnabled': 'the Android enabled check',
        'checkPermissions': 'the Darwin permission check',
        'requestPermissions': 'the Darwin permission request',
        'requestNotificationsPermission': 'the Android permission request',
        'openAppNotificationSettings': 'the open-app-notification-settings call',
      };
      final hits = <String>[];
      primitives.forEach((needle, what) {
        for (final path in _filesNaming(features, needle)) {
          hits.add('$path reaches $needle ($what)');
        }
      });
      expect(hits, isEmpty,
          reason: 'DECIDED-9a is the reason this gate exists and the reason it '
              'is written this strictly. The owner decision that ADDED the '
              'Settings permission row KEPT this invariant rather than relaxing '
              'it: the row is allowed to exist only because it reaches named '
              'controller methods (refresh / askOnce / openSystemSettings), '
              'never a platform primitive. Without this group the one property '
              'the owner explicitly preserved would be the only property in the '
              'phase with no STANDING gate — checked once by an acceptance '
              'criterion during plan 07-05 and never again — and it is exactly '
              'the property a future phase erodes by having a screen reach a '
              'primitive directly because it is one line shorter. Offenders: '
              '$hits');
    });
  });

  group('the plugin is quarantined, and the override that reaches it EXISTS',
      () {
    test('exactly one file under lib/ imports the plugin', () {
      final importers = _filesNaming(lib, 'package:flutter_local_notifications');
      expect(
        importers,
        <String>['lib/core/notifications/notification_service.dart'],
        reason: 'every plugin call path throws a LateInitializationError under '
            'flutter test — not a MissingPluginException, not a silent no-op — '
            'so a second importer is a second way for a widget tree to die on '
            'an obscure error naming an obfuscated field. The quarantine is '
            'what makes the seam\'s no-op default sufficient.',
      );
    });

    test('the plugin-backed adapter is referenced by main.dart alone', () {
      final referrers = [
        for (final path in _filesNaming(lib, 'notification_service.dart'))
          if (path != 'lib/core/notifications/notification_service.dart') path,
      ];
      expect(referrers, <String>['lib/main.dart'],
          reason: 'the adapter reaches production through exactly one door: the '
              'bootstrap\'s override. A second referrer would be a second door, '
              'and the no-op default would stop being the thing that keeps the '
              'plugin out of every test.');
    });

    test('main.dart INSTALLS the scheduler override — not merely that it is the '
        'only reference to it', () {
      final main = lib['lib/main.dart'];
      expect(main, isNotNull,
          reason: 'lib/main.dart is not in the scanned set at all');
      const reason = 'notificationSchedulerProvider defaults to the NO-OP '
          'implementation, deliberately, so that no test can reach the plugin '
          'by accident. The price of that choice is paid here and nowhere else: '
          'a forgotten or removed override means production silently schedules '
          'NOTHING while the entire suite stays green — no failing test, no '
          'crash report, no log line, and a user whose reminders simply never '
          'arrive. Plan 07-01 checked this once as an acceptance criterion; a '
          'property whose failure mode is total silence deserves a standing '
          'gate rather than a one-off.';
      expect(main!.contains('notificationSchedulerProvider.overrideWith('),
          isTrue,
          reason: 'main.dart no longer installs the scheduler override. $reason');
      expect(main.contains('PluginNotificationScheduler('), isTrue,
          reason: 'main.dart no longer constructs the plugin-backed scheduler, '
              'so whatever the override installs, it is not the plugin. '
              '$reason');
    });
  });
}
