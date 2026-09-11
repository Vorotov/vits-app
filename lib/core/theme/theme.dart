/// VitoMy app theme — the single ThemeData factory (D-06).
///
/// Built EXCLUSIVELY from `tokens.dart` constants: this file contains zero
/// raw color hex literals (D-07 token-only rule applied to the theme itself).
///
/// Fonts are the bundled variable-font assets from pubspec (`Instrument
/// Sans`, `JetBrains Mono`) — plain [FontWeight] selects the `wght` axis
/// instance automatically (Flutter 3.41+); no runtime fetching, no manual
/// [FontVariation] code (D-05).
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app-wide [ThemeData] encoding the approved mockup's design system.
ThemeData bqTheme() {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: BqColors.accent,
  ).copyWith(
    primary: BqColors.accent,
    surface: BqColors.paper,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Instrument Sans',
    scaffoldBackgroundColor: BqColors.paper,
    colorScheme: colorScheme,
    textTheme: const TextTheme(
      // Heading role — stub screen titles (D-24, UI-SPEC Typography).
      headlineSmall: TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.1,
        color: BqColors.ink,
      ),
      // Body role — captions/subtitles (UI-SPEC Typography).
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: BqColors.ink,
      ),
    ),
    // NO bottom-navigation sub-theme (plan 06-01, D-25 superseded). The bar
    // is the hand-built `BqNavBar`, which reads BqColors directly (D-07), so
    // the former surfaceAlt background / accent-selected / textFaint-unselected
    // / 10px label values moved INTO `bq_nav_bar.dart` and were then deleted
    // from here. A sub-theme no widget reads is a trap: the next reader edits
    // it expecting the bar to change (T-06-01).
    //
    // The FAB (plan 06-04, UX-01): the ONLY place its colours may be written.
    // `bq_add_fab.dart` carries `Icons.add` and nothing else — no BqColors
    // reference exists in that file (D-07).
    //
    // Elevation is 0 in every state, deliberately. The design brief asks for
    // "the app's existing elevation language" and this app HAS none: the v1
    // bar was flat and 04-UI-SPEC states there is no Material elevation
    // anywhere on the planner screens. A flat accent disc on the paper
    // background has ample contrast without a shadow, and a shadow here —
    // including one that appears only on focus, hover or press — would be the
    // first one in the app.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: BqColors.accent,
      foregroundColor: BqColors.surface,
      splashColor: BqColors.accentPressed,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    //
    // Phase-2 sub-themes (02-UI-SPEC "bqTheme() extensions this phase").
    // Every value below references tokens only (D-07).
    //
    // Text inputs / date fields: white fill, radius `BqRadii.input`, 1px
    // `inputBorder` side (accent when focused — discretion per plan), hint in
    // `textMuted`, mockup-exact 13/14 content padding (UI-SPEC spacing
    // override — direction-neutral).
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: BqColors.surface,
      hintStyle: TextStyle(color: BqColors.textMuted),
      contentPadding: EdgeInsetsDirectional.symmetric(
        vertical: 13,
        horizontal: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(BqRadii.input)),
        borderSide: BorderSide(color: BqColors.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(BqRadii.input)),
        borderSide: BorderSide(color: BqColors.accent),
      ),
    ),
    // Cycle sliders: accent active track + thumb, `field` inactive track
    // (mockup `accent-color:#4A4E7C`).
    sliderTheme: const SliderThemeData(
      activeTrackColor: BqColors.accent,
      thumbColor: BqColors.accent,
      inactiveTrackColor: BqColors.field,
    ),
    // SDK date/time pickers (the one place genuine pickers are used —
    // CLAUDE.md): white surface, accent selection via colorScheme.primary.
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: BqColors.surface,
      headerBackgroundColor: BqColors.accent,
      headerForegroundColor: BqColors.surface,
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: BqColors.surface,
      dialHandColor: BqColors.accent,
    ),
    // Modal bottom sheets: paper background, `scrim` barrier, mockup's
    // 26px top corners (line 127).
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: BqColors.paper,
      modalBarrierColor: BqColors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BqRadii.sheet),
        ),
      ),
    ),
  );
}

/// Text-style helpers outside the Material [TextTheme] roles.
abstract final class BqText {
  /// Mono numerals/labels style — JetBrains Mono with tabular figures
  /// (UI-SPEC mono-numerals rule; consumed from Phase 3 on).
  static TextStyle mono({
    double size = 11,
    Color color = BqColors.textMuted,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0.5,
  }) {
    return TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
