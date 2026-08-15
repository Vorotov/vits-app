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
}
