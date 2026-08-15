/// Design tokens for Boostque, transcribed verbatim from the approved mockup
/// (`claude_design_mockup/Boostque v0.1.dc.html`) and locked in
/// 01-CONTEXT.md (D-06, D-07).
///
/// TOKEN-ONLY RULE (D-07): every later phase styles UI exclusively through
/// these constants and `bqTheme()` — no ad-hoc hex literals anywhere else in
/// the codebase, ever.
library;

import 'package:flutter/material.dart';

/// Full mockup palette (D-06).
abstract final class BqColors {
  /// Design-artboard background only — NOT an app surface. Do not use in-app
  /// (per UI-SPEC: the artboard canvas around the phone frames, nothing else).
  static const Color canvas = Color(0xFFEAE9E4);

  /// App scaffold background — the dominant surface on all screens.
  static const Color paper = Color(0xFFF7F6F3);

  /// Cards, panels, input fields, primary sheets.
  static const Color surface = Color(0xFFFFFFFF);

  /// NavigationBar (bottom tab bar) background, home-indicator bar.
  static const Color surfaceAlt = Color(0xFFFBFBF9);

  /// Chip / tag / pill backgrounds.
  static const Color chip = Color(0xFFF2F1EE);

  /// Form field / avatar-placeholder backgrounds.
  static const Color field = Color(0xFFE4E3DD);

  /// Primary text.
  static const Color ink = Color(0xFF17171B);

  /// Secondary body text.
  static const Color textSecondary = Color(0xFF5C5C66);

  /// Captions, meta labels, mono eyebrow labels.
  static const Color textMuted = Color(0xFF8E8E99);

  /// Tertiary text; unselected NavigationBar icon + label.
  static const Color textFaint = Color(0xFFA0A0A9);

  /// Primary brand indigo; selected NavigationBar icon + label.
  static const Color accent = Color(0xFF4A4E7C);

  /// Accent pressed/hover state.
  static const Color accentPressed = Color(0xFF3D4169);

  /// Accent-tinted chip background.
  static const Color accentChipBg = Color(0xFFEDEDF4);

  /// Semantic "calm" status foreground.
  static const Color calm = Color(0xFF3F7A6A);

  /// Semantic "calm" status background.
  static const Color calmBg = Color(0xFFE8F1ED);

  /// Semantic "warn" status foreground.
  static const Color warn = Color(0xFFB07A22);

  /// Semantic "warn" status background.
  static const Color warnBg = Color(0xFFFAF1E0);

  /// Semantic "risk"/destructive status foreground.
  static const Color risk = Color(0xFFA8443C);

  /// Semantic "risk"/destructive status background.
  static const Color riskBg = Color(0xFFF8EBE8);

  /// 1px hairline borders — mockup's `rgba(23,23,27,.08)` top border on the
  /// tab bar (alpha 0x14 ≈ 0.078). Claude's-discretion addition per UI-SPEC.
  static const Color hairline = Color(0x1417171B);

  // --- Phase-2 additions (02-UI-SPEC "Token Additions", mockup-sourced) ---

  /// 1px border on cards, result rows, panels, slot rows — mockup's
  /// `rgba(23,23,27,.09)` (lines 107, 141, 505, 542). Also the segmented
  /// control's container fill (same mockup value; see `BqSegmented`).
  static const Color cardBorder = Color(0x1717171B);

  /// 1px border on text inputs, date fields, secondary buttons — mockup's
  /// `rgba(23,23,27,.14)` (lines 139, 508, 556; the .13 date-field border
  /// collapses into this — locked simplification).
  static const Color inputBorder = Color(0x2417171B);

  /// Modal-sheet barrier color — mockup's `rgba(23,23,27,.32)` (line 126).
  static const Color scrim = Color(0x5217171B);

  /// Sheet drag-handle pill — mockup's `rgba(23,23,27,.16)` (line 128).
  static const Color dragHandle = Color(0x2917171B);

  /// Dashed border of "+ Додати слот часу" — mockup's `rgba(74,78,124,.4)`
  /// (line 549).
  static const Color accentBorder = Color(0x664A4E7C);

  /// Видалити button border — mockup's `rgba(168,68,60,.3)` (line 557).
  static const Color riskBorder = Color(0x4DA8443C);

  /// Disabled "+ Додати слот часу" text at the 6-slot cap (mockup line 951).
  static const Color textDisabled = Color(0xFFB9B9C0);

  /// Disabled slot "−" glyph at the 1-slot floor (mockup line 946).
  static const Color iconDisabled = Color(0xFFD8D7D1);
}

/// Supplement color-tag series palette (D-06) — exactly 8 colors, in mockup
/// order. Consumed by Phase 2+ color tags; index-stable, do not reorder.
abstract final class BqSeriesColors {
  static const List<Color> palette = [
    Color(0xFFB08A2A),
    Color(0xFF2F3457),
    Color(0xFF3F7A6A),
    Color(0xFF6B6FA8),
    Color(0xFFC4685E),
    Color(0xFF2F7A85),
    Color(0xFFC07A3A),
    Color(0xFF4A4E7C),
  ];
}

/// Corner radii (D-07). None render in Phase 1's stub shell, but they are
/// defined now so Phase 2+ consumes them without re-deriving values.
abstract final class BqRadii {
  static const double card = 14.0;
  static const double panel = 16.0;
  static const double button = 12.0;
  static const double chip = 5.0;
  static const double seg = 10.0;

  // --- Phase-2 additions (02-UI-SPEC "Token Additions", mockup-sourced) ---

  /// Search input, date fields (mockup lines 139, 508).
  static const double input = 11.0;

  /// Active segment pill inside `BqSegmented` (mockup lines 134, 501).
  static const double segInner = 8.0;

  /// Bottom-sheet top corners, via `bottomSheetTheme` (mockup line 127).
  static const double sheet = 26.0;
}

/// Spacing scale — standard 8-point scale (UI-SPEC).
///
/// The NavigationBar mockup-exact pixel overrides (top 10 / horizontal 22 /
/// destination column 66 / home-indicator 24) are intentionally NOT tokens —
/// they are hardcoded in the shell widget only (UI-SPEC Spacing exemption).
abstract final class BqSpace {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}
