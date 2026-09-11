// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VitoMy';

  @override
  String get tabStack => 'Stack';

  @override
  String get tabToday => 'Today';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get navBack => 'Back';

  @override
  String get disclaimerEducational =>
      'Educational material, not medical advice.';

  @override
  String substancesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString substances',
      one: '$countString substance',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString weeks',
      one: '$countString week',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'My stack';

  @override
  String stackSummary(int total, int active) {
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);
    final intl.NumberFormat activeNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String activeString = activeNumberFormat.format(active);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$totalString supplements',
      one: '$totalString supplement',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$activeString active',
      one: '$activeString active',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get supplementsLabel => 'SUPPLEMENTS';

  @override
  String get statusActive => 'ACTIVE';

  @override
  String get statusPaused => 'PAUSED';

  @override
  String get statusPlanned => 'PLANNED';

  @override
  String get statusFresh => 'JUST ADDED';

  @override
  String get statusFinished => 'FINISHED';

  @override
  String get emptyStackTitle => 'Your stack is empty';

  @override
  String get emptyStackBody =>
      'Add your first supplement with the + button: from the catalog or manually.';

  @override
  String get stackLoadError => 'Couldn\'t load your stack. Try again.';

  @override
  String get retry => 'Retry';

  @override
  String get addSupplement => 'Add supplement';

  @override
  String get close => 'Close';

  @override
  String get searchTab => 'Search catalog';

  @override
  String get manualTab => 'Add manually';

  @override
  String get searchCatalogHint => 'Name or active substance';

  @override
  String get noResultsCatalog =>
      'Nothing in the catalog matches. Add this supplement manually.';

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
    return '$on on, then $off off. Repeats until you turn it off.';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on on without a break. Repeats until you turn it off.';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'One course without repetition: $start — $end';
  }

  @override
  String get timeSlotsLabel => 'DOSE TIMES';

  @override
  String slotsPerDay(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString times per day',
      one: '$countString time per day',
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
    final intl.NumberFormat hNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String hString = hNumberFormat.format(h);
    final intl.NumberFormat mNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String mString = mNumberFormat.format(m);

    return 'Smallest interval — $hString h $mString min.';
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
      'The cycle is saved to your stack as paused, so it won\'t appear in the calendar.';

  @override
  String deleteConfirmTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteConfirmBody =>
      'Deleting removes the schedule and future doses. Your intake history stays.';

  @override
  String get saveFailed => 'Couldn\'t save. Try again.';

  @override
  String get catalogAshwagandhaName => 'Ashwagandha KSM-66';

  @override
  String get catalogAshwagandhaDose => '300 mg · capsules';

  @override
  String get catalogCreatineName => 'Creatine monohydrate';

  @override
  String get catalogCreatineDose => '5 g · powder';

  @override
  String get catalogMelatoninName => 'Melatonin 3 mg';

  @override
  String get catalogMelatoninDose => '3 mg · tablets';

  @override
  String get catalogNmnName => 'NMN 250 mg';

  @override
  String get catalogNmnDose => '250 mg · capsules';

  @override
  String get catalogB12Name => 'Vitamin B12 methylcobalamin';

  @override
  String get catalogB12Dose => '1000 mcg · tablets';

  @override
  String get catalogQ10Name => 'Coenzyme Q10 ubiquinol';

  @override
  String get catalogQ10Dose => '100 mg · capsules';

  @override
  String get catalogIodineName => 'Iodine 150 mcg';

  @override
  String get catalogIodineDose => '150 mcg · tablets';

  @override
  String get catalogIronName => 'Iron bisglycinate';

  @override
  String get catalogIronDose => '25 mg · capsules';

  @override
  String get catalogHypericumName => 'St. John\'s wort';

  @override
  String get catalogHypericumDose => 'extract 300 mg · capsules';

  @override
  String get catalogMagnesiumName => 'Magnesium bisglycinate';

  @override
  String get catalogMagnesiumDose => '400 mg · capsules';

  @override
  String get catalogChondroName => 'Chondroprotector';

  @override
  String get catalogChondroDose => 'glucosamine 500 + chondroitin 400';

  @override
  String get catalogD3Name => 'Vitamin D3';

  @override
  String get catalogD3Dose => '2000 IU · drops';

  @override
  String get catalogOmega3Name => 'Omega-3';

  @override
  String get catalogOmega3Dose => 'EPA 500 / DHA 250';

  @override
  String get catalogZincName => 'Zinc picolinate';

  @override
  String get catalogZincDose => '15 mg · tablets';

  @override
  String get catalogCurcuminName => 'Curcumin';

  @override
  String get catalogCurcuminDose => '500 mg + piperine';

  @override
  String get calendarTitleToday => 'Today';

  @override
  String get blockMorning => 'Morning';

  @override
  String get blockDay => 'Day';

  @override
  String get blockEvening => 'Evening';

  @override
  String get blockNight => 'Night';

  @override
  String get blockTagBreakfast => 'with breakfast';

  @override
  String get blockTagLunch => 'with lunch';

  @override
  String get blockTagDinner => 'with dinner';

  @override
  String get blockTagSleep => 'before sleep';

  @override
  String get blockAllTaken => 'all taken';

  @override
  String get blockAllMarked => 'all marked';

  @override
  String blockProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString of $totalString';
  }

  @override
  String get overdueLabel => 'not taken on time';

  @override
  String get skippedLabel => 'skipped';

  @override
  String get notMarkedLabel => 'not marked';

  @override
  String get plannedLabel => 'planned';

  @override
  String doseCycleChip(int n, int m) {
    final intl.NumberFormat nNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String nString = nNumberFormat.format(n);
    final intl.NumberFormat mNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String mString = mNumberFormat.format(m);

    return 'dose $nString of $mString';
  }

  @override
  String ringSemantics(int taken, int total) {
    final intl.NumberFormat takenNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String takenString = takenNumberFormat.format(taken);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$takenString of $totalString doses taken',
      one: '$takenString of $totalString dose taken',
    );
    return '$_temp0';
  }

  @override
  String get markTaken => 'Mark taken';

  @override
  String get markSkipped => 'Mark skipped';

  @override
  String get undoMark => 'Clear mark';

  @override
  String get backToToday => 'Today';

  @override
  String doseSheetSubtitle(String time, String dose) {
    return '$time · $dose';
  }

  @override
  String doseSheetSubtitleTimeOnly(String time) {
    return '$time';
  }

  @override
  String get emptyDayTitle => 'No doses on this day';

  @override
  String get emptyDayBody => 'No cycle is active on this day.';

  @override
  String get emptyDayBodyNoStack =>
      'Add a supplement on the Stack tab to see doses here.';

  @override
  String get dayLoadError => 'Couldn\'t load this day. Try again.';

  @override
  String get markFailed => 'Couldn\'t save the mark.';

  @override
  String get calendarDisclaimer =>
      'This schedule is built from your own entries. Educational material, not medical advice.';

  @override
  String get plannerTitle => 'Planner';

  @override
  String get plannerSegYear => 'Year';

  @override
  String get plannerSegCycles => 'Cycles';

  @override
  String plannerRangeSubtitle(String start, String end, String year) {
    return '$start — $end $year';
  }

  @override
  String plannerRangeSubtitleCrossYear(
    String start,
    String startYear,
    String end,
    String endYear,
  ) {
    return '$start $startYear — $end $endYear';
  }

  @override
  String plannerYearSubtitle(String year, String months) {
    return '$year · $months';
  }

  @override
  String monthsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString months',
      one: '$countString month',
    );
    return '$_temp0';
  }

  @override
  String periodsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString periods',
      one: '$countString period',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return '$count at the same time this week';
  }

  @override
  String get legendTaking => 'taking';

  @override
  String get legendPlanned => 'planned';

  @override
  String get legendPaused => 'paused';

  @override
  String get loadChartTitle => 'CONCURRENT LOAD';

  @override
  String get loadChartMeta => 'by week';

  @override
  String get loadScaleCaption => 'full bar = your whole stack';

  @override
  String peakMonth(String month) {
    return 'Densest month — $month';
  }

  @override
  String peakMonthsTie(String month) {
    return 'Densest months, including $month';
  }

  @override
  String get yearLegendHint => 'lighter = planned';

  @override
  String get monthStateTaking => 'taking';

  @override
  String get monthStatePlanned => 'planned';

  @override
  String get monthStatePartial => 'part of the month';

  @override
  String get monthEmpty => 'No cycle is active this month.';

  @override
  String get emptyPlannerTitle => 'Nothing to plan yet';

  @override
  String get emptyPlannerBody =>
      'Add a supplement on the Stack tab and its cycles will appear here.';

  @override
  String get emptyPlannerBodyNoRegimen =>
      'Your supplements don\'t have a schedule yet. Open one on the Stack tab to set a cycle.';

  @override
  String get plannerLoadError => 'Couldn\'t load the planner. Try again.';

  @override
  String get plannerDisclaimer =>
      'The planner shows how your cycles overlap over time. Educational material, not medical advice.';

  @override
  String ganttRowSemantics(String name, String schedule, String periods) {
    return '$name, $schedule, $periods';
  }

  @override
  String ganttRowSemanticsPaused(String name, String schedule, String state) {
    return '$name, $schedule, $state';
  }

  @override
  String yearLegendEntrySemantics(String name, String state) {
    return '$name, $state';
  }

  @override
  String weekBarSemantics(String range, String load) {
    return '$range, $load';
  }

  @override
  String monthCardSemantics(String month, String count) {
    return '$month, $count';
  }

  @override
  String addSupplementCatalogSemantics(String action, String name) {
    return '$action: $name';
  }

  @override
  String get languageName => 'English';

  @override
  String get languageSystem => 'System default';

  @override
  String get settingsLanguageTitle => 'LANGUAGE';

  @override
  String get settingsRemindersTitle => 'REMINDERS';

  @override
  String get settingsRemindersAllowed => 'Reminders are allowed';

  @override
  String get settingsRemindersBlocked => 'Reminders are not allowed';

  @override
  String get settingsRemindersOpenSystem => 'Open system settings';

  @override
  String get doseReminderTitle => 'Time for your doses';

  @override
  String doseReminderBody(int count, String time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString doses',
      one: '$countString dose',
    );
    return '$time · $_temp0';
  }

  @override
  String get doseChannelName => 'Dose reminders';

  @override
  String get doseChannelDescription =>
      'One reminder for each dose time in your schedule.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingAddFirst => 'Add your first supplement';

  @override
  String get onboardingPage1Title => 'Your stack, day by day';

  @override
  String get onboardingPage1Body =>
      'Plan what to take and mark what you\'ve taken. Today shows only what\'s needed today.';

  @override
  String get onboardingIllustrationSemantics1 =>
      'Example dose list: one marked taken, one pending';

  @override
  String get hintDismiss => 'Got it';

  @override
  String get hintCycle =>
      'A cycle is on-weeks plus a break. Set them with the sliders below and the app works out which days need a dose.';

  @override
  String get hintMarkDose =>
      'Tap a dose to mark it taken. Press and hold for the other options.';

  @override
  String get settingsShowIntroAgain => 'Reset intro and hints';

  @override
  String get onboardingPage2Title => 'The calendar sees it all at once';

  @override
  String get onboardingPage2Body =>
      'The calendar shows where you are in each cycle, what overlaps with what, and when the next break starts.';

  @override
  String get onboardingIllustrationSemantics2 =>
      'Example calendar: three supplements whose on-weeks partly overlap';

  @override
  String get onboardingNext => 'Next';
}
