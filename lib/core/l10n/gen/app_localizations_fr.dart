// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'VitoMy';

  @override
  String get tabStack => 'Stack';

  @override
  String get tabToday => 'Aujourd\'hui';

  @override
  String get tabCalendar => 'Calendrier';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get navBack => 'Retour';

  @override
  String get disclaimerEducational => 'Contenu éducatif, pas un avis médical.';

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
      other: '$countString semaines',
      one: '$countString semaine',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'Mon stack';

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
      other: '$totalString compléments',
      one: '$totalString complément',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$activeString actifs',
      one: '$activeString actif',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get supplementsLabel => 'COMPLÉMENTS';

  @override
  String get statusActive => 'ACTIF';

  @override
  String get statusPaused => 'EN PAUSE';

  @override
  String get statusPlanned => 'PLANIFIÉ';

  @override
  String get statusFresh => 'JUSTE AJOUTÉ';

  @override
  String get statusFinished => 'TERMINÉ';

  @override
  String get emptyStackTitle => 'Votre stack est vide';

  @override
  String get emptyStackBody =>
      'Ajoutez votre premier complément avec le bouton + : depuis le catalogue ou manuellement.';

  @override
  String get stackLoadError => 'Impossible de charger votre stack. Réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get addSupplement => 'Ajouter un complément';

  @override
  String get close => 'Fermer';

  @override
  String get searchTab => 'Rechercher';

  @override
  String get manualTab => 'Manuellement';

  @override
  String get searchCatalogHint => 'Nom ou substance active';

  @override
  String get noResultsCatalog =>
      'Aucun résultat dans le catalogue. Ajoutez ce complément manuellement.';

  @override
  String get nameLabel => 'Nom';

  @override
  String get doseLabel => 'Dose';

  @override
  String get addManualSupplement => 'Ajouter un complément';

  @override
  String get scheduleTitle => 'Horaires de prise';

  @override
  String get pausedBadge => 'EN PAUSE';

  @override
  String get periodicityLabel => 'PÉRIODICITÉ';

  @override
  String get cyclicTab => 'Cyclique';

  @override
  String get courseTab => 'Cure unique';

  @override
  String get startLabel => 'Début';

  @override
  String get endLabel => 'Fin';

  @override
  String get cycleLength => 'Durée du cycle';

  @override
  String get breakLabel => 'Repos';

  @override
  String get noBreak => 'sans repos';

  @override
  String cycleSummaryCyclic(String on, String off) {
    return '$on de prise, puis $off de repos. Se répète jusqu\'à ce que vous l\'arrêtiez.';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on de prise sans repos. Se répète jusqu\'à ce que vous l\'arrêtiez.';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'Une cure unique sans répétition : $start — $end';
  }

  @override
  String get timeSlotsLabel => 'HEURES DE PRISE';

  @override
  String slotsPerDay(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString fois par jour',
      one: '$countString fois par jour',
    );
    return '$_temp0';
  }

  @override
  String get addTimeSlot => '+ Ajouter une heure';

  @override
  String removeSlot(String time) {
    return 'Supprimer l\'heure $time';
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

    return 'Intervalle le plus court — $hString h $mString min.';
  }

  @override
  String get slotIntervalSingle => 'Une seule heure par jour.';

  @override
  String get saveAndStart => 'Ajouter et lancer le cycle';

  @override
  String get saveWhilePaused => 'Enregistrer, cycle en pause';

  @override
  String get saveChanges => 'Enregistrer';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre le cycle';

  @override
  String get delete => 'Supprimer';

  @override
  String get cancel => 'Annuler';

  @override
  String saveHintActive(String start) {
    return 'Les doses apparaîtront dans le calendrier à partir du $start. La pause les retire sans supprimer vos réglages.';
  }

  @override
  String get saveHintPaused =>
      'Le cycle est enregistré dans votre stack en pause : il n\'apparaîtra pas dans le calendrier.';

  @override
  String deleteConfirmTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteConfirmBody =>
      'La suppression retire les horaires et les doses à venir. Votre historique de prises est conservé.';

  @override
  String get saveFailed => 'Impossible d\'enregistrer. Réessayez.';

  @override
  String get catalogAshwagandhaName => 'Ashwagandha KSM-66';

  @override
  String get catalogAshwagandhaDose => '300 mg · gélules';

  @override
  String get catalogCreatineName => 'Créatine monohydrate';

  @override
  String get catalogCreatineDose => '5 g · poudre';

  @override
  String get catalogMelatoninName => 'Mélatonine 3 mg';

  @override
  String get catalogMelatoninDose => '3 mg · comprimés';

  @override
  String get catalogNmnName => 'NMN 250 mg';

  @override
  String get catalogNmnDose => '250 mg · gélules';

  @override
  String get catalogB12Name => 'Vitamine B12 méthylcobalamine';

  @override
  String get catalogB12Dose => '1000 mcg · comprimés';

  @override
  String get catalogQ10Name => 'Coenzyme Q10 ubiquinol';

  @override
  String get catalogQ10Dose => '100 mg · gélules';

  @override
  String get catalogIodineName => 'Iode 150 mcg';

  @override
  String get catalogIodineDose => '150 mcg · comprimés';

  @override
  String get catalogIronName => 'Fer bisglycinate';

  @override
  String get catalogIronDose => '25 mg · gélules';

  @override
  String get catalogHypericumName => 'Millepertuis';

  @override
  String get catalogHypericumDose => 'extrait 300 mg · gélules';

  @override
  String get catalogMagnesiumName => 'Magnésium bisglycinate';

  @override
  String get catalogMagnesiumDose => '400 mg · gélules';

  @override
  String get catalogChondroName => 'Chondroprotecteur';

  @override
  String get catalogChondroDose => 'glucosamine 500 + chondroïtine 400';

  @override
  String get catalogD3Name => 'Vitamine D3';

  @override
  String get catalogD3Dose => '2000 UI · gouttes';

  @override
  String get catalogOmega3Name => 'Oméga-3';

  @override
  String get catalogOmega3Dose => 'EPA 500 / DHA 250';

  @override
  String get catalogZincName => 'Zinc picolinate';

  @override
  String get catalogZincDose => '15 mg · comprimés';

  @override
  String get catalogCurcuminName => 'Curcumine';

  @override
  String get catalogCurcuminDose => '500 mg + pipérine';

  @override
  String get calendarTitleToday => 'Aujourd\'hui';

  @override
  String get blockMorning => 'Matin';

  @override
  String get blockDay => 'Après-midi';

  @override
  String get blockEvening => 'Soir';

  @override
  String get blockNight => 'Nuit';

  @override
  String get blockTagBreakfast => 'au petit-déjeuner';

  @override
  String get blockTagLunch => 'au déjeuner';

  @override
  String get blockTagDinner => 'au dîner';

  @override
  String get blockTagSleep => 'avant le coucher';

  @override
  String get blockAllTaken => 'tout pris';

  @override
  String get blockAllMarked => 'tout marqué';

  @override
  String blockProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString sur $totalString';
  }

  @override
  String get overdueLabel => 'pas prise à l\'heure';

  @override
  String get skippedLabel => 'sautée';

  @override
  String get notMarkedLabel => 'non marquée';

  @override
  String get plannedLabel => 'prévue';

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

    return 'dose $nString sur $mString';
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
      other: '$takenString doses sur $totalString prises',
      one: '$takenString dose sur $totalString prise',
    );
    return '$_temp0';
  }

  @override
  String get markTaken => 'Marquer comme prise';

  @override
  String get markSkipped => 'Marquer comme sautée';

  @override
  String get undoMark => 'Retirer la marque';

  @override
  String get backToToday => 'Aujourd\'hui';

  @override
  String doseSheetSubtitle(String time, String dose) {
    return '$time · $dose';
  }

  @override
  String doseSheetSubtitleTimeOnly(String time) {
    return '$time';
  }

  @override
  String get emptyDayTitle => 'Aucune dose ce jour-là';

  @override
  String get emptyDayBody => 'Aucun cycle n\'est actif ce jour-là.';

  @override
  String get emptyDayBodyNoStack =>
      'Ajoutez un complément dans l\'onglet « Stack » pour voir des doses ici.';

  @override
  String get dayLoadError => 'Impossible de charger ce jour. Réessayez.';

  @override
  String get markFailed => 'Impossible d\'enregistrer la marque.';

  @override
  String get calendarDisclaimer =>
      'Ce planning est établi à partir de vos propres saisies. Contenu éducatif, pas un avis médical.';

  @override
  String get plannerTitle => 'Planificateur';

  @override
  String get plannerSegYear => 'Année';

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
      other: '$countString mois',
      one: '$countString mois',
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
      other: '$countString périodes',
      one: '$countString période',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return '$count en même temps cette semaine';
  }

  @override
  String get legendTaking => 'en cours';

  @override
  String get legendPlanned => 'prévu';

  @override
  String get legendPaused => 'en pause';

  @override
  String get loadChartTitle => 'CHARGE SIMULTANÉE';

  @override
  String get loadChartMeta => 'par semaine';

  @override
  String get loadScaleCaption => 'barre pleine = tout votre stack';

  @override
  String peakMonth(String month) {
    return 'Mois le plus dense — $month';
  }

  @override
  String peakMonthsTie(String month) {
    return 'Mois les plus denses, dont $month';
  }

  @override
  String get yearLegendHint => 'plus clair = prévu';

  @override
  String get monthStateTaking => 'en cours';

  @override
  String get monthStatePlanned => 'prévu';

  @override
  String get monthStatePartial => 'une partie du mois';

  @override
  String get monthEmpty => 'Aucun cycle n\'est actif ce mois-ci.';

  @override
  String get emptyPlannerTitle => 'Rien à planifier pour l\'instant';

  @override
  String get emptyPlannerBody =>
      'Ajoutez un complément dans l\'onglet « Stack » et ses cycles apparaîtront ici.';

  @override
  String get emptyPlannerBodyNoRegimen =>
      'Vos compléments n\'ont pas encore d\'horaires. Ouvrez-en un dans l\'onglet « Stack » pour définir un cycle.';

  @override
  String get plannerLoadError =>
      'Impossible de charger le planificateur. Réessayez.';

  @override
  String get plannerDisclaimer =>
      'Le planificateur montre comment vos cycles se chevauchent dans le temps. Contenu éducatif, pas un avis médical.';

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
    return '$action : $name';
  }

  @override
  String get languageName => 'Français';

  @override
  String get languageSystem => 'Langue du système';

  @override
  String get settingsLanguageTitle => 'LANGUE';

  @override
  String get settingsRemindersTitle => 'RAPPELS';

  @override
  String get settingsRemindersAllowed => 'Les rappels sont autorisés';

  @override
  String get settingsRemindersBlocked => 'Les rappels ne sont pas autorisés';

  @override
  String get settingsRemindersOpenSystem => 'Ouvrir les paramètres système';

  @override
  String get doseReminderTitle => 'Heure de vos doses';

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
  String get doseChannelName => 'Rappels de dose';

  @override
  String get doseChannelDescription =>
      'Un rappel pour chaque heure de prise de vos horaires.';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingAddFirst => 'Ajouter mon premier complément';

  @override
  String get onboardingPage1Title => 'Votre stack, jour après jour';

  @override
  String get onboardingPage1Body =>
      'Planifiez ce que vous prenez et marquez ce que vous avez pris. « Aujourd\'hui » n\'affiche que ce qui est prévu pour aujourd\'hui.';

  @override
  String get onboardingIllustrationSemantics1 =>
      'Exemple de liste de doses : une marquée comme prise, une en attente';

  @override
  String get hintDismiss => 'J\'ai compris';

  @override
  String get hintCycle =>
      'Un cycle, ce sont des semaines de prise plus un repos. Réglez-les avec les curseurs ci-dessous et l\'application calcule quels jours comportent une dose.';

  @override
  String get hintMarkDose =>
      'Touchez une dose pour la marquer comme prise. Appuyez longuement pour les autres options.';

  @override
  String get settingsShowIntroAgain => 'Réinitialiser l\'intro et les astuces';

  @override
  String get onboardingPage2Title => 'Le calendrier voit tout en même temps';

  @override
  String get onboardingPage2Body =>
      'Le calendrier montre où vous en êtes dans chaque cycle, ce qui se chevauche avec quoi et quand commence le prochain repos.';

  @override
  String get onboardingIllustrationSemantics2 =>
      'Exemple de calendrier : trois compléments dont les semaines de prise se chevauchent en partie';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get settingsSupportRow => 'Soutenir le développeur';

  @override
  String get supportTitle => 'Soutenir le développeur';

  @override
  String get supportBody =>
      'VitoMy est fait par une seule personne. Pas de publicité, pas de compte, et votre liste n\'est envoyée nulle part. Un pourboire est une façon de dire que l\'application mérite d\'être gardée. Il ne débloque rien et rien ne change ensuite.';

  @override
  String get supportTipSmall => 'Petit pourboire';

  @override
  String get supportTipMedium => 'Pourboire moyen';

  @override
  String get supportTipLarge => 'Gros pourboire';

  @override
  String get supportThanks => 'Merci. Cela compte beaucoup.';

  @override
  String get supportUnavailable =>
      'Les pourboires ne sont pas disponibles pour le moment. Vérifiez la connexion et réessayez plus tard.';

  @override
  String get supportFailed => 'Cela n\'a pas abouti. Rien n\'a été débité.';
}
