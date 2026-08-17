/// Platform-configuration invariants (DATA-02 backup half, release-signing safety).
///
/// The milestone audit found that DATA-02's "a user's data survives an app
/// reinstall via OS-level device backup" guarantee lived only in a doc comment
/// in `lib/core/db/database.dart` — a one-line manifest edit could break it
/// with the whole suite still green. These tests make the platform config an
/// asserted invariant like every other locked decision in this codebase.
///
/// The security audit separately found that release builds are signed with the
/// debug keystore (the Flutter template default). That is a release blocker,
/// not a code defect, so it is asserted here as a visible reminder rather than
/// silently fixed — a real keystore is a secret only the project owner can
/// create. The test documents the exact state and fails the day someone
/// believes the app is release-signed when it is not.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strips XML comments so a comment naming a forbidden attribute cannot
/// invalidate its own gate (the comment-stripping convention used by every
/// source gate in this suite).
String _stripXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// Strips Dart/Swift/ObjC line and block comments for the same reason: the
/// database's own doc comment names `NSURLIsExcludedFromBackupKey` in order to
/// forbid it, and a gate that flags its own documentation is a gate nobody
/// keeps.
String _stripCodeComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('DATA-02 backup guarantee — the app must never opt out of OS backups', () {
    test('no Android manifest disables backup', () {
      // All three variants: a debug/profile-only opt-out would still be wrong,
      // and would mask the release behaviour during testing.
      for (final variant in const ['main', 'debug', 'profile']) {
        final file = File('android/app/src/$variant/AndroidManifest.xml');
        if (!file.existsSync()) continue;
        final xml = _stripXmlComments(file.readAsStringSync());
        expect(
          xml.contains('android:allowBackup="false"'),
          isFalse,
          reason:
              'android/app/src/$variant/AndroidManifest.xml opts out of Android '
              'Auto Backup. DATA-02 requires the local database to be included '
              'in OS backups so a reinstall restores the user\'s stack and '
              'intake history. See lib/core/db/database.dart.',
        );
        expect(
          xml.contains('android:fullBackupContent="false"'),
          isFalse,
          reason: 'android/app/src/$variant/AndroidManifest.xml disables full '
              'backup content, which excludes the database (DATA-02).',
        );
      }
    });

    test('no iOS source excludes the database from iCloud backup', () {
      // NSURLIsExcludedFromBackupKey is the iOS equivalent opt-out. It could be
      // set from Dart or from the native runner, so scan both.
      final roots = [Directory('lib'), Directory('ios/Runner')];
      final offenders = <String>[];
      for (final root in roots) {
        if (!root.existsSync()) continue;
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!const ['.dart', '.swift', '.m', '.h', '.plist']
              .any(entity.path.endsWith)) {
            continue;
          }
          final code = entity.path.endsWith('.plist')
              ? entity.readAsStringSync()
              : _stripCodeComments(entity.readAsStringSync());
          if (code.contains('isExcludedFromBackup') ||
              code.contains('NSURLIsExcludedFromBackupKey')) {
            offenders.add(entity.path);
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'These files exclude data from iCloud backup, breaking DATA-02: '
            '$offenders',
      );
    });

    test('the database is opened in the OS-backed application documents directory',
        () {
      // drift_flutter's default `driftDatabase(name:)` resolves to
      // getApplicationDocumentsDirectory(), which is backed up on both
      // platforms. An explicit path (cache/tmp/support) would silently leave
      // the backup set.
      final source = File('lib/core/db/database.dart').readAsStringSync();
      expect(
        source.contains('driftDatabase('),
        isTrue,
        reason: 'DATA-02 relies on drift_flutter resolving the OS '
            'application-documents directory; an explicit path would need its '
            'own backup-inclusion proof.',
      );
      for (final forbidden in const [
        'getTemporaryDirectory',
        'getApplicationCacheDirectory',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason: 'lib/core/db/database.dart uses $forbidden — cache and temp '
              'directories are excluded from OS backups, breaking DATA-02.',
        );
      }
    });
  });

  group('NOTIF-02 — the notification platform config, asserted in both directions',
      () {
    // Reads the DECLARED permission set of our own main manifest. That is the
    // only set this repository controls: the merged release manifest also holds
    // POST_NOTIFICATIONS and VIBRATE, which arrive from the plugin's own
    // manifest at merge time (measured by building the app twice, 07-RESEARCH
    // §3.3). Asserting the declared set by EQUALITY is the point — a
    // forbidden-list `contains` check passes happily the day a merge into our
    // own file introduces a permission nobody listed.
    Set<String> declaredPermissions(String variant) {
      final file = File('android/app/src/$variant/AndroidManifest.xml');
      if (!file.existsSync()) return const <String>{};
      final xml = _stripXmlComments(file.readAsStringSync());
      return RegExp(r'<uses-permission\s+android:name="([^"]+)"')
          .allMatches(xml)
          .map((m) => m.group(1)!)
          .toSet();
    }

    test('the main manifest declares EXACTLY the boot-completed permission', () {
      expect(
        declaredPermissions('main'),
        <String>{'android.permission.RECEIVE_BOOT_COMPLETED'},
        reason:
            'android/app/src/main/AndroidManifest.xml must declare exactly one '
            'permission: RECEIVE_BOOT_COMPLETED, so the plugin can re-arm dose '
            'reminders after a reboot. The two notification permissions arrive '
            'from the plugin\'s own manifest at merge time and must NOT be '
            'declared here; nothing else may be added at all.',
      );
    });

    test('no privileged or network permission is declared, by name', () {
      // Named individually so a failure reports the specific policy problem
      // rather than only a set mismatch.
      const forbidden = <String, String>{
        'android.permission.SCHEDULE_EXACT_ALARM':
            'exact alarms are a Play-policy landmine and the scheduling mode '
                'this app uses (inexactAllowWhileIdle) needs no permission',
        'android.permission.USE_EXACT_ALARM': 'same, and this one is the '
            'restricted variant that requires a policy declaration',
        'android.permission.INTERNET':
            'the release build is fully offline; INTERNET belongs to the debug '
                'manifest only',
        'android.permission.ACCESS_NETWORK_STATE': 'the app makes no network '
            'requests at all',
        'android.permission.USE_FULL_SCREEN_INTENT':
            'a dose reminder is not an alarm clock and this permission is '
                'review-gated',
        'android.permission.ACCESS_NOTIFICATION_POLICY':
            'the app never overrides Do Not Disturb',
        'android.permission.POST_NOTIFICATIONS':
            'supplied by the plugin\'s own manifest — declaring it here would '
                'duplicate it in the file this gate protects',
        'android.permission.VIBRATE': 'supplied by the plugin\'s own manifest',
      };
      final declared = declaredPermissions('main');
      for (final entry in forbidden.entries) {
        expect(
          declared.contains(entry.key),
          isFalse,
          reason: 'android/app/src/main/AndroidManifest.xml declares '
              '${entry.key} — ${entry.value}.',
        );
      }
    });

    test('INTERNET stays debug-only, which is what keeps the release build offline',
        () {
      expect(
        declaredPermissions('debug'),
        contains('android.permission.INTERNET'),
        reason: 'the debug manifest must keep its own INTERNET permission — the '
            'Flutter tool needs it for hot reload.',
      );
      expect(
        declaredPermissions('main'),
        isNot(contains('android.permission.INTERNET')),
        reason: 'INTERNET in the main manifest would ship in the release '
            'build, breaking the fully-offline property.',
      );
    });

    // Added by plan 07-06, and deliberately a WIDENING of the two assertions
    // above rather than a copy of them in another file. Those two read the
    // `main` variant only, because that is the one whose contents ship. This
    // one reads EVERY variant, because `profile` also ships when a release
    // build is profiled and because the merged manifest is the union of them
    // all — an exact-alarm permission parked in `profile` would be invisible to
    // every assertion in this repository while still being a real Play-policy
    // declaration in a build the team actually installs.
    test('no variant of the manifest declares an exact-alarm permission, and '
        'INTERNET lives in exactly the two development variants', () {
      final variants = Directory('android/app/src')
          .listSync()
          .whereType<Directory>()
          .map((d) => d.path.split(Platform.pathSeparator).last)
          .where((v) =>
              File('android/app/src/$v/AndroidManifest.xml').existsSync())
          .toList()
        ..sort();
      // The glob self-proof this file's other manifest assertions get for free
      // by naming their variant literally.
      expect(variants, containsAll(<String>['main', 'debug']),
          reason: 'the manifest variants glob resolved $variants — without at '
              'least main and debug this assertion is scanning nothing');

      for (final variant in variants) {
        final declared = declaredPermissions(variant);
        for (final exact in const [
          'android.permission.SCHEDULE_EXACT_ALARM',
          'android.permission.USE_EXACT_ALARM',
        ]) {
          expect(
            declared.contains(exact),
            isFalse,
            reason: 'android/app/src/$variant/AndroidManifest.xml declares '
                '$exact. This app schedules with inexactAllowWhileIdle, which '
                'needs no permission at all, and accepts ~10-15 minutes of '
                'doze jitter as a stated cost — the reminder body restates the '
                'scheduled time precisely because delivery is not exact. An '
                'exact-alarm declaration in ANY variant is a policy '
                'declaration the app would have to justify to a reviewer for a '
                'capability it does not use.',
          );
        }
      }

      // Which variants declare INTERNET, as a SET rather than as two separate
      // membership checks. `debug` and `profile` are the Flutter template's own
      // development manifests and both need it for the tool's VM-service
      // connection; `main` is the one whose contents ship. Asserting the set by
      // equality is what makes a FOURTH variant — or `main` acquiring it —
      // fail here, where the two assertions above would both stay green.
      final internetVariants = <String>{
        for (final variant in variants)
          if (declaredPermissions(variant)
              .contains('android.permission.INTERNET'))
            variant,
      };
      expect(
        internetVariants,
        <String>{'debug', 'profile'},
        reason: 'INTERNET must be declared by the development manifests and by '
            'nothing else. This app is fully offline — no client, no '
            'serialization package, no endpoint — and the notification phase '
            'added none of the three: reminders are scheduled by the operating '
            'system on the device, not fetched. INTERNET reaching the shipped '
            'manifest would be a capability the app never uses and a '
            'permission a reviewer would ask about.',
      );
    });

    test('both plugin receivers are declared, non-exported', () {
      final xml = _stripXmlComments(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      );
      for (final receiver in const [
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        'com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver',
      ]) {
        expect(
          xml.contains('android:name="$receiver"'),
          isTrue,
          reason: 'android/app/src/main/AndroidManifest.xml no longer declares '
              '$receiver. Without it scheduled dose reminders never fire (or '
              'never survive a reboot) and NOTHING in the Dart suite can see '
              'it — a manifest tidy-up breaks scheduling with no other symptom.',
        );
      }
      // Every declared receiver must be non-exported: neither is ever launched
      // by another app, and an exported one is a free entry point into the
      // notification machinery.
      final receiverBlocks =
          RegExp(r'<receiver[\s\S]*?(?:/>|</receiver>)').allMatches(xml);
      expect(receiverBlocks.length, 2,
          reason: 'expected exactly the two plugin receivers.');
      for (final block in receiverBlocks) {
        expect(
          block.group(0)!.contains('android:exported="false"'),
          isTrue,
          reason: 'a <receiver> in the main manifest is not '
              'android:exported="false": ${block.group(0)}',
        );
      }
    });

    test('core-library desugaring is enabled and its runtime declared', () {
      final gradle = _stripCodeComments(
        File('android/app/build.gradle.kts').readAsStringSync(),
      );
      expect(
        gradle.contains('isCoreLibraryDesugaringEnabled = true'),
        isTrue,
        reason: 'android/app/build.gradle.kts no longer enables core-library '
            'desugaring. flutter_local_notifications requires it and the '
            'Android build FAILS outright without it — this assertion turns '
            '"the build broke mysteriously after a Gradle edit" into a named '
            'test failure.',
      );
      expect(
        gradle.contains('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs'),
        isTrue,
        reason: 'the desugar_jdk_libs runtime is no longer declared in the '
            'top-level dependencies block of android/app/build.gradle.kts; '
            'enabling the flag without the library does not build.',
      );
    });

    test('the iOS notification-centre delegate is wired, and Info.plist stays bare',
        () {
      final appDelegate = _stripCodeComments(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      );
      expect(
        appDelegate.contains('UNUserNotificationCenter.current().delegate'),
        isTrue,
        reason: 'ios/Runner/AppDelegate.swift no longer sets the '
            'UNUserNotificationCenter delegate. Without it neither foreground '
            'presentation nor the notification tap callback works on iOS.',
      );
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        plist.contains('UIBackgroundModes'),
        isFalse,
        reason: 'ios/Runner/Info.plist declares UIBackgroundModes. Local '
            'notifications need no background mode, no entitlement and no '
            'Info.plist key at all; adding one defensively asks the user (and '
            'App Review) for capability the app does not use.',
      );
    });
  });

  group('release signing — pre-release blocker, asserted so it cannot be forgotten',
      () {
    test('records that release builds still use the debug keystore', () {
      final gradle =
          File('android/app/build.gradle.kts').readAsStringSync();
      final usesDebugKeys =
          gradle.contains('signingConfigs.getByName("debug")');

      // This is the Flutter template default and is harmless for local runs,
      // but a debug-signed release APK is signed with a publicly known key:
      // anyone can forge an update for it outside the Play Store.
      //
      // When a real keystore is wired up, this expectation flips to isFalse and
      // the test becomes a permanent guard against regressing to debug keys.
      expect(
        usesDebugKeys,
        isTrue,
        reason: 'android/app/build.gradle.kts no longer signs release builds '
            'with the debug keystore — good. Flip this expectation to isFalse '
            'so the suite now guards the real signing config.',
      );
    }, skip: false);
  });
}
