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
  String get tabCalendar => 'Календар';

  @override
  String get tabSettings => 'Налаштування';

  @override
  String get navBack => 'Назад';

  @override
  String get disclaimerEducational => 'Освітній матеріал, не медична порада.';

  @override
  String substancesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count речовини',
      many: '$count речовин',
      few: '$count речовини',
      one: '$count речовина',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тижні',
      many: '$count тижнів',
      few: '$count тижні',
      one: '$count тиждень',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'Мій стек';

  @override
  String stackSummary(int total, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total добавки',
      many: '$total добавок',
      few: '$total добавки',
      one: '$total добавка',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active активні',
      many: '$active активних',
      few: '$active активні',
      one: '$active активна',
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
  String get emptyStackBody => 'Додайте першу добавку — з каталогу або вручну.';

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
      'Нічого не знайшли в каталозі. Додайте цю добавку вручну.';

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
    return '$on прийому, потім $off перерви — повторюється, поки не вимкнете';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on прийому без перерви — повторюється, поки не вимкнете';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'Один курс без повторення: $start — $end';
  }

  @override
  String get timeSlotsLabel => 'ЧАС ПРИЙОМУ';

  @override
  String slotsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count разу на день',
      many: '$count разів на день',
      few: '$count рази на день',
      one: '$count раз на день',
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
    return 'Найменший інтервал — $h год $m хв.';
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
      'Цикл збережеться в стеку зі статусом «пауза» — у календарі його не буде.';

  @override
  String deleteConfirmTitle(String name) {
    return 'Видалити «$name»?';
  }

  @override
  String get deleteConfirmBody =>
      'Розклад і майбутні дози буде видалено. Історію прийому збережемо.';

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
    return '$done з $total';
  }

  @override
  String get overdueLabel => 'не прийнято вчасно';

  @override
  String get skippedLabel => 'пропущено';

  @override
  String get notMarkedLabel => 'не позначено';

  @override
  String doseCycleChip(int n, int m) {
    return 'доза $n з $m';
  }

  @override
  String ringSemantics(int taken, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$taken з $total доз прийнято',
      many: '$taken з $total доз прийнято',
      few: '$taken з $total доз прийнято',
      one: '$taken з $total дози прийнято',
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count місяці',
      many: '$count місяців',
      few: '$count місяці',
      one: '$count місяць',
    );
    return '$_temp0';
  }

  @override
  String cyclesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count цикли',
      many: '$count циклів',
      few: '$count цикли',
      one: '$count цикл',
    );
    return '$_temp0';
  }

  @override
  String periodsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count періоди',
      many: '$count періодів',
      few: '$count періоди',
      one: '$count період',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return 'Цього тижня одночасно $count';
  }

  @override
  String limitBadge(int max) {
    return 'межа $max';
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
  String loadAxisLegend(int max, int comfort) {
    return 'межа $max · комфорт $comfort';
  }

  @override
  String slotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count слотів',
      many: '$count слотів',
      few: '$count слотів',
      one: '$count слота',
    );
    return '$_temp0';
  }

  @override
  String substancesLimitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count речовини',
      many: '$count речовин',
      few: '$count речовини',
      one: '$count речовину',
    );
    return '$_temp0';
  }

  @override
  String weekLoadLabel(int load, String max) {
    return '$load з $max';
  }

  @override
  String weekFreeSlots(int n) {
    return 'Вільно $n — можна планувати старт';
  }

  @override
  String get weekNoFreeSlots => 'Вільних слотів немає';

  @override
  String get verdictComfort => 'КОМФОРТНО';

  @override
  String get verdictLimit => 'МЕЖА';

  @override
  String get verdictOverLimit => 'ПОНАД МЕЖУ';

  @override
  String get weekNoteComfort =>
      'До трьох речовин одночасно легко відстежувати: якщо щось піде не так, зрозуміло, що саме прибрати.';

  @override
  String get weekNoteLimit =>
      'П\'ять — наша межа за замовчуванням. Вище стає важко відрізнити, що дає ефект, а що — побічні відчуття.';

  @override
  String weekNoteOverLimit(String cycles) {
    return 'Цього тижня перетинаються $cycles. Варто зсунути старт частини з них або обговорити такий обсяг із лікарем.';
  }

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
  String monthMeta(String count, int max) {
    return '$count · межа $max';
  }

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
      'Додайте добавку у вкладці «Стек» — її цикли з\'являться тут.';

  @override
  String get emptyPlannerBodyNoRegimen =>
      'У ваших добавок ще немає розкладу. Відкрийте добавку у вкладці «Стек», щоб задати цикл.';

  @override
  String get plannerLoadError =>
      'Не вдалося завантажити планувальник. Спробуйте ще раз.';

  @override
  String get plannerDisclaimer =>
      'Межа в 5 речовин — наше редакційне правило для зручності відстеження, а не медичний норматив. Освітній матеріал, не медична порада.';

  @override
  String yearFootnote(String max) {
    return 'Рік показує, як цикли накладаються один на одний. Червоне число в місяці означає перевищення нашої межі у $max одночасно.';
  }

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
}
