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
}
