// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Boostque';

  @override
  String get tabStack => 'Стек';

  @override
  String get tabToday => 'Сьогодні';

  @override
  String get tabCalendar => 'Календар';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get navBack => 'Назад';

  @override
  String get disclaimerEducational => 'Освітній матеріал, не медична порада.';

  @override
  String substancesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString речовини',
      many: '$countString речовин',
      few: '$countString речовини',
      one: '$countString речовина',
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
      other: '$countString тижні',
      many: '$countString тижнів',
      few: '$countString тижні',
      one: '$countString тиждень',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'Мій стек';

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
      other: '$totalString добавки',
      many: '$totalString добавок',
      few: '$totalString добавки',
      one: '$totalString добавка',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$activeString активні',
      many: '$activeString активних',
      few: '$activeString активні',
      one: '$activeString активна',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get supplementsLabel => 'ДОБАВКИ';

  @override
  String get statusActive => 'АКТИВНА';

  @override
  String get statusPaused => 'ПАУЗА';

  @override
  String get statusPlanned => 'ЗАПЛАНОВАНО';

  @override
  String get statusFresh => 'ЩОЙНО ДОДАНО';

  @override
  String get statusFinished => 'ЗАВЕРШЕНО';

  @override
  String get emptyStackTitle => 'Стек порожній';

  @override
  String get emptyStackBody =>
      'Додайте першу добавку кнопкою +: з каталогу або вручну.';

  @override
  String get stackLoadError => 'Не вдалося завантажити стек. Спробуйте ще раз.';

  @override
  String get retry => 'Повторити';

  @override
  String get addSupplement => 'Додати добавку';

  @override
  String get close => 'Закрити';

  @override
  String get searchTab => 'Пошук у базі';

  @override
  String get manualTab => 'Вручну';

  @override
  String get searchCatalogHint => 'Назва або діюча речовина';

  @override
  String get noResultsCatalog =>
      'У каталозі нічого не знайшлося. Додайте цю добавку вручну.';

  @override
  String get nameLabel => 'Назва';

  @override
  String get doseLabel => 'Доза';

  @override
  String get addManualSupplement => 'Додати добавку';

  @override
  String get scheduleTitle => 'Розклад прийому';

  @override
  String get pausedBadge => 'НА ПАУЗІ';

  @override
  String get periodicityLabel => 'ПЕРІОДИЧНІСТЬ';

  @override
  String get cyclicTab => 'Циклічно';

  @override
  String get courseTab => 'Разовий курс';

  @override
  String get startLabel => 'Старт';

  @override
  String get endLabel => 'Кінець';

  @override
  String get cycleLength => 'Довжина циклу';

  @override
  String get breakLabel => 'Перерва';

  @override
  String get noBreak => 'без перерви';

  @override
  String cycleSummaryCyclic(String on, String off) {
    return '$on прийому, потім $off перерви. Повторюється, поки не вимкнете.';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on прийому без перерви. Повторюється, поки не вимкнете.';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'Один курс без повторення: $start — $end';
  }

  @override
  String get timeSlotsLabel => 'ЧАС ПРИЙОМУ';

  @override
  String slotsPerDay(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString разу на день',
      many: '$countString разів на день',
      few: '$countString рази на день',
      one: '$countString раз на день',
    );
    return '$_temp0';
  }

  @override
  String get addTimeSlot => '+ Додати слот часу';

  @override
  String removeSlot(String time) {
    return 'Видалити слот $time';
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

    return 'Найменший інтервал — $hString год $mString хв.';
  }

  @override
  String get slotIntervalSingle => 'Один слот на день.';

  @override
  String get saveAndStart => 'Додати й запустити цикл';

  @override
  String get saveWhilePaused => 'Зберегти, цикл на паузі';

  @override
  String get pause => 'Пауза';

  @override
  String get resume => 'Відновити цикл';

  @override
  String get delete => 'Видалити';

  @override
  String get cancel => 'Скасувати';

  @override
  String saveHintActive(String start) {
    return 'Слоти з\'являться в календарі з $start. Пауза прибирає їх, не видаляючи налаштувань.';
  }

  @override
  String get saveHintPaused =>
      'Цикл збережеться в стеку зі статусом «пауза», у календарі його не буде.';

  @override
  String deleteConfirmTitle(String name) {
    return 'Видалити «$name»?';
  }

  @override
  String get deleteConfirmBody =>
      'Видалення прибирає розклад і майбутні дози. Історія прийому залишається.';

  @override
  String get saveFailed => 'Не вдалося зберегти. Спробуйте ще раз.';

  @override
  String get catalogAshwagandhaName => 'Ашваганда KSM-66';

  @override
  String get catalogAshwagandhaDose => '300 мг · капсули';

  @override
  String get catalogCreatineName => 'Креатин моногідрат';

  @override
  String get catalogCreatineDose => '5 г · порошок';

  @override
  String get catalogMelatoninName => 'Мелатонін 3 мг';

  @override
  String get catalogMelatoninDose => '3 мг · таблетки';

  @override
  String get catalogNmnName => 'NMN 250 мг';

  @override
  String get catalogNmnDose => '250 мг · капсули';

  @override
  String get catalogB12Name => 'Вітамін B12 метилкобаламін';

  @override
  String get catalogB12Dose => '1000 мкг · таблетки';

  @override
  String get catalogQ10Name => 'Коензим Q10 убіквінол';

  @override
  String get catalogQ10Dose => '100 мг · капсули';

  @override
  String get catalogIodineName => 'Йод 150 мкг';

  @override
  String get catalogIodineDose => '150 мкг · таблетки';

  @override
  String get catalogIronName => 'Залізо бісглицинат';

  @override
  String get catalogIronDose => '25 мг · капсули';

  @override
  String get catalogHypericumName => 'Зверобій';

  @override
  String get catalogHypericumDose => 'екстракт 300 мг · капсули';

  @override
  String get catalogMagnesiumName => 'Магній бісглицинат';

  @override
  String get catalogMagnesiumDose => '400 мг · капсули';

  @override
  String get catalogChondroName => 'Хондропротектор';

  @override
  String get catalogChondroDose => 'глюкозамін 500 + хондроїтин 400';

  @override
  String get catalogD3Name => 'Вітамін D3';

  @override
  String get catalogD3Dose => '2000 МО · краплі';

  @override
  String get catalogOmega3Name => 'Омега-3';

  @override
  String get catalogOmega3Dose => 'EPA 500 / DHA 250';

  @override
  String get catalogZincName => 'Цинк піколінат';

  @override
  String get catalogZincDose => '15 мг · таблетки';

  @override
  String get catalogCurcuminName => 'Куркумін';

  @override
  String get catalogCurcuminDose => '500 мг + піперин';

  @override
  String get calendarTitleToday => 'Сьогодні';

  @override
  String get blockMorning => 'Ранок';

  @override
  String get blockDay => 'День';

  @override
  String get blockEvening => 'Вечір';

  @override
  String get blockNight => 'Ніч';

  @override
  String get blockTagBreakfast => 'зі сніданком';

  @override
  String get blockTagLunch => 'з обідом';

  @override
  String get blockTagDinner => 'з вечерею';

  @override
  String get blockTagSleep => 'перед сном';

  @override
  String get blockAllTaken => 'усе прийнято';

  @override
  String get blockAllMarked => 'усе відмічено';

  @override
  String blockProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString з $totalString';
  }

  @override
  String get overdueLabel => 'не прийнято вчасно';

  @override
  String get skippedLabel => 'пропущено';

  @override
  String get notMarkedLabel => 'не позначено';

  @override
  String get plannedLabel => 'заплановано';

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

    return 'доза $nString з $mString';
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
      other: '$takenString з $totalString доз прийнято',
      many: '$takenString з $totalString доз прийнято',
      few: '$takenString з $totalString доз прийнято',
      one: '$takenString з $totalString дози прийнято',
    );
    return '$_temp0';
  }

  @override
  String get markTaken => 'Позначити прийнято';

  @override
  String get markSkipped => 'Позначити пропущено';

  @override
  String get undoMark => 'Зняти позначку';

  @override
  String get backToToday => 'Сьогодні';

  @override
  String doseSheetSubtitle(String time, String dose) {
    return '$time · $dose';
  }

  @override
  String doseSheetSubtitleTimeOnly(String time) {
    return '$time';
  }

  @override
  String get emptyDayTitle => 'Доз на цей день немає';

  @override
  String get emptyDayBody => 'Жоден цикл не активний цього дня.';

  @override
  String get emptyDayBodyNoStack =>
      'Додайте добавку у вкладці «Стек», щоб побачити тут дози.';

  @override
  String get dayLoadError => 'Не вдалося завантажити день. Спробуйте ще раз.';

  @override
  String get markFailed => 'Не вдалося зберегти позначку.';

  @override
  String get calendarDisclaimer =>
      'Розклад складено з ваших власних записів. Освітній матеріал, не медична порада.';

  @override
  String get plannerTitle => 'Планувальник';

  @override
  String get plannerSegYear => 'Рік';

  @override
  String get plannerSegCycles => 'Цикли';

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
      other: '$countString місяці',
      many: '$countString місяців',
      few: '$countString місяці',
      one: '$countString місяць',
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
      other: '$countString періоди',
      many: '$countString періодів',
      few: '$countString періоди',
      one: '$countString період',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return 'Цього тижня одночасно $count';
  }

  @override
  String get legendTaking => 'приймаю';

  @override
  String get legendPlanned => 'заплановано';

  @override
  String get legendPaused => 'пауза';

  @override
  String get loadChartTitle => 'ОДНОЧАСНЕ НАВАНТАЖЕННЯ';

  @override
  String get loadChartMeta => 'по тижнях';

  @override
  String get loadScaleCaption => 'повний стовпчик — увесь стек';

  @override
  String peakMonth(String month) {
    return 'Найщільніший місяць — $month';
  }

  @override
  String peakMonthsTie(String month) {
    return 'Найщільніші місяці, зокрема $month';
  }

  @override
  String get yearLegendHint => 'світліше = заплановано';

  @override
  String get monthStateTaking => 'приймаю';

  @override
  String get monthStatePlanned => 'заплановано';

  @override
  String get monthStatePartial => 'частина місяця';

  @override
  String get monthEmpty => 'Цього місяця жоден цикл не активний.';

  @override
  String get emptyPlannerTitle => 'Планувати ще нічого';

  @override
  String get emptyPlannerBody =>
      'Додайте добавку у вкладці «Стек», і її цикли з\'являться тут.';

  @override
  String get emptyPlannerBodyNoRegimen =>
      'У ваших добавок ще немає розкладу. Відкрийте добавку у вкладці «Стек», щоб задати цикл.';

  @override
  String get plannerLoadError =>
      'Не вдалося завантажити планувальник. Спробуйте ще раз.';

  @override
  String get plannerDisclaimer =>
      'Планувальник показує, як ваші цикли накладаються в часі. Освітній матеріал, не медична порада.';

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
  String get languageName => 'Українська';

  @override
  String get languageSystem => 'Системна';

  @override
  String get settingsLanguageTitle => 'МОВА';

  @override
  String get settingsRemindersTitle => 'НАГАДУВАННЯ';

  @override
  String get settingsRemindersAllowed => 'Нагадування дозволено';

  @override
  String get settingsRemindersBlocked => 'Нагадування не дозволено';

  @override
  String get settingsRemindersOpenSystem => 'Відкрити налаштування системи';

  @override
  String get doseReminderTitle => 'Час прийому';

  @override
  String doseReminderBody(int count, String time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString прийоми',
      many: '$countString прийомів',
      few: '$countString прийоми',
      one: '$countString прийом',
    );
    return '$time · $_temp0';
  }

  @override
  String get doseChannelName => 'Нагадування про прийом';

  @override
  String get doseChannelDescription =>
      'Одне нагадування на кожен час прийому у вашому розкладі.';

  @override
  String get onboardingSkip => 'Пропустити';

  @override
  String get onboardingAddFirst => 'Додати першу добавку';

  @override
  String get onboardingPage1Title => 'Ваш стек, день за днем';

  @override
  String get onboardingPage1Body =>
      'Плануйте, що приймати, і відмічайте прийняте. Сьогодні показує лише те, що потрібно саме сьогодні.';

  @override
  String get onboardingIllustrationSemantics1 =>
      'Приклад списку доз: одну відмічено, одна очікує';

  @override
  String get hintDismiss => 'Зрозуміло';

  @override
  String get hintCycle =>
      'Цикл — це тижні прийому та перерви. Задайте їх повзунками нижче, і застосунок сам порахує, у які дні доза потрібна.';

  @override
  String get hintMarkDose =>
      'Торкніться дози, щоб відмітити прийом. Натисніть і утримуйте, щоб побачити інші варіанти.';

  @override
  String get settingsShowIntroAgain => 'Скинути вступ і підказки';

  @override
  String get onboardingPage2Title => 'Календар бачить усе разом';

  @override
  String get onboardingPage2Body =>
      'На календарі видно, де ви зараз у циклі, що з чим збігається і коли починається наступна перерва.';

  @override
  String get onboardingIllustrationSemantics2 =>
      'Приклад календаря: три добавки, тижні прийому подекуди збігаються';

  @override
  String get onboardingNext => 'Далі';
}
