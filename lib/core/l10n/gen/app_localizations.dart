import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Boostque'**
  String get appTitle;

  /// Bottom navigation tab label for the supplement stack screen
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get tabStack;

  /// Bottom navigation destination label for the Сьогодні tab, which holds today's doses and the week strip. A DISTINCT key from `backToToday`, the Today header's escape-hatch control: the two strings coincide in Ukrainian today and are unrelated, so collapsing them would make a future locale wrong
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// Bottom navigation destination label for the Календар tab, which holds the Цикли/Рік planner
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// ONE key, TWO placements (D-3): the settings gear's accessibility label on every bar-reachable screen, and the title of the Settings screen the gear pushes — so the control and its destination can never disagree. Settings is no longer a nav destination, which is why this key is no longer named after one
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Accessibility label on the back control of the pushed Settings route. Never painted: the control is an icon-only chevron, so this string exists only for screen readers
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get navBack;

  /// Educational disclaimer shown on screens with recommendations
  ///
  /// In en, this message translates to:
  /// **'Educational material, not medical advice.'**
  String get disclaimerEducational;

  /// Count of supplements in the user's stack
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} substance} other{{count} substances}}'**
  String substancesCount(int count);

  /// Count of weeks in a planner range
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} week} other{{count} weeks}}'**
  String weeksCount(int count);

  /// Stack screen heading
  ///
  /// In en, this message translates to:
  /// **'My stack'**
  String get stackTitle;

  /// Stack header summary under the heading — two ICU plural placeholders (total supplements · active count)
  ///
  /// In en, this message translates to:
  /// **'{total, plural, one{{total} supplement} other{{total} supplements}} · {active, plural, one{{active} active} other{{active} active}}'**
  String stackSummary(int total, int active);

  /// Mono eyebrow label above the stack card list; omitted when the list is empty
  ///
  /// In en, this message translates to:
  /// **'SUPPLEMENTS'**
  String get supplementsLabel;

  /// Status chip label for an active regimen
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get statusActive;

  /// Status chip label for a paused regimen
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get statusPaused;

  /// Status chip label for a regimen starting in the future
  ///
  /// In en, this message translates to:
  /// **'PLANNED'**
  String get statusPlanned;

  /// Status chip label for a supplement with no regimen yet (E-7)
  ///
  /// In en, this message translates to:
  /// **'JUST ADDED'**
  String get statusFresh;

  /// Status chip label for a course whose end date is past (D10 — invented, confirm at UAT)
  ///
  /// In en, this message translates to:
  /// **'FINISHED'**
  String get statusFinished;

  /// Empty-state heading on the Stack screen, below the still-visible CTA
  ///
  /// In en, this message translates to:
  /// **'Your stack is empty'**
  String get emptyStackTitle;

  /// Empty-state body on the Stack screen. Names the + ACTION rather than a screen corner ('bottom right'), so it stays true under RTL and if the floating button ever moves (plan 06-04)
  ///
  /// In en, this message translates to:
  /// **'Add your first supplement with the + button — from the catalog or manually.'**
  String get emptyStackBody;

  /// Stack list AsyncValue.error copy — raw exception text is never user-visible
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your stack. Try again.'**
  String get stackLoadError;

  /// Retry action on the stack load-error state
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Primary CTA on the Stack screen; also the add-supplement sheet title
  ///
  /// In en, this message translates to:
  /// **'Add supplement'**
  String get addSupplement;

  /// Dismiss action in the add-supplement sheet header
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Add-supplement sheet segmented tab: catalog search
  ///
  /// In en, this message translates to:
  /// **'Search catalog'**
  String get searchTab;

  /// Add-supplement sheet segmented tab: manual entry (replaces the mockup camera tab — D1)
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get manualTab;

  /// Hint text of the catalog search input
  ///
  /// In en, this message translates to:
  /// **'Name or active substance'**
  String get searchCatalogHint;

  /// Catalog search empty-result copy — rewritten with no label-scanning promise (D3/PF-5)
  ///
  /// In en, this message translates to:
  /// **'Nothing found in the catalog. Add this supplement manually.'**
  String get noResultsCatalog;

  /// Label for the required supplement name field in the manual add form
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Label for the optional dose description field in the manual add form
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get doseLabel;

  /// Primary CTA of the manual entry form in the add-supplement sheet
  ///
  /// In en, this message translates to:
  /// **'Add supplement'**
  String get addManualSupplement;

  /// Regimen editor top bar title
  ///
  /// In en, this message translates to:
  /// **'Dosing schedule'**
  String get scheduleTitle;

  /// Badge in the regimen editor top bar shown while the draft is paused
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get pausedBadge;

  /// Mono eyebrow label above the cyclic/course segmented toggle
  ///
  /// In en, this message translates to:
  /// **'PERIODICITY'**
  String get periodicityLabel;

  /// Segmented toggle label for the cyclic regimen mode
  ///
  /// In en, this message translates to:
  /// **'Cyclic'**
  String get cyclicTab;

  /// Segmented toggle label for the one-time course regimen mode
  ///
  /// In en, this message translates to:
  /// **'One-time course'**
  String get courseTab;

  /// Label above the regimen start date field
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startLabel;

  /// Label above the course end date field
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endLabel;

  /// Label of the on-days slider row in the regimen editor
  ///
  /// In en, this message translates to:
  /// **'Cycle length'**
  String get cycleLength;

  /// Label of the break-days slider row in the regimen editor
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get breakLabel;

  /// Break slider value label when the break length is zero
  ///
  /// In en, this message translates to:
  /// **'no break'**
  String get noBreak;

  /// Cycle preview summary for a cyclic regimen with a break; placeholders are pre-formatted weeksCount strings
  ///
  /// In en, this message translates to:
  /// **'{on} on, then {off} off — repeats until you turn it off'**
  String cycleSummaryCyclic(String on, String off);

  /// Cycle preview summary for a cyclic regimen without a break; placeholder is a pre-formatted weeksCount string
  ///
  /// In en, this message translates to:
  /// **'{on} on without a break — repeats until you turn it off'**
  String cycleSummaryCyclicNoBreak(String on);

  /// Cycle preview summary for a one-time course; placeholders are locale-formatted dates
  ///
  /// In en, this message translates to:
  /// **'One course without repetition: {start} — {end}'**
  String courseSummaryRange(String start, String end);

  /// Mono eyebrow label above the daily time-slot list
  ///
  /// In en, this message translates to:
  /// **'DOSE TIMES'**
  String get timeSlotsLabel;

  /// Daily slot count summary next to the DOSE TIMES eyebrow
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} time per day} other{{count} times per day}}'**
  String slotsPerDay(int count);

  /// Dashed button adding a daily time slot; disabled at the 6-slot cap
  ///
  /// In en, this message translates to:
  /// **'+ Add time slot'**
  String get addTimeSlot;

  /// Semantics label of the minus control on a time-slot row
  ///
  /// In en, this message translates to:
  /// **'Remove slot {time}'**
  String removeSlot(String time);

  /// Neutral helper under the slot list stating the smallest interval between slots
  ///
  /// In en, this message translates to:
  /// **'Smallest interval — {h} h {m} min.'**
  String slotIntervalNote(int h, int m);

  /// Helper under the slot list when only one slot exists
  ///
  /// In en, this message translates to:
  /// **'One slot per day.'**
  String get slotIntervalSingle;

  /// Editor footer primary CTA while the draft is not paused
  ///
  /// In en, this message translates to:
  /// **'Add and start cycle'**
  String get saveAndStart;

  /// Editor footer primary CTA while the draft is paused
  ///
  /// In en, this message translates to:
  /// **'Save, cycle paused'**
  String get saveWhilePaused;

  /// Editor footer secondary button pausing the regimen draft
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Editor footer secondary button resuming a paused regimen draft
  ///
  /// In en, this message translates to:
  /// **'Resume cycle'**
  String get resume;

  /// Editor footer destructive button; also the confirm action in the delete dialog
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Dismiss action in the delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Centered helper under the footer buttons while the draft is not paused; placeholder is a locale-formatted start date
  ///
  /// In en, this message translates to:
  /// **'Slots will appear in the calendar from {start}. Pause removes them without deleting your settings.'**
  String saveHintActive(String start);

  /// Centered helper under the footer buttons while the draft is paused
  ///
  /// In en, this message translates to:
  /// **'The cycle is saved to your stack as paused — it won\'t appear in the calendar.'**
  String get saveHintPaused;

  /// Delete confirmation dialog title; placeholder is the supplement name
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteConfirmTitle(String name);

  /// Delete confirmation dialog body stating that intake history is kept
  ///
  /// In en, this message translates to:
  /// **'Its schedule and future doses will be removed. Your intake history is kept.'**
  String get deleteConfirmBody;

  /// SnackBar shown when a save/add/delete write to the database fails; the screen stays open so no draft data is lost (WR-04)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get saveFailed;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Ashwagandha KSM-66'**
  String get catalogAshwagandhaName;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'300 mg · capsules'**
  String get catalogAshwagandhaDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Creatine monohydrate'**
  String get catalogCreatineName;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'5 g · powder'**
  String get catalogCreatineDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Melatonin 3 mg'**
  String get catalogMelatoninName;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'3 mg · tablets'**
  String get catalogMelatoninDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'NMN 250 mg'**
  String get catalogNmnName;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'250 mg · capsules'**
  String get catalogNmnDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Vitamin B12 methylcobalamin'**
  String get catalogB12Name;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'1000 mcg · tablets'**
  String get catalogB12Dose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Coenzyme Q10 ubiquinol'**
  String get catalogQ10Name;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'100 mg · capsules'**
  String get catalogQ10Dose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Iodine 150 mcg'**
  String get catalogIodineName;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'150 mcg · tablets'**
  String get catalogIodineDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Iron bisglycinate'**
  String get catalogIronName;

  /// Catalog entry dose text, neutral form/dose only (invented for the CATALOG 8 — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'25 mg · capsules'**
  String get catalogIronDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1; uk keeps the mockup's Зверобій spelling per A4)
  ///
  /// In en, this message translates to:
  /// **'St. John\'s wort'**
  String get catalogHypericumName;

  /// Catalog entry dose text (en translation of the uk BASE_STACK dose — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'extract 300 mg · capsules'**
  String get catalogHypericumDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Magnesium bisglycinate'**
  String get catalogMagnesiumName;

  /// Catalog entry dose text (en translation of the uk BASE_STACK dose — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'400 mg · capsules'**
  String get catalogMagnesiumDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Chondroprotector'**
  String get catalogChondroName;

  /// Catalog entry dose text (en translation of the uk BASE_STACK dose — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'glucosamine 500 + chondroitin 400'**
  String get catalogChondroDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Vitamin D3'**
  String get catalogD3Name;

  /// Catalog entry dose text (en translation of the uk BASE_STACK dose — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'2000 IU · drops'**
  String get catalogD3Dose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Omega-3'**
  String get catalogOmega3Name;

  /// Catalog entry dose text (verbatim from the uk BASE_STACK dose — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'EPA 500 / DHA 250'**
  String get catalogOmega3Dose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Zinc picolinate'**
  String get catalogZincName;

  /// Catalog entry dose text (en translation of the uk BASE_STACK dose — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'15 mg · tablets'**
  String get catalogZincDose;

  /// Catalog entry name (en translation of the uk mockup copy — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'Curcumin'**
  String get catalogCurcuminName;

  /// Catalog entry dose text (en translation of the uk BASE_STACK dose — review at UAT, A1)
  ///
  /// In en, this message translates to:
  /// **'500 mg + piperine'**
  String get catalogCurcuminDose;

  /// Calendar screen heading while the resolved day is today (mockup line 206); non-today days show the capitalized weekday from intl, not an ARB string (UI-SPEC S4)
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarTitleToday;

  /// Time-block label, 00:00-11:59 (DECIDED-1; mockup line 617)
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get blockMorning;

  /// Time-block label, 12:00-17:59 (DECIDED-1; mockup line 618)
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get blockDay;

  /// Time-block label, 18:00-21:59 (DECIDED-1; mockup line 619)
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get blockEvening;

  /// Time-block label, 22:00-23:59 (DECIDED-1; mockup line 620)
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get blockNight;

  /// Neutral meal tag on the morning block header (mockup line 617)
  ///
  /// In en, this message translates to:
  /// **'with breakfast'**
  String get blockTagBreakfast;

  /// Neutral meal tag on the day block header (mockup line 618)
  ///
  /// In en, this message translates to:
  /// **'with lunch'**
  String get blockTagLunch;

  /// Neutral meal tag on the evening block header (mockup line 619)
  ///
  /// In en, this message translates to:
  /// **'with dinner'**
  String get blockTagDinner;

  /// Neutral meal tag on the night block header (mockup line 620)
  ///
  /// In en, this message translates to:
  /// **'before sleep'**
  String get blockTagSleep;

  /// Block-header tag when EVERY dose in the block is taken; calm palette (mockup line 744)
  ///
  /// In en, this message translates to:
  /// **'all taken'**
  String get blockAllTaken;

  /// Block-header tag when every dose is marked and at least one is skipped; neutral palette — it must not claim skipped doses were taken (DECIDED-6, invented)
  ///
  /// In en, this message translates to:
  /// **'all marked'**
  String get blockAllMarked;

  /// Block-header progress tag on a past block of TODAY that still holds a pending dose; bare numerals, no plural (mockup line 744)
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String blockProgress(int done, int total);

  /// Dose-row chip for a pending dose whose slot time has passed — TODAY only, warn palette (mockup line 727, DECIDED-5)
  ///
  /// In en, this message translates to:
  /// **'not taken on time'**
  String get overdueLabel;

  /// Dose-row chip for a dose the user explicitly skipped; neutral palette
  ///
  /// In en, this message translates to:
  /// **'skipped'**
  String get skippedLabel;

  /// Dose-row chip for an unmarked dose on a PAST day (DECIDED-3, invented). Deliberately not 'skipped': the row is still `pending`, so the app does not know what happened — this states only what is true and carries no blame (TRACK-03)
  ///
  /// In en, this message translates to:
  /// **'not marked'**
  String get notMarkedLabel;

  /// Dose-row chip for a dose on a FUTURE day (v1.2). The row is inert — a day that has not happened cannot be marked — and this chip is what stops it from reading as a live row that silently ignores taps. Deliberately not 'not marked': nothing is expected of the user yet, so the word states a schedule, not an omission (TRACK-03 neutrality)
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get plannedLabel;

  /// Dose-row chip naming this dose's position among that regimen's doses on the day; rendered only when m > 1, bare numerals, no plural (mockup line 608)
  ///
  /// In en, this message translates to:
  /// **'dose {n} of {m}'**
  String doseCycleChip(int n, int m);

  /// Accessibility label of the day-progress ring; `total` counts every dose of the day and skipped counts as not-taken (DECIDED-7). The uk value carries all four CLDR forms on `total` (PF-8); the ring is never rendered at total == 0
  ///
  /// In en, this message translates to:
  /// **'{total, plural, one{{taken} of {total} dose taken} other{{taken} of {total} doses taken}}'**
  String ringSemantics(int taken, int total);

  /// Primary dose action — the row's Semantics action label and the first dose-sheet row (DECIDED-2)
  ///
  /// In en, this message translates to:
  /// **'Mark taken'**
  String get markTaken;

  /// Secondary dose action — dose-sheet row and Semantics custom action (DECIDED-2)
  ///
  /// In en, this message translates to:
  /// **'Mark skipped'**
  String get markSkipped;

  /// Inverse dose action returning a marked dose to pending — undo IS the feature (TRACK-02); no confirm dialog and no SnackBar undo exists
  ///
  /// In en, this message translates to:
  /// **'Clear mark'**
  String get undoMark;

  /// Header text button clearing the day selection back to 'follow today'; visible only when the resolved day differs from today. Same word as the screen title by design — it names the destination (UI-SPEC S4)
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get backToToday;

  /// Dose action-sheet subtitle under the supplement name: 24-hour slot time and the slot's dose label, rendered in mono
  ///
  /// In en, this message translates to:
  /// **'{time} · {dose}'**
  String doseSheetSubtitle(String time, String dose);

  /// Dose action-sheet subtitle when the slot carries no dose label: the 24-hour slot time alone, with no separator (the dose label is optional, and '08:00 · ' with a dangling middle dot is not a string the user should ever see)
  ///
  /// In en, this message translates to:
  /// **'{time}'**
  String doseSheetSubtitleTimeOnly(String time);

  /// Empty-state heading for a day with zero doses (invented — the mockup has no empty state). A correct, expected state on an off-week, never an error
  ///
  /// In en, this message translates to:
  /// **'No doses on this day'**
  String get emptyDayTitle;

  /// Empty-day body when the stack HAS entries — no next step is required
  ///
  /// In en, this message translates to:
  /// **'No cycle is active on this day.'**
  String get emptyDayBody;

  /// Empty-day body when the stack is empty; names the Stack tab rather than linking to it — the nav bar is the affordance
  ///
  /// In en, this message translates to:
  /// **'Add a supplement on the Stack tab to see doses here.'**
  String get emptyDayBodyNoStack;

  /// AsyncValue.error copy for the day dose stream, paired with the existing `retry` key; raw exception text is never user-visible
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this day. Try again.'**
  String get dayLoadError;

  /// SnackBar shown when a dose status write fails; the row keeps its previously rendered status because the stream is the source of truth. The only SnackBar on this screen
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the mark.'**
  String get markFailed;

  /// Two-sentence disclaimer closing the calendar scroll body (mockup line 264, verbatim). Deliberately distinct from `disclaimerEducational`, which holds only the second sentence — neither key replaces the other
  ///
  /// In en, this message translates to:
  /// **'This schedule is built from your own entries. Educational material, not medical advice.'**
  String get calendarDisclaimer;

  /// The planner screen's own title (mockup line 287) — its only placement since phase 06 deleted the Calendar header's entry button along with the page swap; the planner is reached by its own nav destination now, whose label is `tabCalendar`. Verb-free by design; never 'Open planner'
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get plannerTitle;

  /// First segment label of the planner's BqSegmented control (mockup line 290); the zoom-out view
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get plannerSegYear;

  /// Second segment label of the planner's BqSegmented control (mockup line 291) and the DEFAULT segment — its ~4-month window contains today and answers PLAN-01
  ///
  /// In en, this message translates to:
  /// **'Cycles'**
  String get plannerSegCycles;

  /// Цикли header subtitle naming the window (mockup line 288). `start`/`end` are intl LLLL standalone month names for the ACTIVE locale — never ARB, never MMMM (which yields the uk genitive case, PF-4)
  ///
  /// In en, this message translates to:
  /// **'{start} — {end} {year}'**
  String plannerRangeSubtitle(String start, String end, String year);

  /// Цикли header subtitle when the window crosses 31 December (E-8): each month carries its own year. Same LLLL standalone month rule as plannerRangeSubtitle
  ///
  /// In en, this message translates to:
  /// **'{start} {startYear} — {end} {endYear}'**
  String plannerRangeSubtitleCrossYear(
    String start,
    String startYear,
    String end,
    String endYear,
  );

  /// Рік header subtitle (mockup line 402); `months` is a pre-formatted monthsCount string, never a raw number
  ///
  /// In en, this message translates to:
  /// **'{year} · {months}'**
  String plannerYearSubtitle(String year, String months);

  /// Count of months, pre-formatted into plannerYearSubtitle. uk carries all four CLDR forms
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} month} other{{count} months}}'**
  String monthsCount(int count);

  /// Count of painted runs on a gantt row — accessibility only, pre-formatted into ganttRowSemantics because the painted bands are invisible to assistive tech. uk carries all four CLDR forms
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} period} other{{count} periods}}'**
  String periodsCount(int count);

  /// Цикли summary chip label (mockup line 920); `count` is a pre-formatted substancesCount string — the existing key, reused, never duplicated
  ///
  /// In en, this message translates to:
  /// **'{count} at the same time this week'**
  String plannerThisWeek(String count);

  /// Gantt legend entry for a solid accent segment (mockup line 326)
  ///
  /// In en, this message translates to:
  /// **'taking'**
  String get legendTaking;

  /// Gantt legend entry for a hatched segment (mockup line 327). The legend has EXACTLY THREE entries: the mockup's fourth, `є взаємодія`, does not ship (M1) — it is an interaction claim on the never-ship exclusion list. Do not add a fourth key here
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get legendPlanned;

  /// Gantt legend entry for a bare track (mockup line 329) — the swatch is the same chip colour as the track, which is how the design says a paused row is an empty track
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get legendPaused;

  /// Mono eyebrow above the weekly load chart (mockup line 335)
  ///
  /// In en, this message translates to:
  /// **'CONCURRENT LOAD'**
  String get loadChartTitle;

  /// Mono meta beside loadChartTitle (mockup line 336)
  ///
  /// In en, this message translates to:
  /// **'by week'**
  String get loadChartMeta;

  /// The load chart's scale caption (plan 06-05), on its own full-width row under the axis bounds. It states what a full bar MEANS (every scheduled supplement in the stack overlaps that week) and asserts nothing about whether that is good or bad; it replaces loadAxisLegend, which named an editorial limit. It occupied the axis row's centre slot until CR-02, where a third of the card's width proved too narrow to render it without truncation in either locale
  ///
  /// In en, this message translates to:
  /// **'full bar = your whole stack'**
  String get loadScaleCaption;

  /// Рік peak chip when one month leads (mockup line 967); `month` is an intl LLLL standalone (nominative) form
  ///
  /// In en, this message translates to:
  /// **'Densest month — {month}'**
  String peakMonth(String month);

  /// Рік peak chip when several months tie (mockup line 967); `month` is an intl LLLL standalone (nominative) form
  ///
  /// In en, this message translates to:
  /// **'Densest months, including {month}'**
  String peakMonthsTie(String month);

  /// Closing entry of the Рік legend explaining the two-tone swatch (mockup line 436)
  ///
  /// In en, this message translates to:
  /// **'lighter = planned'**
  String get yearLegendHint;

  /// Month-detail row state when the whole month is covered and already running (mockup line 850)
  ///
  /// In en, this message translates to:
  /// **'taking'**
  String get monthStateTaking;

  /// Month-detail row state when the month's coverage is entirely in the future (mockup line 850)
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get monthStatePlanned;

  /// Month-detail row state when coverage is partial (mockup line 850)
  ///
  /// In en, this message translates to:
  /// **'part of the month'**
  String get monthStatePartial;

  /// Month-detail body when no supplement covers the month (invented — the mockup never renders a zero-coverage month). A correct, expected state, never an error
  ///
  /// In en, this message translates to:
  /// **'No cycle is active this month.'**
  String get monthEmpty;

  /// Planner empty-state heading, rendered on BOTH segments (invented — the mockup has no empty state)
  ///
  /// In en, this message translates to:
  /// **'Nothing to plan yet'**
  String get emptyPlannerTitle;

  /// Planner empty-state body when the stack is empty; names the Stack tab rather than linking to it — the nav bar is the affordance
  ///
  /// In en, this message translates to:
  /// **'Add a supplement on the Stack tab — its cycles will appear here.'**
  String get emptyPlannerBody;

  /// Planner empty-state body when supplements exist but none has a regimen (DECIDED-7) — a user who owns supplements is never told to go add one
  ///
  /// In en, this message translates to:
  /// **'Your supplements don\'t have a schedule yet. Open one on the Stack tab to set a cycle.'**
  String get emptyPlannerBodyNoRegimen;

  /// AsyncValue.error copy for the planner's stack stream, paired with the existing `retry` key; raw exception text and stack traces never enter the widget tree
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the planner. Try again.'**
  String get plannerLoadError;

  /// PLAN-04 closure, REWRITTEN in phase 06 (06-UI-SPEC D-4). Rendered as the LAST element of BOTH planner segments — Цикли and Рік — and on the empty and error surfaces too, because PLAN-04 is unconditional. It says what the planner IS and closes with the educational sentence verbatim; it asserts no limit, because after PLAN-05 there is no limit anywhere in the planner to frame. The bare `disclaimerEducational` still cannot stand in for it — the first sentence is what makes this the planner's own closure (DECIDED-8, superseded in part by 06-UI-SPEC D-4)
  ///
  /// In en, this message translates to:
  /// **'The planner shows how your cycles overlap over time. Educational material, not medical advice.'**
  String get plannerDisclaimer;

  /// Accessibility label of a gantt row: the painted bands are invisible to assistive tech, so the run count is spoken. `schedule` is the shared schedule-summary composition (minus the daily-slot tail) and `periods` is a pre-formatted periodsCount string
  ///
  /// In en, this message translates to:
  /// **'{name}, {schedule}, {periods}'**
  String ganttRowSemantics(String name, String schedule, String periods);

  /// Accessibility label of a PAUSED gantt row. DECIDED-7 says a paused row is a bare track, and the legend translates that into one word — both are purely visual, so assistive tech would otherwise hear a supplement with a schedule and zero periods and have no way to tell 'paused' from 'off-cycle all window' (WR-01). `state` is the existing legendPaused word, never new copy, so the PLAN-04 gate stays authoritative over one vocabulary
  ///
  /// In en, this message translates to:
  /// **'{name}, {schedule}, {state}'**
  String ganttRowSemanticsPaused(String name, String schedule, String state);

  /// Accessibility label of a PAUSED supplement's year-legend entry — the only place a paused supplement is named on the Рік segment, since its coverage bars are all zero-width and therefore silent. `state` is the existing legendPaused word (WR-01)
  ///
  /// In en, this message translates to:
  /// **'{name}, {state}'**
  String yearLegendEntrySemantics(String name, String state);

  /// Accessibility label of a load-chart week column; `range` is an intl-formatted bucket range and `load` a pre-formatted substancesCount string (it named a weekLoadLabel string until phase 06 deleted that key along with the limit it stated)
  ///
  /// In en, this message translates to:
  /// **'{range}, {load}'**
  String weekBarSemantics(String range, String load);

  /// Accessibility label of a year-grid month card; `month` is an intl LLLL standalone form and `count` a pre-formatted substancesCount string
  ///
  /// In en, this message translates to:
  /// **'{month}, {count}'**
  String monthCardSemantics(String month, String count);

  /// Accessibility label of a catalog row's add affordance. The whole sentence — including its separator — lives here rather than being concatenated in Dart, because word order and punctuation between the two fragments are a per-language decision (PF-5); both parts are passed in finished, the pre-formatted-count idiom
  ///
  /// In en, this message translates to:
  /// **'{action}: {name}'**
  String addSupplementCatalogSemantics(String action, String name);

  /// This language's OWN name, written in this language (its endonym). EVERY app_*.arb declares its own value under this same key; the picker resolves it via lookupAppLocalizations(locale), so adding a new ARB file needs no code change (L10N-04, criterion 4). NEVER translate this key
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// Language-picker option meaning 'follow the device language'. Rendered in the ACTIVE locale via context.l10n, unlike languageName
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// Mono eyebrow above the language list on the Settings screen, in the supplementsLabel style. Stored uppercase; never toUpperCase()'d at runtime
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguageTitle;

  /// Mono eyebrow above the dose-reminder permission row on the Settings screen, in the same style as settingsLanguageTitle. Stored UPPERCASE DELIBERATELY, exactly like that key: uppercasing at runtime is locale-dependent, and storing the cased form side-steps the question entirely. The whole section is absent while the permission answer is not yet known
  ///
  /// In en, this message translates to:
  /// **'REMINDERS'**
  String get settingsRemindersTitle;

  /// The reminder-permission row when the operating system allows this app to post notifications (DECIDED-9a). A statement of state, never a control: there is no toggle here, and it carries NO numeral, no duration, no per-slot detail and no schedule information. The horizon limitation wants a magnitude and that magnitude belongs to the deferred notification-settings screen, which is precisely why a state row fits on this one
  ///
  /// In en, this message translates to:
  /// **'Reminders are allowed'**
  String get settingsRemindersAllowed;

  /// The reminder-permission row when the operating system does not allow this app to post notifications — whether the user refused the prompt or switched them off later (DECIDED-9a). Neither platform can distinguish the two, so the copy states the effect and never the cause. Same rules as settingsRemindersAllowed: no numeral, no toggle, no schedule detail
  ///
  /// In en, this message translates to:
  /// **'Reminders are not allowed'**
  String get settingsRemindersBlocked;

  /// Label of the one control on the reminder-permission row, which opens the operating system's own notification settings for this app. It is the ONLY route back after a refusal on iOS and after a second refusal on Android, which is why it is offered in both states rather than only in the blocked one
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get settingsRemindersOpenSystem;

  /// Title line of the grouped dose-reminder notification, rendered by the OS in the notification shade and on the lock screen. CONSTANT across every reminder and deliberately carries neither the app name (both platforms print it in chrome the app does not control), nor the count, nor the time (both live in the body, so the title stays a recognition line). MUST NEVER name a supplement: this text sits on a lock screen, and iOS exposes no hiddenPreviewsBodyPlaceholder through this plugin, which makes the text itself the only privacy control (spec 2.1, ASVS V4). Budget: 24 characters in every locale
  ///
  /// In en, this message translates to:
  /// **'Time for your doses'**
  String get doseReminderTitle;

  /// Body line of the grouped dose-reminder notification: the scheduled dose time this reminder belongs to, then how many doses are due at it. One notification exists per time-of-day, so `count` counts DOSES DUE AT THAT ONE TIME — never supplements in the stack, never doses left in the day. `count` is never 0: the pure plan emits nothing for a time with no active doses. `time` is pre-formatted 24-hour HH:mm by the notification service via DateFormat.Hm, matching the app's alwaysUse24HourFormat rule on every other time display; it is restated even though the notification arrives at that time, because inexactAllowWhileIdle can shift delivery by 10-15 minutes and the OS timestamps delivery, not schedule. The ' · ' separator is the house idiom from doseSheetSubtitle and deliberately replaces a preposition, which Ukrainian would have to inflect per hour (о 08:00 / об 11:00). MUST NEVER name a supplement. Budget: 32 characters at count=999 in every locale
  ///
  /// In en, this message translates to:
  /// **'{time} · {count, plural, one{{count} dose} other{{count} doses}}'**
  String doseReminderBody(int count, String time);

  /// Name of the Android notification channel `doses_v1`, user-visible in the OS's own Settings > Apps > Boostque > Notifications list. It is UI copy rendered by Android, so it is localized like everything else. Android's createNotificationChannel updates the name and description of an existing channel id, so this is re-applied at startup and on every language change WITHOUT versioning the id — versioning it would reset the user's own channel customizations (DECIDED-14)
  ///
  /// In en, this message translates to:
  /// **'Dose reminders'**
  String get doseChannelName;

  /// Description of the Android notification channel `doses_v1`, shown under its name in the OS's notification settings. States the grouping rule (one per time-of-day, not one per supplement) so the user can predict the volume before enabling it. Mutable alongside the name; same refresh rule (DECIDED-14)
  ///
  /// In en, this message translates to:
  /// **'One reminder for each dose time in your schedule.'**
  String get doseChannelDescription;

  /// Text button in the top trailing corner of both onboarding pages. Leaves the intro without opening the add sheet; sets the same seen flag as the final CTA (D-7/D-8), so onboarding never comes back after it
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Primary CTA on onboarding page 2 — marks onboarding seen and opens the existing add-supplement sheet through the app's single add entry point (D-10). Cancelling that sheet is fine: the flag stays set
  ///
  /// In en, this message translates to:
  /// **'Add your first supplement'**
  String get onboardingAddFirst;

  /// Title of onboarding page 1 — what the app is: a stack you plan and tick off daily. Plain product language, no medical or efficacy claims (copy gate applies to all onboarding keys)
  ///
  /// In en, this message translates to:
  /// **'Your stack, day by day'**
  String get onboardingPage1Title;

  /// Body of onboarding page 1: the daily loop (plan → see → mark). Names the Сьогодні/Today tab the way the nav bar does. Describes scheduling behavior only — never a benefit, dosage or safety claim
  ///
  /// In en, this message translates to:
  /// **'Plan what to take and mark what you\'ve taken — Today shows only what\'s needed today.'**
  String get onboardingPage1Body;

  /// Screen-reader label for page 1's decorative illustration (a token-built miniature of two dose rows). The visual is ExcludeSemantics'd; this one sentence replaces it
  ///
  /// In en, this message translates to:
  /// **'Example dose list: one marked taken, one pending'**
  String get onboardingIllustrationSemantics1;

  /// Dismiss control on a one-time contextual hint card. Permanent: the hint never returns after it. Phrased as the user's own acknowledgement rather than as a command like Close, because the card asks nothing else of them
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get hintDismiss;

  /// One-time hint shown inside the regimen editor's schedule panel, at the moment the cycle sliders are first on screen. Explains the one non-obvious idea in the product where it actually lives, instead of on an intro screen the user saw before they had a regimen. Describes scheduling only — never why one would cycle, which would be a physiological claim
  ///
  /// In en, this message translates to:
  /// **'A cycle is on-weeks plus a break. Set them with the sliders below and the app works out which days need a dose.'**
  String get hintCycle;

  /// One-time hint shown on Сьогодні above the first day that actually has doses, so it arrives only once the action it describes is possible. Names both gestures the dose row supports
  ///
  /// In en, this message translates to:
  /// **'Tap a dose to mark it taken. Long-press for the other options.'**
  String get hintMarkDose;

  /// Row in Settings that clears the onboarding seen-flag and every dismissed hint, so they can be seen again. Rendered ONLY in debug builds (kDebugMode) — it exists so the intro can be re-tested on a device without a reinstall, which would delete the user's data. It is localized like any other row because it is a real, visible row in the build that has it
  ///
  /// In en, this message translates to:
  /// **'Reset intro and hints'**
  String get debugResetOnboarding;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
