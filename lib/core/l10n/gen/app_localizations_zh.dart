// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'VitoMy';

  @override
  String get tabStack => '组合';

  @override
  String get tabToday => '今天';

  @override
  String get tabCalendar => '日历';

  @override
  String get settingsTitle => '设置';

  @override
  String get navBack => '返回';

  @override
  String get disclaimerEducational => '科普内容，非医疗建议。';

  @override
  String substancesCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 种成分',
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
      other: '$countString 周',
    );
    return '$_temp0';
  }

  @override
  String get stackTitle => '我的组合';

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
      other: '$totalString 种补剂',
    );
    String _temp1 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$activeString 种在用',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get supplementsLabel => '补剂';

  @override
  String get statusActive => '进行中';

  @override
  String get statusPaused => '已暂停';

  @override
  String get statusPlanned => '已计划';

  @override
  String get statusFresh => '刚添加';

  @override
  String get statusFinished => '已结束';

  @override
  String get emptyStackTitle => '组合还是空的';

  @override
  String get emptyStackBody => '用 + 按钮添加第一种补剂：从目录选择或手动填写。';

  @override
  String get stackLoadError => '无法加载你的组合，请重试。';

  @override
  String get retry => '重试';

  @override
  String get addSupplement => '添加补剂';

  @override
  String get close => '关闭';

  @override
  String get searchTab => '搜索目录';

  @override
  String get manualTab => '手动添加';

  @override
  String get searchCatalogHint => '名称或有效成分';

  @override
  String get noResultsCatalog => '目录里没有匹配项，可手动添加这种补剂。';

  @override
  String get nameLabel => '名称';

  @override
  String get doseLabel => '剂量';

  @override
  String get addManualSupplement => '添加补剂';

  @override
  String get scheduleTitle => '服用安排';

  @override
  String get pausedBadge => '已暂停';

  @override
  String get periodicityLabel => '周期方式';

  @override
  String get cyclicTab => '循环';

  @override
  String get courseTab => '单次周期';

  @override
  String get startLabel => '开始';

  @override
  String get endLabel => '结束';

  @override
  String get cycleLength => '周期长度';

  @override
  String get breakLabel => '间歇';

  @override
  String get noBreak => '无间歇';

  @override
  String cycleSummaryCyclic(String on, String off) {
    return '$on服用，然后$off间歇。一直重复，直到你关闭。';
  }

  @override
  String cycleSummaryCyclicNoBreak(String on) {
    return '$on服用，中间不间歇。一直重复，直到你关闭。';
  }

  @override
  String courseSummaryRange(String start, String end) {
    return '一次周期，不重复：$start — $end';
  }

  @override
  String get timeSlotsLabel => '服用时间';

  @override
  String slotsPerDay(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '每天 $countString 次',
    );
    return '$_temp0';
  }

  @override
  String get addTimeSlot => '+ 添加时间点';

  @override
  String removeSlot(String time) {
    return '移除时间点 $time';
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

    return '最小间隔 — $hString 小时 $mString 分钟。';
  }

  @override
  String get slotIntervalSingle => '每天一个时间点。';

  @override
  String get saveAndStart => '添加并开始周期';

  @override
  String get saveWhilePaused => '保存，周期暂停';

  @override
  String get pause => '暂停';

  @override
  String get resume => '继续周期';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String saveHintActive(String start) {
    return '时间点将从 $start 起出现在日历中。暂停会移除它们，但不会删除你的设置。';
  }

  @override
  String get saveHintPaused => '周期会以暂停状态保存到你的组合中，因此不会出现在日历里。';

  @override
  String deleteConfirmTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get deleteConfirmBody => '删除会移除安排和未来的服用计划。你的服用记录会保留。';

  @override
  String get saveFailed => '保存失败，请重试。';

  @override
  String get catalogAshwagandhaName => '南非醉茄 KSM-66';

  @override
  String get catalogAshwagandhaDose => '300 毫克 · 胶囊';

  @override
  String get catalogCreatineName => '一水肌酸';

  @override
  String get catalogCreatineDose => '5 克 · 粉剂';

  @override
  String get catalogMelatoninName => '褪黑素 3 毫克';

  @override
  String get catalogMelatoninDose => '3 毫克 · 片剂';

  @override
  String get catalogNmnName => 'NMN 250 毫克';

  @override
  String get catalogNmnDose => '250 毫克 · 胶囊';

  @override
  String get catalogB12Name => '维生素 B12 甲钴胺';

  @override
  String get catalogB12Dose => '1000 微克 · 片剂';

  @override
  String get catalogQ10Name => '辅酶 Q10 泛醇';

  @override
  String get catalogQ10Dose => '100 毫克 · 胶囊';

  @override
  String get catalogIodineName => '碘 150 微克';

  @override
  String get catalogIodineDose => '150 微克 · 片剂';

  @override
  String get catalogIronName => '甘氨酸亚铁';

  @override
  String get catalogIronDose => '25 毫克 · 胶囊';

  @override
  String get catalogHypericumName => '圣约翰草';

  @override
  String get catalogHypericumDose => '提取物 300 毫克 · 胶囊';

  @override
  String get catalogMagnesiumName => '甘氨酸镁';

  @override
  String get catalogMagnesiumDose => '400 毫克 · 胶囊';

  @override
  String get catalogChondroName => '软骨保护剂';

  @override
  String get catalogChondroDose => '氨基葡萄糖 500 + 硫酸软骨素 400';

  @override
  String get catalogD3Name => '维生素 D3';

  @override
  String get catalogD3Dose => '2000 国际单位 · 滴剂';

  @override
  String get catalogOmega3Name => '欧米伽-3';

  @override
  String get catalogOmega3Dose => 'EPA 500 / DHA 250';

  @override
  String get catalogZincName => '吡啶甲酸锌';

  @override
  String get catalogZincDose => '15 毫克 · 片剂';

  @override
  String get catalogCurcuminName => '姜黄素';

  @override
  String get catalogCurcuminDose => '500 毫克 + 胡椒碱';

  @override
  String get calendarTitleToday => '今天';

  @override
  String get blockMorning => '早晨';

  @override
  String get blockDay => '白天';

  @override
  String get blockEvening => '傍晚';

  @override
  String get blockNight => '夜间';

  @override
  String get blockTagBreakfast => '随早餐';

  @override
  String get blockTagLunch => '随午餐';

  @override
  String get blockTagDinner => '随晚餐';

  @override
  String get blockTagSleep => '睡前';

  @override
  String get blockAllTaken => '全部已服用';

  @override
  String get blockAllMarked => '全部已标记';

  @override
  String blockProgress(int done, int total) {
    final intl.NumberFormat doneNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String doneString = doneNumberFormat.format(done);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return '$doneString/$totalString';
  }

  @override
  String get overdueLabel => '未按时服用';

  @override
  String get skippedLabel => '已跳过';

  @override
  String get notMarkedLabel => '未标记';

  @override
  String get plannedLabel => '已计划';

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

    return '第 $nString 次，共 $mString 次';
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
      other: '共 $totalString 次，已服用 $takenString 次',
    );
    return '$_temp0';
  }

  @override
  String get markTaken => '标记为已服用';

  @override
  String get markSkipped => '标记为已跳过';

  @override
  String get undoMark => '清除标记';

  @override
  String get backToToday => '今天';

  @override
  String doseSheetSubtitle(String time, String dose) {
    return '$time · $dose';
  }

  @override
  String doseSheetSubtitleTimeOnly(String time) {
    return '$time';
  }

  @override
  String get emptyDayTitle => '这一天没有安排';

  @override
  String get emptyDayBody => '这一天没有进行中的周期。';

  @override
  String get emptyDayBodyNoStack => '在“组合”标签页添加补剂，就能在这里看到安排。';

  @override
  String get dayLoadError => '无法加载这一天，请重试。';

  @override
  String get markFailed => '无法保存标记。';

  @override
  String get calendarDisclaimer => '这份安排来自你自己的记录。科普内容，非医疗建议。';

  @override
  String get plannerTitle => '规划';

  @override
  String get plannerSegYear => '年';

  @override
  String get plannerSegCycles => '周期';

  @override
  String plannerRangeSubtitle(String start, String end, String year) {
    return '$year $start — $end';
  }

  @override
  String plannerRangeSubtitleCrossYear(
    String start,
    String startYear,
    String end,
    String endYear,
  ) {
    return '$startYear $start — $endYear $end';
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
      other: '$countString 个月',
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
      other: '$countString 个时段',
    );
    return '$_temp0';
  }

  @override
  String plannerThisWeek(String count) {
    return '本周同时进行 $count';
  }

  @override
  String get legendTaking => '服用中';

  @override
  String get legendPlanned => '已计划';

  @override
  String get legendPaused => '已暂停';

  @override
  String get loadChartTitle => '同时进行数量';

  @override
  String get loadChartMeta => '按周';

  @override
  String get loadScaleCaption => '整条 = 你的全部组合';

  @override
  String peakMonth(String month) {
    return '最密集的月份 — $month';
  }

  @override
  String peakMonthsTie(String month) {
    return '最密集的月份，包括 $month';
  }

  @override
  String get yearLegendHint => '浅色 = 已计划';

  @override
  String get monthStateTaking => '服用中';

  @override
  String get monthStatePlanned => '已计划';

  @override
  String get monthStatePartial => '本月部分时间';

  @override
  String get monthEmpty => '本月没有进行中的周期。';

  @override
  String get emptyPlannerTitle => '还没有可规划的内容';

  @override
  String get emptyPlannerBody => '在“组合”标签页添加补剂，它的周期就会显示在这里。';

  @override
  String get emptyPlannerBodyNoRegimen => '你的补剂还没有安排。在“组合”标签页打开其中一种来设置周期。';

  @override
  String get plannerLoadError => '无法加载规划，请重试。';

  @override
  String get plannerDisclaimer => '规划展示你的各个周期在时间上如何重叠。科普内容，非医疗建议。';

  @override
  String ganttRowSemantics(String name, String schedule, String periods) {
    return '$name，$schedule，$periods';
  }

  @override
  String ganttRowSemanticsPaused(String name, String schedule, String state) {
    return '$name，$schedule，$state';
  }

  @override
  String yearLegendEntrySemantics(String name, String state) {
    return '$name，$state';
  }

  @override
  String weekBarSemantics(String range, String load) {
    return '$range，$load';
  }

  @override
  String monthCardSemantics(String month, String count) {
    return '$month，$count';
  }

  @override
  String addSupplementCatalogSemantics(String action, String name) {
    return '$action：$name';
  }

  @override
  String get languageName => '中文';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsRemindersTitle => '提醒';

  @override
  String get settingsRemindersAllowed => '已允许提醒';

  @override
  String get settingsRemindersBlocked => '未允许提醒';

  @override
  String get settingsRemindersOpenSystem => '打开系统设置';

  @override
  String get doseReminderTitle => '到服用时间了';

  @override
  String doseReminderBody(int count, String time) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString 次',
    );
    return '$time · $_temp0';
  }

  @override
  String get doseChannelName => '服用提醒';

  @override
  String get doseChannelDescription => '你安排中的每个服用时间对应一条提醒。';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingAddFirst => '添加第一种补剂';

  @override
  String get onboardingPage1Title => '你的组合，一天一天来';

  @override
  String get onboardingPage1Body => '计划要服用什么，并标记已经服用的。“今天”只显示今天需要的内容。';

  @override
  String get onboardingIllustrationSemantics1 => '服用列表示例：一项已标记为已服用，一项待处理';

  @override
  String get hintDismiss => '知道了';

  @override
  String get hintCycle => '一个周期由服用的若干周加上一段间歇组成。用下面的滑块设置它们，应用会算出哪些日子需要服用。';

  @override
  String get hintMarkDose => '点按某一项即可标记为已服用。长按可查看其他选项。';

  @override
  String get settingsShowIntroAgain => '重置引导和提示';

  @override
  String get onboardingPage2Title => '日历把一切一次看全';

  @override
  String get onboardingPage2Body => '日历显示你在每个周期中的位置、哪些内容相互重叠，以及下一段间歇何时开始。';

  @override
  String get onboardingIllustrationSemantics2 => '日历示例：三种补剂的服用周数部分重叠';

  @override
  String get onboardingNext => '下一步';

  @override
  String get settingsSupportRow => '支持开发者';

  @override
  String get supportTitle => '支持开发者';

  @override
  String get supportBody =>
      'VitoMy 由一个人开发。没有广告，没有账号，你的清单也不会被发送到任何地方。打赏只是表示这个应用值得留下。它不会解锁任何内容，之后也不会有任何变化。';

  @override
  String get supportTipSmall => '小额打赏';

  @override
  String get supportTipMedium => '中等打赏';

  @override
  String get supportTipLarge => '大额打赏';

  @override
  String get supportThanks => '谢谢，这很有意义。';

  @override
  String get supportUnavailable => '目前无法打赏。请检查网络连接，稍后再试。';

  @override
  String get supportFailed => '未能完成，没有扣款。';
}
