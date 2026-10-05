// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'VitoMy';

  @override
  String get tabStack => 'स्टैक';

  @override
  String get tabToday => 'आज';

  @override
  String get tabCalendar => 'कैलेंडर';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get navBack => 'वापस';

  @override
  String get disclaimerEducational => 'शैक्षिक सामग्री, चिकित्सकीय सलाह नहीं।';

  @override
  String substancesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString पदार्थ',
      one: '$countString पदार्थ',
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
      other: '$countString सप्ताह',
      one: '$countString सप्ताह',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'मेरा स्टैक';

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
      other: '$totalString सप्लीमेंट',
      one: '$totalString सप्लीमेंट',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$activeString सक्रिय',
      one: '$activeString सक्रिय',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get supplementsLabel => 'सप्लीमेंट';

  @override
  String get statusActive => 'सक्रिय';

  @override
  String get statusPaused => 'रुका हुआ';

  @override
  String get statusPlanned => 'नियोजित';

  @override
  String get statusFresh => 'अभी जोड़ा';

  @override
  String get statusFinished => 'पूरा हुआ';

  @override
  String get emptyStackTitle => 'आपका स्टैक खाली है';

  @override
  String get emptyStackBody =>
      '+ बटन से अपना पहला सप्लीमेंट जोड़ें: कैटलॉग से या मैन्युअल रूप से।';

  @override
  String get stackLoadError => 'स्टैक लोड नहीं हो सका। फिर से कोशिश करें।';

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get addSupplement => 'सप्लीमेंट जोड़ें';

  @override
  String get close => 'बंद करें';

  @override
  String get searchTab => 'कैटलॉग खोजें';

  @override
  String get manualTab => 'मैन्युअल रूप से जोड़ें';

  @override
  String get searchCatalogHint => 'नाम या सक्रिय पदार्थ';

  @override
  String get noResultsCatalog =>
      'कैटलॉग में कुछ नहीं मिला। इस सप्लीमेंट को मैन्युअल रूप से जोड़ें।';

  @override
  String get nameLabel => 'नाम';

  @override
  String get doseLabel => 'खुराक';

  @override
  String get addManualSupplement => 'सप्लीमेंट जोड़ें';

  @override
  String get scheduleTitle => 'खुराक शेड्यूल';

  @override
  String get pausedBadge => 'रुका हुआ';

  @override
  String get periodicityLabel => 'आवृत्ति';

  @override
  String get cyclicTab => 'चक्रीय';

  @override
  String get courseTab => 'एक बार का कोर्स';

  @override
  String get startLabel => 'शुरू';

  @override
  String get endLabel => 'समाप्त';

  @override
  String get cycleLength => 'चक्र की लंबाई';

  @override
  String get breakLabel => 'ब्रेक';

  @override
  String get noBreak => 'कोई ब्रेक नहीं';

  @override
  String cycleSummaryCyclic(String on, String off) {
    return '$on लेना, फिर $off का ब्रेक। आपके बंद करने तक दोहराता रहेगा।';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on बिना ब्रेक के लेना। आपके बंद करने तक दोहराता रहेगा।';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'बिना दोहराव का एक कोर्स: $start — $end';
  }

  @override
  String get timeSlotsLabel => 'खुराक का समय';

  @override
  String slotsPerDay(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'दिन में $countString बार',
      one: 'दिन में $countString बार',
    );
    return '$_temp0';
  }

  @override
  String get addTimeSlot => '+ समय स्लॉट जोड़ें';

  @override
  String removeSlot(String time) {
    return 'स्लॉट $time हटाएँ';
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

    return 'सबसे छोटा अंतराल — $hString घं $mString मि।';
  }

  @override
  String get slotIntervalSingle => 'दिन में एक स्लॉट।';

  @override
  String get saveAndStart => 'जोड़ें और चक्र शुरू करें';

  @override
  String get saveWhilePaused => 'सहेजें, चक्र रुका हुआ';

  @override
  String get saveChanges => 'सहेजें';

  @override
  String get pause => 'रोकें';

  @override
  String get resume => 'चक्र फिर से शुरू करें';

  @override
  String get delete => 'हटाएँ';

  @override
  String get cancel => 'रद्द करें';

  @override
  String saveHintActive(String start) {
    return 'स्लॉट कैलेंडर में $start से दिखेंगे। रोकने पर वे हट जाते हैं, आपकी सेटिंग्स नहीं मिटतीं।';
  }

  @override
  String get saveHintPaused =>
      'चक्र आपके स्टैक में रुके हुए के रूप में सहेजा जाता है, इसलिए कैलेंडर में नहीं दिखेगा।';

  @override
  String deleteConfirmTitle(String name) {
    return '“$name” हटाएँ?';
  }

  @override
  String get deleteConfirmBody =>
      'हटाने से शेड्यूल और आगे की खुराकें हट जाती हैं। आपका सेवन इतिहास बना रहता है।';

  @override
  String get saveFailed => 'सहेजा नहीं जा सका। फिर से कोशिश करें।';

  @override
  String get catalogAshwagandhaName => 'अश्वगंधा KSM-66';

  @override
  String get catalogAshwagandhaDose => '300 mg · कैप्सूल';

  @override
  String get catalogCreatineName => 'क्रिएटिन मोनोहाइड्रेट';

  @override
  String get catalogCreatineDose => '5 g · पाउडर';

  @override
  String get catalogMelatoninName => 'मेलाटोनिन 3 mg';

  @override
  String get catalogMelatoninDose => '3 mg · गोलियाँ';

  @override
  String get catalogNmnName => 'NMN 250 mg';

  @override
  String get catalogNmnDose => '250 mg · कैप्सूल';

  @override
  String get catalogB12Name => 'विटामिन B12 मिथाइलकोबालामिन';

  @override
  String get catalogB12Dose => '1000 mcg · गोलियाँ';

  @override
  String get catalogQ10Name => 'कोएंजाइम Q10 यूबिक्विनॉल';

  @override
  String get catalogQ10Dose => '100 mg · कैप्सूल';

  @override
  String get catalogIodineName => 'आयोडीन 150 mcg';

  @override
  String get catalogIodineDose => '150 mcg · गोलियाँ';

  @override
  String get catalogIronName => 'आयरन बिसग्लाइसिनेट';

  @override
  String get catalogIronDose => '25 mg · कैप्सूल';

  @override
  String get catalogHypericumName => 'सेंट जॉन्स वॉर्ट';

  @override
  String get catalogHypericumDose => 'अर्क 300 mg · कैप्सूल';

  @override
  String get catalogMagnesiumName => 'मैग्नीशियम बिसग्लाइसिनेट';

  @override
  String get catalogMagnesiumDose => '400 mg · कैप्सूल';

  @override
  String get catalogChondroName => 'कॉन्ड्रोप्रोटेक्टर';

  @override
  String get catalogChondroDose => 'ग्लूकोसामाइन 500 + कॉन्ड्रोइटिन 400';

  @override
  String get catalogD3Name => 'विटामिन D3';

  @override
  String get catalogD3Dose => '2000 IU · ड्रॉप्स';

  @override
  String get catalogOmega3Name => 'ओमेगा-3';

  @override
  String get catalogOmega3Dose => 'EPA 500 / DHA 250';

  @override
  String get catalogZincName => 'ज़िंक पिकोलिनेट';

  @override
  String get catalogZincDose => '15 mg · गोलियाँ';

  @override
  String get catalogCurcuminName => 'कर्क्यूमिन';

  @override
  String get catalogCurcuminDose => '500 mg + पिपेरिन';

  @override
  String get calendarTitleToday => 'आज';

  @override
  String get blockMorning => 'सुबह';

  @override
  String get blockDay => 'दोपहर';

  @override
  String get blockEvening => 'शाम';

  @override
  String get blockNight => 'रात';

  @override
  String get blockTagBreakfast => 'नाश्ते के साथ';

  @override
  String get blockTagLunch => 'लंच के साथ';

  @override
  String get blockTagDinner => 'डिनर के साथ';

  @override
  String get blockTagSleep => 'सोने से पहले';

  @override
  String get blockAllTaken => 'सब ले लिया';

  @override
  String get blockAllMarked => 'सब चिह्नित';

  @override
  String blockProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$totalString में से $doneString';
  }

  @override
  String get overdueLabel => 'समय पर नहीं लिया';

  @override
  String get skippedLabel => 'छोड़ा गया';

  @override
  String get notMarkedLabel => 'चिह्नित नहीं';

  @override
  String get plannedLabel => 'नियोजित';

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

    return 'खुराक $nString, कुल $mString';
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
      other: '$totalString में से $takenString खुराकें ली गईं',
      one: '$totalString में से $takenString खुराक ली गई',
    );
    return '$_temp0';
  }

  @override
  String get markTaken => 'लिया हुआ चिह्नित करें';

  @override
  String get markSkipped => 'छोड़ा हुआ चिह्नित करें';

  @override
  String get undoMark => 'चिह्न हटाएँ';

  @override
  String get backToToday => 'आज';

  @override
  String doseSheetSubtitle(String time, String dose) {
    return '$time · $dose';
  }

  @override
  String doseSheetSubtitleTimeOnly(String time) {
    return '$time';
  }

  @override
  String get emptyDayTitle => 'इस दिन कोई खुराक नहीं';

  @override
  String get emptyDayBody => 'इस दिन कोई चक्र सक्रिय नहीं है।';

  @override
  String get emptyDayBodyNoStack =>
      'यहाँ खुराकें देखने के लिए स्टैक टैब में एक सप्लीमेंट जोड़ें।';

  @override
  String get dayLoadError => 'यह दिन लोड नहीं हो सका। फिर से कोशिश करें।';

  @override
  String get markFailed => 'चिह्न सहेजा नहीं जा सका।';

  @override
  String get calendarDisclaimer =>
      'यह शेड्यूल आपकी अपनी प्रविष्टियों से बना है। शैक्षिक सामग्री, चिकित्सकीय सलाह नहीं।';

  @override
  String get plannerTitle => 'प्लानर';

  @override
  String get plannerSegYear => 'वर्ष';

  @override
  String get plannerSegCycles => 'चक्र';

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
      other: '$countString महीने',
      one: '$countString महीना',
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
      other: '$countString अवधियाँ',
      one: '$countString अवधि',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return 'इस सप्ताह एक साथ $count';
  }

  @override
  String get legendTaking => 'ले रहे हैं';

  @override
  String get legendPlanned => 'नियोजित';

  @override
  String get legendPaused => 'रुका हुआ';

  @override
  String get loadChartTitle => 'एक साथ भार';

  @override
  String get loadChartMeta => 'सप्ताह के अनुसार';

  @override
  String get loadScaleCaption => 'पूरा बार = आपका पूरा स्टैक';

  @override
  String peakMonth(String month) {
    return 'सबसे घना महीना — $month';
  }

  @override
  String peakMonthsTie(String month) {
    return 'सबसे घने महीने, जिनमें $month शामिल है';
  }

  @override
  String get yearLegendHint => 'हल्का = नियोजित';

  @override
  String get monthStateTaking => 'ले रहे हैं';

  @override
  String get monthStatePlanned => 'नियोजित';

  @override
  String get monthStatePartial => 'महीने का हिस्सा';

  @override
  String get monthEmpty => 'इस महीने कोई चक्र सक्रिय नहीं है।';

  @override
  String get emptyPlannerTitle => 'अभी योजना बनाने को कुछ नहीं';

  @override
  String get emptyPlannerBody =>
      'स्टैक टैब में एक सप्लीमेंट जोड़ें और उसके चक्र यहाँ दिखेंगे।';

  @override
  String get emptyPlannerBodyNoRegimen =>
      'आपके सप्लीमेंट का अभी कोई शेड्यूल नहीं है। चक्र तय करने के लिए स्टैक टैब में कोई एक खोलें।';

  @override
  String get plannerLoadError => 'प्लानर लोड नहीं हो सका। फिर से कोशिश करें।';

  @override
  String get plannerDisclaimer =>
      'प्लानर दिखाता है कि आपके चक्र समय के साथ कैसे आपस में मिलते हैं। शैक्षिक सामग्री, चिकित्सकीय सलाह नहीं।';

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
  String get languageName => 'हिन्दी';

  @override
  String get languageSystem => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get settingsLanguageTitle => 'भाषा';

  @override
  String get settingsRemindersTitle => 'रिमाइंडर';

  @override
  String get settingsRemindersAllowed => 'रिमाइंडर की अनुमति है';

  @override
  String get settingsRemindersBlocked => 'रिमाइंडर की अनुमति नहीं है';

  @override
  String get settingsRemindersOpenSystem => 'सिस्टम सेटिंग्स खोलें';

  @override
  String get doseReminderTitle => 'खुराक का समय';

  @override
  String doseReminderBody(int count, String time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString खुराकें',
      one: '$countString खुराक',
    );
    return '$time · $_temp0';
  }

  @override
  String get doseChannelName => 'खुराक रिमाइंडर';

  @override
  String get doseChannelDescription =>
      'आपके शेड्यूल के हर खुराक समय के लिए एक रिमाइंडर।';

  @override
  String get onboardingSkip => 'छोड़ें';

  @override
  String get onboardingAddFirst => 'अपना पहला सप्लीमेंट जोड़ें';

  @override
  String get onboardingPage1Title => 'आपका स्टैक, दिन-ब-दिन';

  @override
  String get onboardingPage1Body =>
      'योजना बनाएँ कि क्या लेना है, और जो लिया उसे चिह्नित करें। आज सिर्फ़ वही दिखाता है जो आज चाहिए।';

  @override
  String get onboardingIllustrationSemantics1 =>
      'खुराक सूची का उदाहरण: एक लिया हुआ चिह्नित, एक बाकी';

  @override
  String get hintDismiss => 'समझ गया';

  @override
  String get hintCycle =>
      'चक्र यानी लेने के सप्ताह और एक ब्रेक। नीचे स्लाइडर से इन्हें तय करें, ऐप खुद हिसाब लगा लेगा कि किन दिनों खुराक चाहिए।';

  @override
  String get hintMarkDose =>
      'खुराक को लिया हुआ चिह्नित करने के लिए उस पर टैप करें। बाकी विकल्पों के लिए दबाकर रखें।';

  @override
  String get settingsShowIntroAgain => 'परिचय और संकेत रीसेट करें';

  @override
  String get onboardingPage2Title => 'कैलेंडर सब कुछ एक साथ देखता है';

  @override
  String get onboardingPage2Body =>
      'कैलेंडर दिखाता है कि आप हर चक्र में कहाँ हैं, क्या किससे मिलता है, और अगला ब्रेक कब शुरू होता है।';

  @override
  String get onboardingIllustrationSemantics2 =>
      'कैलेंडर का उदाहरण: तीन सप्लीमेंट जिनके लेने के सप्ताह आंशिक रूप से मिलते हैं';

  @override
  String get onboardingNext => 'आगे';

  @override
  String get settingsSupportRow => 'डेवलपर को सहयोग दें';

  @override
  String get supportTitle => 'डेवलपर को सहयोग दें';

  @override
  String get supportBody =>
      'VitoMy को एक ही व्यक्ति बनाता है। यहाँ न विज्ञापन हैं और न कोई खाता, और आपकी सूची कहीं नहीं भेजी जाती। टिप यह कहने का एक तरीका है कि ऐप रखने लायक है। इससे कुछ नहीं खुलता, और उसके बाद कुछ नहीं बदलता।';

  @override
  String get supportTipSmall => 'छोटी टिप';

  @override
  String get supportTipMedium => 'मध्यम टिप';

  @override
  String get supportTipLarge => 'बड़ी टिप';

  @override
  String get supportThanks => 'धन्यवाद। यह बहुत मायने रखता है।';

  @override
  String get supportUnavailable =>
      'टिप अभी उपलब्ध नहीं हैं। कनेक्शन जाँचें और बाद में फिर कोशिश करें।';

  @override
  String get supportFailed => 'यह पूरा नहीं हुआ। कोई राशि नहीं ली गई।';
}
