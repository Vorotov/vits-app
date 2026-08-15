// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Boostque';

  @override
  String get tabStack => 'Stack';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabSettings => 'Settings';

  @override
  String get disclaimerEducational =>
      'Educational material, not medical advice.';

  @override
  String substancesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count substances',
      one: '$count substance',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '$count week',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'My stack';

  @override
  String get addSupplement => 'Add supplement';

  @override
  String get close => 'Close';

  @override
  String get nameLabel => 'Name';

  @override
  String get doseLabel => 'Dose';

  @override
  String get addManualSupplement => 'Add supplement';

  @override
  String get scheduleTitle => 'Dosing schedule';

  @override
  String get pausedBadge => 'PAUSED';

  @override
  String get periodicityLabel => 'PERIODICITY';

  @override
  String get cyclicTab => 'Cyclic';

  @override
  String get courseTab => 'One-time course';

  @override
  String get startLabel => 'Start';

  @override
  String get endLabel => 'End';

  @override
  String get cycleLength => 'Cycle length';

  @override
  String get breakLabel => 'Break';

  @override
  String get noBreak => 'no break';

  @override
  String cycleSummaryCyclic(String on, String off) {
    return '$on on, then $off off — repeats until you turn it off';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on on without a break — repeats until you turn it off';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'One course without repetition: $start — $end';
  }

  @override
  String get timeSlotsLabel => 'DOSE TIMES';

  @override
  String slotsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times per day',
      one: '$count time per day',
    );
    return '$_temp0';
  }

  @override
  String get addTimeSlot => '+ Add time slot';

  @override
  String removeSlot(String time) {
    return 'Remove slot $time';
  }

  @override
  String slotIntervalNote(int h, int m) {
    return 'Smallest interval — $h h $m min.';
  }

  @override
  String get slotIntervalSingle => 'One slot per day.';

  @override
  String get saveAndStart => 'Add and start cycle';

  @override
  String get saveWhilePaused => 'Save, cycle paused';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume cycle';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String saveHintActive(String start) {
    return 'Slots will appear in the calendar from $start. Pause removes them without deleting your settings.';
  }

  @override
  String get saveHintPaused =>
      'The cycle is saved to your stack as paused — it won\'t appear in the calendar.';

  @override
  String deleteConfirmTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteConfirmBody =>
      'Its schedule and future doses will be removed. Your intake history is kept.';
}
