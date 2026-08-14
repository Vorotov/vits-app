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
}
