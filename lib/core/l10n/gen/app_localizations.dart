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

  /// Bottom navigation tab label for the calendar screen
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// Bottom navigation tab label for the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

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

  /// Empty-state body on the Stack screen
  ///
  /// In en, this message translates to:
  /// **'Add your first supplement — from the catalog or manually.'**
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
