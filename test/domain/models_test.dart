import 'package:boostque/core/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DoseSlot range validation', () {
    test('minutesFromMidnight -1 throws', () {
      expect(
        () => DoseSlot(id: 'd1', minutesFromMidnight: -1, doseLabel: 'morning'),
        throwsAssertionError,
      );
    });

    test('minutesFromMidnight 1440 throws', () {
      expect(
        () =>
            DoseSlot(id: 'd1', minutesFromMidnight: 1440, doseLabel: 'night'),
        throwsAssertionError,
      );
    });

    test('minutesFromMidnight 0 is accepted', () {
      final slot =
          DoseSlot(id: 'd1', minutesFromMidnight: 0, doseLabel: 'midnight');
      expect(slot.minutesFromMidnight, 0);
    });

    test('minutesFromMidnight 1439 is accepted', () {
      final slot =
          DoseSlot(id: 'd1', minutesFromMidnight: 1439, doseLabel: 'late');
      expect(slot.minutesFromMidnight, 1439);
    });
  });

  group('Regimen range validation', () {
    test('negative onDays throws', () {
      expect(
        () => Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2026, 8, 14),
          endDate: null,
          onDays: -1,
          offDays: 0,
          paused: false,
          slots: const [],
        ),
        throwsAssertionError,
      );
    });

    test('negative offDays throws', () {
      expect(
        () => Regimen(
          id: 'r1',
          supplementId: 's1',
          kind: RegimenKind.cyclic,
          startDate: DateTime.utc(2026, 8, 14),
          endDate: null,
          onDays: 7,
          offDays: -1,
          paused: false,
          slots: const [],
        ),
        throwsAssertionError,
      );
    });

    test('course with endDate null is accepted at model level', () {
      final r = Regimen(
        id: 'r2',
        supplementId: 's1',
        kind: RegimenKind.course,
        startDate: DateTime.utc(2026, 8, 14),
        endDate: null,
        onDays: 0,
        offDays: 0,
        paused: false,
        slots: const [],
      );
      expect(r.kind, RegimenKind.course);
      expect(r.endDate, isNull);
    });
  });

  group('const constructors and final fields', () {
    // Compile-time proof: const instantiation only compiles when every
    // field is final and the constructor is const. Regimen also declares a
    // const constructor, but DateTime has no const constructor, so it
    // cannot appear in a const context — its final fields are proven by
    // the accepted-construction tests above.
    test('DoseSlot and Supplement support const instantiation', () {
      const slot =
          DoseSlot(id: 'd1', minutesFromMidnight: 480, doseLabel: 'morning');
      const supplement = Supplement(
        id: 's1',
        name: 'Creatine',
        doseText: '5 g',
        colorValue: 0xFFB08A2A,
        note: '',
      );
      expect(slot.minutesFromMidnight, 480);
      expect(supplement.name, 'Creatine');
    });

    test('enums declare the locked value sets', () {
      expect(RegimenKind.values, [RegimenKind.cyclic, RegimenKind.course]);
      expect(DoseStatus.values,
          [DoseStatus.pending, DoseStatus.taken, DoseStatus.skipped]);
    });
  });
}
