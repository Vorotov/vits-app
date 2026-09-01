// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Boostque';

  @override
  String get tabStack => 'المجموعة';

  @override
  String get tabToday => 'اليوم';

  @override
  String get tabCalendar => 'التقويم';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get navBack => 'رجوع';

  @override
  String get disclaimerEducational => 'مادة تثقيفية، وليست نصيحة طبية.';

  @override
  String substancesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مادة',
      many: '$count مادة',
      few: '$count مواد',
      two: '$count مادتان',
      one: '$count مادة',
      zero: '$count مادة',
    );
    return '$_temp0';
  }

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسبوع',
      many: '$count أسبوعًا',
      few: '$count أسابيع',
      two: '$count أسبوعان',
      one: '$count أسبوع',
      zero: '$count أسبوع',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => 'مجموعتي';

  @override
  String stackSummary(int total, int active) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total مكمل',
      many: '$total مكملًا',
      few: '$total مكملات',
      two: '$total مكملان',
      one: '$total مكمل',
      zero: '$total مكمل',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active نشط',
      many: '$active نشطًا',
      few: '$active نشطة',
      two: '$active نشطان',
      one: '$active نشط',
      zero: '$active نشط',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get supplementsLabel => 'المكملات';

  @override
  String get statusActive => 'نشط';

  @override
  String get statusPaused => 'متوقف';

  @override
  String get statusPlanned => 'مخطط';

  @override
  String get statusFresh => 'مضاف حديثًا';

  @override
  String get statusFinished => 'انتهى';

  @override
  String get emptyStackTitle => 'مجموعتك فارغة';

  @override
  String get emptyStackBody => 'أضف أول مكمل بزر +: من الكتالوج أو يدويًا.';

  @override
  String get stackLoadError => 'تعذّر تحميل مجموعتك. حاول مرة أخرى.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get addSupplement => 'إضافة مكمل';

  @override
  String get close => 'إغلاق';

  @override
  String get searchTab => 'البحث في الكتالوج';

  @override
  String get manualTab => 'إضافة يدوية';

  @override
  String get searchCatalogHint => 'الاسم أو المادة الفعّالة';

  @override
  String get noResultsCatalog =>
      'لا يوجد ما يطابق في الكتالوج. أضف هذا المكمل يدويًا.';

  @override
  String get nameLabel => 'الاسم';

  @override
  String get doseLabel => 'الجرعة';

  @override
  String get addManualSupplement => 'إضافة مكمل';

  @override
  String get scheduleTitle => 'جدول الجرعات';

  @override
  String get pausedBadge => 'متوقف';

  @override
  String get periodicityLabel => 'الدورية';

  @override
  String get cyclicTab => 'دوري';

  @override
  String get courseTab => 'دورة لمرة واحدة';

  @override
  String get startLabel => 'البداية';

  @override
  String get endLabel => 'النهاية';

  @override
  String get cycleLength => 'طول الدورة';

  @override
  String get breakLabel => 'الاستراحة';

  @override
  String get noBreak => 'بلا استراحة';

  @override
  String cycleSummaryCyclic(String on, String off) {
    return '$on تناول، ثم $off استراحة. يتكرر حتى توقفه.';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on تناول بلا استراحة. يتكرر حتى توقفه.';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return 'دورة واحدة بلا تكرار: $start — $end';
  }

  @override
  String get timeSlotsLabel => 'أوقات الجرعات';

  @override
  String slotsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرة في اليوم',
      many: '$count مرة في اليوم',
      few: '$count مرات في اليوم',
      two: '$count مرتان في اليوم',
      one: '$count مرة في اليوم',
      zero: '$count مرة في اليوم',
    );
    return '$_temp0';
  }

  @override
  String get addTimeSlot => '+ إضافة وقت';

  @override
  String removeSlot(String time) {
    return 'إزالة الوقت $time';
  }

  @override
  String slotIntervalNote(int h, int m) {
    return 'أصغر فاصل — $h ساعة $m دقيقة.';
  }

  @override
  String get slotIntervalSingle => 'وقت واحد في اليوم.';

  @override
  String get saveAndStart => 'إضافة وبدء الدورة';

  @override
  String get saveWhilePaused => 'حفظ، والدورة متوقفة';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get resume => 'استئناف الدورة';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String saveHintActive(String start) {
    return 'ستظهر الأوقات في التقويم بدءًا من $start. الإيقاف المؤقت يزيلها دون حذف إعداداتك.';
  }

  @override
  String get saveHintPaused =>
      'تُحفظ الدورة في مجموعتك كمتوقفة، لذا لن تظهر في التقويم.';

  @override
  String deleteConfirmTitle(String name) {
    return 'حذف «$name»؟';
  }

  @override
  String get deleteConfirmBody =>
      'الحذف يزيل الجدول والجرعات المستقبلية. يبقى سجل تناولك.';

  @override
  String get saveFailed => 'تعذّر الحفظ. حاول مرة أخرى.';

  @override
  String get catalogAshwagandhaName => 'أشواغاندا KSM-66';

  @override
  String get catalogAshwagandhaDose => '300 ملغ · كبسولات';

  @override
  String get catalogCreatineName => 'كرياتين مونوهيدرات';

  @override
  String get catalogCreatineDose => '5 غ · مسحوق';

  @override
  String get catalogMelatoninName => 'ميلاتونين 3 ملغ';

  @override
  String get catalogMelatoninDose => '3 ملغ · أقراص';

  @override
  String get catalogNmnName => 'NMN 250 ملغ';

  @override
  String get catalogNmnDose => '250 ملغ · كبسولات';

  @override
  String get catalogB12Name => 'فيتامين B12 ميثيل كوبالامين';

  @override
  String get catalogB12Dose => '1000 مكغ · أقراص';

  @override
  String get catalogQ10Name => 'كوإنزيم Q10 يوبيكوينول';

  @override
  String get catalogQ10Dose => '100 ملغ · كبسولات';

  @override
  String get catalogIodineName => 'يود 150 مكغ';

  @override
  String get catalogIodineDose => '150 مكغ · أقراص';

  @override
  String get catalogIronName => 'حديد بيسغليسينات';

  @override
  String get catalogIronDose => '25 ملغ · كبسولات';

  @override
  String get catalogHypericumName => 'عشبة سانت جون';

  @override
  String get catalogHypericumDose => 'خلاصة 300 ملغ · كبسولات';

  @override
  String get catalogMagnesiumName => 'مغنيسيوم بيسغليسينات';

  @override
  String get catalogMagnesiumDose => '400 ملغ · كبسولات';

  @override
  String get catalogChondroName => 'واقي الغضاريف';

  @override
  String get catalogChondroDose => 'غلوكوزامين 500 + كوندرويتين 400';

  @override
  String get catalogD3Name => 'فيتامين D3';

  @override
  String get catalogD3Dose => '2000 وحدة دولية · قطرات';

  @override
  String get catalogOmega3Name => 'أوميغا-3';

  @override
  String get catalogOmega3Dose => 'EPA 500 / DHA 250';

  @override
  String get catalogZincName => 'زنك بيكولينات';

  @override
  String get catalogZincDose => '15 ملغ · أقراص';

  @override
  String get catalogCurcuminName => 'كركمين';

  @override
  String get catalogCurcuminDose => '500 ملغ + بيبيرين';

  @override
  String get calendarTitleToday => 'اليوم';

  @override
  String get blockMorning => 'الصباح';

  @override
  String get blockDay => 'النهار';

  @override
  String get blockEvening => 'المساء';

  @override
  String get blockNight => 'الليل';

  @override
  String get blockTagBreakfast => 'مع الفطور';

  @override
  String get blockTagLunch => 'مع الغداء';

  @override
  String get blockTagDinner => 'مع العشاء';

  @override
  String get blockTagSleep => 'قبل النوم';

  @override
  String get blockAllTaken => 'تم تناول الكل';

  @override
  String get blockAllMarked => 'تم تعليم الكل';

  @override
  String blockProgress(int done, int total) {
    return '$done من $total';
  }

  @override
  String get overdueLabel => 'لم يُتناول في وقته';

  @override
  String get skippedLabel => 'تم التخطي';

  @override
  String get notMarkedLabel => 'غير معلَّم';

  @override
  String get plannedLabel => 'مخطط';

  @override
  String doseCycleChip(int n, int m) {
    return 'الجرعة $n من $m';
  }

  @override
  String ringSemantics(int taken, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'تم تناول $taken من أصل $total جرعة',
      many: 'تم تناول $taken من أصل $total جرعة',
      few: 'تم تناول $taken من أصل $total جرعات',
      two: 'تم تناول $taken من أصل $total جرعتين',
      one: 'تم تناول $taken من أصل $total جرعة',
      zero: 'تم تناول $taken من أصل $total جرعة',
    );
    return '$_temp0';
  }

  @override
  String get markTaken => 'تسجيل التناول';

  @override
  String get markSkipped => 'تسجيل التخطي';

  @override
  String get undoMark => 'إزالة العلامة';

  @override
  String get backToToday => 'اليوم';

  @override
  String doseSheetSubtitle(String time, String dose) {
    return '$time · $dose';
  }

  @override
  String doseSheetSubtitleTimeOnly(String time) {
    return '$time';
  }

  @override
  String get emptyDayTitle => 'لا جرعات في هذا اليوم';

  @override
  String get emptyDayBody => 'لا توجد دورة نشطة في هذا اليوم.';

  @override
  String get emptyDayBodyNoStack =>
      'أضف مكملًا في تبويب «المجموعة» لتظهر الجرعات هنا.';

  @override
  String get dayLoadError => 'تعذّر تحميل هذا اليوم. حاول مرة أخرى.';

  @override
  String get markFailed => 'تعذّر حفظ العلامة.';

  @override
  String get calendarDisclaimer =>
      'هذا الجدول مبني على مدخلاتك أنت. مادة تثقيفية، وليست نصيحة طبية.';

  @override
  String get plannerTitle => 'المخطِّط';

  @override
  String get plannerSegYear => 'السنة';

  @override
  String get plannerSegCycles => 'الدورات';

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
      other: '$count شهر',
      many: '$count شهرًا',
      few: '$count أشهر',
      two: '$count شهران',
      one: '$count شهر',
      zero: '$count شهر',
    );
    return '$_temp0';
  }

  @override
  String periodsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فترة',
      many: '$count فترة',
      few: '$count فترات',
      two: '$count فترتان',
      one: '$count فترة',
      zero: '$count فترة',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return '$count في الوقت نفسه هذا الأسبوع';
  }

  @override
  String get legendTaking => 'قيد التناول';

  @override
  String get legendPlanned => 'مخطط';

  @override
  String get legendPaused => 'متوقف';

  @override
  String get loadChartTitle => 'الحمل المتزامن';

  @override
  String get loadChartMeta => 'حسب الأسبوع';

  @override
  String get loadScaleCaption => 'العمود الكامل = مجموعتك كاملة';

  @override
  String peakMonth(String month) {
    return 'أكثر الشهور كثافة — $month';
  }

  @override
  String peakMonthsTie(String month) {
    return 'أكثر الشهور كثافة، ومنها $month';
  }

  @override
  String get yearLegendHint => 'الأفتح = مخطط';

  @override
  String get monthStateTaking => 'قيد التناول';

  @override
  String get monthStatePlanned => 'مخطط';

  @override
  String get monthStatePartial => 'جزء من الشهر';

  @override
  String get monthEmpty => 'لا توجد دورة نشطة هذا الشهر.';

  @override
  String get emptyPlannerTitle => 'لا شيء للتخطيط بعد';

  @override
  String get emptyPlannerBody =>
      'أضف مكملًا في تبويب «المجموعة» لتظهر دوراته هنا.';

  @override
  String get emptyPlannerBodyNoRegimen =>
      'مكملاتك بلا جدول بعد. افتح أحدها في تبويب «المجموعة» لضبط دورة.';

  @override
  String get plannerLoadError => 'تعذّر تحميل المخطِّط. حاول مرة أخرى.';

  @override
  String get plannerDisclaimer =>
      'يعرض المخطِّط كيف تتداخل دوراتك عبر الزمن. مادة تثقيفية، وليست نصيحة طبية.';

  @override
  String ganttRowSemantics(String name, String schedule, String periods) {
    return '$name، $schedule، $periods';
  }

  @override
  String ganttRowSemanticsPaused(String name, String schedule, String state) {
    return '$name، $schedule، $state';
  }

  @override
  String yearLegendEntrySemantics(String name, String state) {
    return '$name، $state';
  }

  @override
  String weekBarSemantics(String range, String load) {
    return '$range، $load';
  }

  @override
  String monthCardSemantics(String month, String count) {
    return '$month، $count';
  }

  @override
  String addSupplementCatalogSemantics(String action, String name) {
    return '$action: $name';
  }

  @override
  String get languageName => 'العربية';

  @override
  String get languageSystem => 'لغة النظام';

  @override
  String get settingsLanguageTitle => 'اللغة';

  @override
  String get settingsRemindersTitle => 'التذكيرات';

  @override
  String get settingsRemindersAllowed => 'التذكيرات مسموح بها';

  @override
  String get settingsRemindersBlocked => 'التذكيرات غير مسموح بها';

  @override
  String get settingsRemindersOpenSystem => 'فتح إعدادات النظام';

  @override
  String get doseReminderTitle => 'حان وقت جرعاتك';

  @override
  String doseReminderBody(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جرعة',
      many: '$count جرعة',
      few: '$count جرعات',
      two: '$count جرعتان',
      one: '$count جرعة',
      zero: '$count جرعة',
    );
    return '$time · $_temp0';
  }

  @override
  String get doseChannelName => 'تذكيرات الجرعات';

  @override
  String get doseChannelDescription => 'تذكير واحد لكل وقت جرعة في جدولك.';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingAddFirst => 'أضف أول مكمل';

  @override
  String get onboardingPage1Title => 'مجموعتك، يومًا بيوم';

  @override
  String get onboardingPage1Body =>
      'خطّط لما تتناوله وسجّل ما تناولته. يعرض «اليوم» ما يلزم اليوم فقط.';

  @override
  String get onboardingIllustrationSemantics1 =>
      'مثال لقائمة جرعات: واحدة مسجَّلة كمتناوَلة وأخرى قيد الانتظار';

  @override
  String get hintDismiss => 'فهمت';

  @override
  String get hintCycle =>
      'الدورة هي أسابيع تناول مع استراحة. اضبطها بالمؤشرات أدناه، ويحسب التطبيق الأيام التي تحتاج جرعة.';

  @override
  String get hintMarkDose =>
      'المس الجرعة لتسجيل تناولها. اضغط مطولًا لبقية الخيارات.';

  @override
  String get debugResetOnboarding => 'إعادة ضبط المقدمة والتلميحات';

  @override
  String get onboardingPage2Title => 'التقويم يرى كل شيء دفعة واحدة';

  @override
  String get onboardingPage2Body =>
      'يبيّن التقويم أين أنت في كل دورة، وما الذي يتداخل مع ماذا، ومتى تبدأ الاستراحة التالية.';

  @override
  String get onboardingIllustrationSemantics2 =>
      'مثال لتقويم: ثلاثة مكملات تتداخل أسابيع تناولها جزئيًا';

  @override
  String get onboardingNext => 'التالي';
}
