// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Boostque';

  @override
  String get tabStack => 'Stack';

  @override
  String get tabToday => 'Hoy';

  @override
  String get tabCalendar => 'Calendario';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get navBack => 'Atrás';

  @override
  String get disclaimerEducational =>
      'Material educativo, no es consejo médico.';

  @override
  String substancesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString sustancias',
      one: '$countString sustancia',
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
      other: '$countString semanas',
      one: '$countString semana',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'Mi stack';

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
      other: '$totalString suplementos',
      one: '$totalString suplemento',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$activeString activos',
      one: '$activeString activo',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get supplementsLabel => 'SUPLEMENTOS';

  @override
  String get statusActive => 'ACTIVO';

  @override
  String get statusPaused => 'EN PAUSA';

  @override
  String get statusPlanned => 'PLANIFICADO';

  @override
  String get statusFresh => 'RECIÉN AÑADIDO';

  @override
  String get statusFinished => 'FINALIZADO';

  @override
  String get emptyStackTitle => 'Tu stack está vacío';

  @override
  String get emptyStackBody =>
      'Añade tu primer suplemento con el botón +: desde el catálogo o manualmente.';

  @override
  String get stackLoadError =>
      'No se pudo cargar tu stack. Inténtalo de nuevo.';

  @override
  String get retry => 'Reintentar';

  @override
  String get addSupplement => 'Añadir suplemento';

  @override
  String get close => 'Cerrar';

  @override
  String get searchTab => 'Buscar en catálogo';

  @override
  String get manualTab => 'Manualmente';

  @override
  String get searchCatalogHint => 'Nombre o sustancia activa';

  @override
  String get noResultsCatalog =>
      'No hay coincidencias en el catálogo. Añade este suplemento manualmente.';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get doseLabel => 'Dosis';

  @override
  String get addManualSupplement => 'Añadir suplemento';

  @override
  String get scheduleTitle => 'Horario de tomas';

  @override
  String get pausedBadge => 'EN PAUSA';

  @override
  String get periodicityLabel => 'PERIODICIDAD';

  @override
  String get cyclicTab => 'Cíclico';

  @override
  String get courseTab => 'Periodo único';

  @override
  String get startLabel => 'Inicio';

  @override
  String get endLabel => 'Fin';

  @override
  String get cycleLength => 'Duración del ciclo';

  @override
  String get breakLabel => 'Descanso';

  @override
  String get noBreak => 'sin descanso';

  @override
  String cycleSummaryCyclic(String on, String off) {
    return '$on de toma, luego $off de descanso. Se repite hasta que lo desactives.';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on de toma sin descanso. Se repite hasta que lo desactives.';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'Un periodo único sin repetición: $start — $end';
  }

  @override
  String get timeSlotsLabel => 'HORAS DE TOMA';

  @override
  String slotsPerDay(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString veces al día',
      one: '$countString vez al día',
    );
    return '$_temp0';
  }

  @override
  String get addTimeSlot => '+ Añadir hora';

  @override
  String removeSlot(String time) {
    return 'Eliminar la hora $time';
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

    return 'Intervalo más corto — $hString h $mString min.';
  }

  @override
  String get slotIntervalSingle => 'Una hora al día.';

  @override
  String get saveAndStart => 'Añadir e iniciar el ciclo';

  @override
  String get saveWhilePaused => 'Guardar, ciclo en pausa';

  @override
  String get pause => 'Pausar';

  @override
  String get resume => 'Reanudar el ciclo';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String saveHintActive(String start) {
    return 'Las horas aparecerán en el calendario desde el $start. La pausa las quita sin borrar tus ajustes.';
  }

  @override
  String get saveHintPaused =>
      'El ciclo se guarda en tu stack en pausa, así que no aparecerá en el calendario.';

  @override
  String deleteConfirmTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get deleteConfirmBody =>
      'Al eliminar se quitan el horario y las dosis futuras. Tu historial de tomas se conserva.';

  @override
  String get saveFailed => 'No se pudo guardar. Inténtalo de nuevo.';

  @override
  String get catalogAshwagandhaName => 'Ashwagandha KSM-66';

  @override
  String get catalogAshwagandhaDose => '300 mg · cápsulas';

  @override
  String get catalogCreatineName => 'Creatina monohidrato';

  @override
  String get catalogCreatineDose => '5 g · polvo';

  @override
  String get catalogMelatoninName => 'Melatonina 3 mg';

  @override
  String get catalogMelatoninDose => '3 mg · comprimidos';

  @override
  String get catalogNmnName => 'NMN 250 mg';

  @override
  String get catalogNmnDose => '250 mg · cápsulas';

  @override
  String get catalogB12Name => 'Vitamina B12 metilcobalamina';

  @override
  String get catalogB12Dose => '1000 mcg · comprimidos';

  @override
  String get catalogQ10Name => 'Coenzima Q10 ubiquinol';

  @override
  String get catalogQ10Dose => '100 mg · cápsulas';

  @override
  String get catalogIodineName => 'Yodo 150 mcg';

  @override
  String get catalogIodineDose => '150 mcg · comprimidos';

  @override
  String get catalogIronName => 'Hierro bisglicinato';

  @override
  String get catalogIronDose => '25 mg · cápsulas';

  @override
  String get catalogHypericumName => 'Hipérico';

  @override
  String get catalogHypericumDose => 'extracto 300 mg · cápsulas';

  @override
  String get catalogMagnesiumName => 'Magnesio bisglicinato';

  @override
  String get catalogMagnesiumDose => '400 mg · cápsulas';

  @override
  String get catalogChondroName => 'Condroprotector';

  @override
  String get catalogChondroDose => 'glucosamina 500 + condroitina 400';

  @override
  String get catalogD3Name => 'Vitamina D3';

  @override
  String get catalogD3Dose => '2000 UI · gotas';

  @override
  String get catalogOmega3Name => 'Omega-3';

  @override
  String get catalogOmega3Dose => 'EPA 500 / DHA 250';

  @override
  String get catalogZincName => 'Zinc picolinato';

  @override
  String get catalogZincDose => '15 mg · comprimidos';

  @override
  String get catalogCurcuminName => 'Curcumina';

  @override
  String get catalogCurcuminDose => '500 mg + piperina';

  @override
  String get calendarTitleToday => 'Hoy';

  @override
  String get blockMorning => 'Mañana';

  @override
  String get blockDay => 'Día';

  @override
  String get blockEvening => 'Tarde';

  @override
  String get blockNight => 'Noche';

  @override
  String get blockTagBreakfast => 'con el desayuno';

  @override
  String get blockTagLunch => 'con el almuerzo';

  @override
  String get blockTagDinner => 'con la cena';

  @override
  String get blockTagSleep => 'antes de dormir';

  @override
  String get blockAllTaken => 'todo tomado';

  @override
  String get blockAllMarked => 'todo marcado';

  @override
  String blockProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString de $totalString';
  }

  @override
  String get overdueLabel => 'no tomado a tiempo';

  @override
  String get skippedLabel => 'omitida';

  @override
  String get notMarkedLabel => 'sin marcar';

  @override
  String get plannedLabel => 'planificada';

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

    return 'dosis $nString de $mString';
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
      other: '$takenString de $totalString dosis tomadas',
      one: '$takenString de $totalString dosis tomada',
    );
    return '$_temp0';
  }

  @override
  String get markTaken => 'Marcar como tomada';

  @override
  String get markSkipped => 'Marcar como omitida';

  @override
  String get undoMark => 'Quitar la marca';

  @override
  String get backToToday => 'Hoy';

  @override
  String doseSheetSubtitle(String time, String dose) {
    return '$time · $dose';
  }

  @override
  String doseSheetSubtitleTimeOnly(String time) {
    return '$time';
  }

  @override
  String get emptyDayTitle => 'No hay dosis este día';

  @override
  String get emptyDayBody => 'Ningún ciclo está activo este día.';

  @override
  String get emptyDayBodyNoStack =>
      'Añade un suplemento en la pestaña «Stack» para ver dosis aquí.';

  @override
  String get dayLoadError => 'No se pudo cargar este día. Inténtalo de nuevo.';

  @override
  String get markFailed => 'No se pudo guardar la marca.';

  @override
  String get calendarDisclaimer =>
      'Este horario se construye con tus propios registros. Material educativo, no es consejo médico.';

  @override
  String get plannerTitle => 'Planificador';

  @override
  String get plannerSegYear => 'Año';

  @override
  String get plannerSegCycles => 'Ciclos';

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
      other: '$countString meses',
      one: '$countString mes',
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
      other: '$countString periodos',
      one: '$countString periodo',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return '$count a la vez esta semana';
  }

  @override
  String get legendTaking => 'tomando';

  @override
  String get legendPlanned => 'planificado';

  @override
  String get legendPaused => 'en pausa';

  @override
  String get loadChartTitle => 'CARGA SIMULTÁNEA';

  @override
  String get loadChartMeta => 'por semana';

  @override
  String get loadScaleCaption => 'barra completa = todo tu stack';

  @override
  String peakMonth(String month) {
    return 'Mes más denso — $month';
  }

  @override
  String peakMonthsTie(String month) {
    return 'Meses más densos, entre ellos $month';
  }

  @override
  String get yearLegendHint => 'más claro = planificado';

  @override
  String get monthStateTaking => 'tomando';

  @override
  String get monthStatePlanned => 'planificado';

  @override
  String get monthStatePartial => 'parte del mes';

  @override
  String get monthEmpty => 'Ningún ciclo está activo este mes.';

  @override
  String get emptyPlannerTitle => 'Todavía no hay nada que planificar';

  @override
  String get emptyPlannerBody =>
      'Añade un suplemento en la pestaña «Stack» y sus ciclos aparecerán aquí.';

  @override
  String get emptyPlannerBodyNoRegimen =>
      'Tus suplementos aún no tienen horario. Abre uno en la pestaña «Stack» para definir un ciclo.';

  @override
  String get plannerLoadError =>
      'No se pudo cargar el planificador. Inténtalo de nuevo.';

  @override
  String get plannerDisclaimer =>
      'El planificador muestra cómo se solapan tus ciclos en el tiempo. Material educativo, no es consejo médico.';

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
  String get languageName => 'Español';

  @override
  String get languageSystem => 'Idioma del sistema';

  @override
  String get settingsLanguageTitle => 'IDIOMA';

  @override
  String get settingsRemindersTitle => 'RECORDATORIOS';

  @override
  String get settingsRemindersAllowed => 'Los recordatorios están permitidos';

  @override
  String get settingsRemindersBlocked =>
      'Los recordatorios no están permitidos';

  @override
  String get settingsRemindersOpenSystem => 'Abrir los ajustes del sistema';

  @override
  String get doseReminderTitle => 'Hora de tus dosis';

  @override
  String doseReminderBody(int count, String time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString dosis',
      one: '$countString dosis',
    );
    return '$time · $_temp0';
  }

  @override
  String get doseChannelName => 'Recordatorios de dosis';

  @override
  String get doseChannelDescription =>
      'Un recordatorio por cada hora de toma de tu horario.';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingAddFirst => 'Añadir mi primer suplemento';

  @override
  String get onboardingPage1Title => 'Tu stack, día a día';

  @override
  String get onboardingPage1Body =>
      'Planifica qué tomar y marca lo que ya has tomado. «Hoy» muestra solo lo previsto para hoy.';

  @override
  String get onboardingIllustrationSemantics1 =>
      'Ejemplo de lista de dosis: una marcada como tomada, otra pendiente';

  @override
  String get hintDismiss => 'Entendido';

  @override
  String get hintCycle =>
      'Un ciclo son semanas de toma más un descanso. Ajústalos con los controles de abajo y la app calcula qué días llevan dosis.';

  @override
  String get hintMarkDose =>
      'Toca una dosis para marcarla como tomada. Mantén pulsado para ver las demás opciones.';

  @override
  String get debugResetOnboarding => 'Restablecer la introducción y las pistas';

  @override
  String get onboardingPage2Title => 'El calendario lo ve todo a la vez';

  @override
  String get onboardingPage2Body =>
      'El calendario muestra en qué punto de cada ciclo estás, qué se solapa con qué y cuándo empieza el próximo descanso.';

  @override
  String get onboardingIllustrationSemantics2 =>
      'Ejemplo de calendario: tres suplementos cuyas semanas de toma se solapan en parte';

  @override
  String get onboardingNext => 'Siguiente';
}
