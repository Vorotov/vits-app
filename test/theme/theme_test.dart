import 'package:boostque/core/theme/theme.dart';
import 'package:boostque/core/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BqColors — exact mockup hex values (D-06)', () {
    test('surfaces', () {
      expect(BqColors.canvas, const Color(0xFFEAE9E4));
      expect(BqColors.paper, const Color(0xFFF7F6F3));
      expect(BqColors.surface, const Color(0xFFFFFFFF));
      expect(BqColors.surfaceAlt, const Color(0xFFFBFBF9));
      expect(BqColors.chip, const Color(0xFFF2F1EE));
      expect(BqColors.field, const Color(0xFFE4E3DD));
    });

    test('text', () {
      expect(BqColors.ink, const Color(0xFF17171B));
      expect(BqColors.textSecondary, const Color(0xFF5C5C66));
      expect(BqColors.textMuted, const Color(0xFF8E8E99));
      expect(BqColors.textFaint, const Color(0xFFA0A0A9));
    });

    test('accent', () {
      expect(BqColors.accent, const Color(0xFF4A4E7C));
      expect(BqColors.accentPressed, const Color(0xFF3D4169));
      expect(BqColors.accentChipBg, const Color(0xFFEDEDF4));
    });

    test('semantic status', () {
      expect(BqColors.calm, const Color(0xFF3F7A6A));
      expect(BqColors.calmBg, const Color(0xFFE8F1ED));
      expect(BqColors.warn, const Color(0xFFB07A22));
      expect(BqColors.warnBg, const Color(0xFFFAF1E0));
      expect(BqColors.risk, const Color(0xFFA8443C));
      expect(BqColors.riskBg, const Color(0xFFF8EBE8));
    });

    test('hairline — 1px top-border rgba(23,23,27,.08)', () {
      expect(BqColors.hairline, const Color(0x1417171B));
    });
  });

  group('BqSeriesColors — supplement color-tag series (D-06)', () {
    test('exactly 8 colors, exact order', () {
      expect(BqSeriesColors.palette.length, 8);
      expect(BqSeriesColors.palette, const [
        Color(0xFFB08A2A),
        Color(0xFF2F3457),
        Color(0xFF3F7A6A),
        Color(0xFF6B6FA8),
        Color(0xFFC4685E),
        Color(0xFF2F7A85),
        Color(0xFFC07A3A),
        Color(0xFF4A4E7C),
      ]);
      expect(BqSeriesColors.palette.first, const Color(0xFFB08A2A));
    });
  });

  group('BqRadii (D-07)', () {
    test('exact values', () {
      expect(BqRadii.card, 14.0);
      expect(BqRadii.panel, 16.0);
      expect(BqRadii.button, 12.0);
      expect(BqRadii.chip, 5.0);
      expect(BqRadii.seg, 10.0);
    });
  });

  group('BqSpace — 8-point scale (UI-SPEC)', () {
    test('exact values', () {
      expect(BqSpace.xs, 4.0);
      expect(BqSpace.sm, 8.0);
      expect(BqSpace.md, 16.0);
      expect(BqSpace.lg, 24.0);
      expect(BqSpace.xl, 32.0);
      expect(BqSpace.xxl, 48.0);
      expect(BqSpace.xxxl, 64.0);
    });
  });

  group('bqTheme() — theme wiring from tokens', () {
    final ThemeData t = bqTheme();

    test('Material 3 + core surfaces', () {
      expect(t.useMaterial3, isTrue);
      expect(t.scaffoldBackgroundColor, BqColors.paper);
      expect(t.colorScheme.primary, BqColors.accent);
      expect(t.colorScheme.surface, BqColors.paper);
    });

    test('bundled Instrument Sans family — no runtime fetch (D-05)', () {
      expect(t.textTheme.bodyMedium?.fontFamily, 'Instrument Sans');
    });

    test('heading role — 25 / w600 / -0.5 / 1.1 (D-24, UI-SPEC)', () {
      final TextStyle? h = t.textTheme.headlineSmall;
      expect(h?.fontSize, 25);
      expect(h?.fontWeight, FontWeight.w600);
      expect(h?.letterSpacing, -0.5);
      expect(h?.height, 1.1);
      expect(h?.color, BqColors.ink);
    });

    test('body role — 13 / w400 / 1.4 (UI-SPEC)', () {
      final TextStyle? b = t.textTheme.bodyMedium;
      expect(b?.fontSize, 13);
      expect(b?.fontWeight, FontWeight.w400);
      expect(b?.height, 1.4);
      expect(b?.color, BqColors.ink);
    });

    test('NavigationBar theming (D-25)', () {
      final NavigationBarThemeData nav = t.navigationBarTheme;
      expect(nav.backgroundColor, BqColors.surfaceAlt);
      expect(nav.elevation, 0);
      expect(nav.indicatorColor, Colors.transparent);
    });

    test('NavigationBar label role — 10 / w500, accent/textFaint (D-25)', () {
      final NavigationBarThemeData nav = t.navigationBarTheme;
      final TextStyle? selected =
          nav.labelTextStyle?.resolve({WidgetState.selected});
      final TextStyle? unselected = nav.labelTextStyle?.resolve(const {});
      expect(selected?.fontSize, 10);
      expect(selected?.fontWeight, FontWeight.w500);
      expect(selected?.color, BqColors.accent);
      expect(unselected?.fontSize, 10);
      expect(unselected?.fontWeight, FontWeight.w500);
      expect(unselected?.color, BqColors.textFaint);
    });

    test('NavigationBar icon colors — accent selected / textFaint unselected',
        () {
      final NavigationBarThemeData nav = t.navigationBarTheme;
      final IconThemeData? selected =
          nav.iconTheme?.resolve({WidgetState.selected});
      final IconThemeData? unselected = nav.iconTheme?.resolve(const {});
      expect(selected?.color, BqColors.accent);
      expect(unselected?.color, BqColors.textFaint);
    });
  });

  group('BqText.mono — JetBrains Mono helper (UI-SPEC mono numerals)', () {
    test('defaults', () {
      final TextStyle s = BqText.mono();
      expect(s.fontFamily, 'JetBrains Mono');
      expect(s.fontSize, 11);
      expect(s.color, BqColors.textMuted);
      expect(s.fontWeight, FontWeight.w500);
      expect(s.letterSpacing, 0.5);
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('overrides', () {
      final TextStyle s = BqText.mono(
        size: 14,
        color: BqColors.ink,
        weight: FontWeight.w400,
        letterSpacing: 0,
      );
      expect(s.fontFamily, 'JetBrains Mono');
      expect(s.fontSize, 14);
      expect(s.color, BqColors.ink);
      expect(s.fontWeight, FontWeight.w400);
      expect(s.letterSpacing, 0);
    });
  });
}
