import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/cycle/domain/cycle_model.dart';

void main() {
  group('CycleDataModel upgrade & daily symptom reset', () {
    test('fromMap(null) produces unconfigured state instead of fake pre-configured dates', () {
      final cycle = CycleDataModel.fromMap(null);
      expect(cycle.isConfigured, isFalse);
    });

    test('fromMap with existing lastPeriodStart preserves configured state for legacy docs', () {
      final cycle = CycleDataModel.fromMap({
        'lastPeriodStart': '2026-11-10T00:00:00.000',
        'cycleLength': 28,
        'periodDuration': 5,
      });
      expect(cycle.isConfigured, isTrue);
    });

    test('activeTodaySymptoms resets automatically when symptomsDate is from a previous day', () {
      final cycle = CycleDataModel(
        lastPeriodStart: DateTime(2026, 11, 10),
        isConfigured: true,
        currentSymptoms: const ['Cólica 🩸', 'Cansaço 😴'],
        symptomsDate: '2026-11-18',
      );
      expect(
        cycle.activeTodaySymptoms(today: DateTime(2026, 11, 18)),
        equals(['Cólica 🩸', 'Cansaço 😴']),
      );
      expect(
        cycle.activeTodaySymptoms(today: DateTime(2026, 11, 19)),
        isEmpty,
      );
    });
  });
}
