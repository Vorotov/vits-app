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
