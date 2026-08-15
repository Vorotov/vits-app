/// The app's single calendar-clock source (plan 03-01, P-1/PF-2; closes
/// 02-REVIEW IN-06).
///
/// This file holds the ONE sanctioned "what day is it" read in the app: every
/// screen consumes [todayProvider] instead of calling `DateTime.now()` per
/// build, so the Calendar and Stack tabs can never disagree about the day and
/// both refresh together at midnight.
///
/// [todayProvider] is app-lifetime (NOT autoDispose) per the D-23 dispose
/// policy recorded once in `core/providers.dart`: it is shared across tabs and
/// costs one `Timer`. It lives in `core/` rather than `features/calendar/`
/// because both the Calendar and the Stack tabs consume it, and `core` must
/// never import `features`.
library;

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/cycle_math.dart' show dateOnly;

/// The next LOCAL midnight strictly after [from].
///
/// Built with the LOCAL date constructor on [from]'s y/m/d with the day
/// component advanced by one: Dart normalizes month/year/leap-day overflow,
/// and the resulting `difference` absorbs a 23-hour or 25-hour DST day.
///
/// Never derive this by adding a fixed `Duration(hours: 24)` (PF-2): on
/// Ukraine's DST days (last Sundays of March/October) that fires an hour early
/// or an hour late, flipping "today" at 23:00 or 01:00.
DateTime nextLocalMidnight(DateTime from) =>
    DateTime(from.year, from.month, from.day + 1);

/// The current device-local calendar day as a UTC date-only value,
/// self-updating at local midnight and on app resume.
class TodayController extends Notifier<DateTime> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  DateTime build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    // Timers are suspended while the app is backgrounded, so a resume may
    // arrive days after the last scheduled tick (E-12: also covers a timezone
    // change while backgrounded).
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _schedule();
    return dateOnly(DateTime.now());
  }

  /// Re-derives the day from the system clock — never increments the previous
  /// value (PF-2) — and re-arms the timer.
  void _refresh() {
    final day = dateOnly(DateTime.now());
    if (day != state) state = day;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    // One second of fudge so the tick lands after the boundary, never on it.
    _timer = Timer(
      nextLocalMidnight(now).difference(now) + const Duration(seconds: 1),
      _refresh,
    );
  }
}

/// The app's single calendar clock (NOT autoDispose per D-23 — see the library
/// doc comment above).
final todayProvider =
    NotifierProvider<TodayController, DateTime>(TodayController.new);
