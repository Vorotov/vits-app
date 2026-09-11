/// Whether the operating system will let this app post reminders — and the one
/// moment in an install's life that it is ever asked (NOTIF-03, NOTIF-05).
///
/// **Nothing in this file may produce a user-visible surface.** That is the
/// no-primer decision (DECIDED-7) seen from the failure side: no sheet, no
/// dialog, no banner, no copy of the app's own precedes the operating system's
/// prompt, and none follows a failure on this path either. Every failure here
/// is absorbed and reported to the crash logger, in the shape the launch
/// bootstrap already establishes for the failures this app deliberately
/// swallows.
///
/// The state is three-valued and the third value is load-bearing. The platform
/// answer is a future; neither platform can distinguish "denied" from "never
/// asked" (07-RESEARCH §6.1, §6.2); and the one screen that reads this state
/// must not lie. So "not yet known" is representable, and the row that reads it
/// renders nothing at all while it holds.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitomy/core/notifications/notification_providers.dart';
import 'package:vitomy/core/providers.dart';

/// The key remembering that the ask has already happened, beside the language
/// override in the same small key-value store.
///
/// It is the ONLY thing preventing a repeat prompt, and no platform API can
/// supply the fact for us: `requestPermission` cannot tell "denied" from "never
/// asked" on either platform, so without this flag Android re-shows its
/// rationale dialog on EVERY regimen save until the user has denied twice —
/// exactly the nagging the approved spec forbids.
const notificationAskedKey = 'notification_permission_asked';

/// The permission answer, and the two things the app ever does about it.
///
/// App-lifetime, and deliberately a plain nullable boolean rather than an async
/// value: the Settings screen's own gates forbid a loading surface, and an
/// async value on that screen would be one.
class NotificationPermission extends Notifier<bool?> {
  AppLifecycleListener? _lifecycle;

  @override
  bool? build() {
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
    });

    // A resume is what makes the Settings row SELF-CORRECTING: returning from
    // the operating system's own notification settings is a resume, so a user
    // who has just switched reminders back on sees the row change with no
    // further action and no manual retry control — which is fortunate, because
    // that screen's own gates forbid a retry affordance. It also picks up a
    // permission revoked outside the app while this one was backgrounded.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));

    // Unknown, and NOTHING is asked of the platform here. The sync watches this
    // notifier as a TRIGGER rather than for its value, so merely building it
    // must not cost a platform round trip: the sync already makes its own fresh
    // check on every application, and the only reader of this value asks for it
    // when it appears. Two tests whose whole claim is that nothing at all is
    // called before the preconditions hold are what a build-time read would
    // have quietly falsified.
    return null;
  }

  /// Re-reads the platform's answer and publishes it, including "cannot say".
  Future<void> refresh() async {
    if (!ref.mounted) return;
    try {
      final answer = await ref.read(notificationSchedulerProvider).isEnabled();
      if (!ref.mounted) return;
      state = answer;
    } catch (error, stack) {
      _report(error, stack,
          ErrorDescription('reading whether dose reminders are allowed'));
    }
  }

  /// Asks the operating system for permission — at most once per install.
  ///
  /// Called from the regimen editor's save call site, after the write has
  /// completed and after the route has popped. It is triggered by the save
  /// ACTION, never by state: a provider that asked whenever a regimen exists
  /// would fire on every cold start for every existing user, which is the
  /// launch-time prompt NOTIF-03 forbids.
  ///
  /// The order is: the persisted flag, then the request, then the flag and a
  /// refresh. The guard in front of an idempotent-looking platform call is not
  /// redundant — see [notificationAskedKey] for why it is the only thing
  /// standing between the user and a prompt on every save.
  Future<void> askOnce() async {
    if (!ref.mounted) return;
    if (_alreadyAsked()) return;

    var asked = false;
    try {
      await ref.read(notificationSchedulerProvider).requestPermission();
      asked = true;
    } catch (error, stack) {
      _report(error, stack,
          ErrorDescription('asking for permission to post dose reminders'));
    }

    // Recorded even when the request threw. The operating system may well have
    // shown its prompt before the failure, and on iOS there is no second one to
    // spend — so a throw may not become a licence to ask again on the next
    // save. The state is deliberately left as it was in that case: a failed ask
    // is not evidence about the answer.
    await _rememberAsked();
    if (asked) await refresh();
  }

  /// Opens the operating system's own notification settings for this app.
  ///
  /// The only route back after a refusal on iOS, and after a second refusal on
  /// Android. It changes nothing here by itself: leaving is not an answer, and
  /// the answer arrives on the way back, as a resume.
  Future<void> openSystemSettings() async {
    try {
      await ref.read(notificationSchedulerProvider).openSystemSettings();
    } catch (error, stack) {
      _report(error, stack,
          ErrorDescription('opening the system notification settings'));
    }
  }

  /// Whether this install has already spent its one ask.
  ///
  /// Read as an untrusted object with its type checked, exactly the way the
  /// stored language override is read: the typed getter performs an unguarded
  /// downcast, so a value of the wrong type under this key would throw rather
  /// than degrade. The type of untrusted storage is as untrusted as its
  /// content, and a wrong type here means "not yet asked" (CR-01, T-07-28).
  bool _alreadyAsked() {
    final stored = _store()?.get(notificationAskedKey);
    return stored is bool && stored;
  }

  /// Records that the ask has happened; a store that will not take it costs the
  /// memory only.
  Future<void> _rememberAsked() async {
    final store = _store();
    if (store == null) return;
    try {
      if (!await store.setBool(notificationAskedKey, true)) {
        throw StateError('the permission store rejected the write');
      }
    } catch (error, stack) {
      _report(
          error,
          stack,
          ErrorDescription('remembering that dose reminders were asked about'));
    }
  }

  /// The small key-value store, or null when there is none to read.
  ///
  /// A null store means it could not be opened at all (CR-02), which is the
  /// same state an empty store leaves: ask, and accept that the memory is lost.
  /// The read is guarded because the provider's default THROWS by design — a
  /// deliberate loud failure for the launch-path language read, which `main()`
  /// always overrides. This path can therefore only meet the throw in a test
  /// container that installed no store, which is the same fact as "no store",
  /// and is not worth a crash report of its own.
  SharedPreferences? _store() {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  /// The crash-report shape the launch bootstrap already establishes for the
  /// failures this app deliberately swallows, in one place because every
  /// failure on this path takes it.
  ///
  /// [what] arrives already wrapped, so the sentence describing the failure sits
  /// literally inside the diagnostic constructor the hardcoded-string gate
  /// already recognises — rather than one indirection away from it, where it
  /// would read as unexplained copy.
  void _report(Object error, StackTrace stack, ErrorDescription what) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'vitomy',
        context: what,
      ),
    );
  }
}

/// App-lifetime (D-23): the answer can change at any moment the app is alive,
/// and the ask outlives the screen that triggers it.
final notificationPermissionProvider =
    NotifierProvider<NotificationPermission, bool?>(NotificationPermission.new);
