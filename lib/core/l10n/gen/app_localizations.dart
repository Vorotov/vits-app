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
