import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/utils/couple_date_utils.dart';
import 'package:couple_app/core/utils/currency_parser.dart';

void main() {
  group('parseBrlCurrency', () {
    test('parses Brazilian and decimal inputs accurately', () {
      expect(parseBrlCurrency('150,50'), 150.50);
      expect(parseBrlCurrency('1.250,90'), 1250.90);
      expect(parseBrlCurrency('R\$ 89,90'), 89.90);
      expect(parseBrlCurrency('150.50'), 150.50);
      expect(parseBrlCurrency('1200'), 1200.0);
      expect(parseBrlCurrency('0,99'), 0.99);
      expect(parseBrlCurrency(''), isNull);
      expect(parseBrlCurrency('abc'), isNull);
      expect(parseBrlCurrency('-50,00'), isNull);
    });
  });

  group('CoupleDateUtils', () {
    test('daysTogether normalizes date boundaries across midnight and clamps future dates', () {
      final anniv = DateTime(2025, 11, 18, 23, 55);
      expect(
        CoupleDateUtils.daysTogether(anniv, now: DateTime(2025, 11, 19, 0, 5)),
        1,
      );
      expect(
        CoupleDateUtils.daysTogether(
          DateTime(2027, 1, 1),
          now: DateTime(2026, 11, 19),
        ),
        0,
      );
      expect(
        CoupleDateUtils.daysTogether(
          DateTime(2026, 11, 19, 10, 0),
          now: DateTime(2026, 11, 19, 23, 59),
        ),
        0,
      );
    });

    test('isDateOverdue does not flag tasks due today as overdue', () {
      final now = DateTime(2026, 11, 19, 18, 30);
      expect(
        CoupleDateUtils.isDateOverdue(DateTime(2026, 11, 19, 0, 0), now: now),
        isFalse,
      );
      expect(
        CoupleDateUtils.isDateToday(DateTime(2026, 11, 19, 0, 0), now: now),
        isTrue,
      );
      expect(
        CoupleDateUtils.isDateOverdue(DateTime(2026, 11, 18, 23, 59), now: now),
        isTrue,
      );
    });

    test('formatDateKey produces padded YYYY-MM-DD', () {
      expect(CoupleDateUtils.formatDateKey(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });
}
