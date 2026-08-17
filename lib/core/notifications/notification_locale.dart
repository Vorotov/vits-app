/// Which language the reminders are built in — OBSERVED from the widget tree,
/// never re-derived (07-UI-SPEC DECIDED-15).
///
/// The notification copy has to be built in the locale the interface is
/// ACTUALLY rendering in. That is not the device locale: the user may have set a
/// manual override, and a reminder in a language the app is not showing is a
/// bug.
///
/// **It is also not re-derived**, and that is the decision worth writing down,
/// because the re-derived form looks simpler and someone will propose it.
/// Reading it as "the stored override, or else the framework's resolution of the
/// platform's locales against the supported list" is exactly what the root app
/// widget already does and would work today — but it is a SECOND COPY of a
/// resolution rule, whose correctness then depends on nobody ever adding a
/// resolution callback. Observing the resolved value is identical by
/// construction and cannot drift. This is the same reasoning the planner view
/// model records for having ONE activity decision point (the PF-1 defect
/// class); a second copy of a resolution rule is the same shape of defect.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The locale the interface is rendering in, or `null` when nothing has
/// observed one yet.
///
/// `null` is a real and useful state, not a gap: a tree that never mounts
/// [NotificationLocaleObserver] — every existing widget test in this repo —
/// resolves no locale, so no text is built and nothing is scheduled. That is
/// the correct behaviour for a tree that is not the app.
class NotificationLocaleReporter extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  /// Reports the locale the tree resolved. The ONLY mutator.
  ///
  /// Idempotent by value, so re-reporting the same locale on every frame
  /// notifies nobody and cannot fan out into repeated re-derivations.
  void report(Locale locale) {
    if (state != locale) state = locale;
  }
}

/// App-lifetime (D-23): the language can change at any moment the app is alive,
/// and both the channel copy and every scheduled reminder follow it.
final notificationLocaleProvider =
    NotifierProvider<NotificationLocaleReporter, Locale?>(
  NotificationLocaleReporter.new,
);

/// Renders its child and reports the locale it finds above itself.
///
/// Mounted inside the localizations it observes — in the root app widget's
/// `builder`, which wraps the navigator and therefore every route.
///
/// The report happens in a POST-FRAME callback rather than during the build
/// phase: writing to a provider while the tree is building is an error the
/// framework asserts on. It also keeps the whole notification bootstrap behind
/// the first frame, which is the FLAG-3 ordering guarantee.
///
/// A test that pumps the shell directly rather than the root app widget will
/// therefore leave the resolved locale null. That is correct and harmless — see
/// [NotificationLocaleReporter].
class NotificationLocaleObserver extends ConsumerStatefulWidget {
  const NotificationLocaleObserver({required this.child, super.key});

  /// The subtree this widget wraps, rendered unchanged.
  final Widget child;

  @override
  ConsumerState<NotificationLocaleObserver> createState() =>
      _NotificationLocaleObserverState();
}

class _NotificationLocaleObserverState
    extends ConsumerState<NotificationLocaleObserver> {
  @override
  Widget build(BuildContext context) {
    final observed = Localizations.localeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationLocaleProvider.notifier).report(observed);
    });
    return widget.child;
  }
}
