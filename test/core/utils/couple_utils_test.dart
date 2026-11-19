import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/utils/couple_date_utils.dart';
import 'package:couple_app/core/utils/currency_parser.dart';
import 'package:couple_app/core/utils/photo_budget_utils.dart';
import 'package:couple_app/core/notifications/notification_route_provider.dart';
import 'package:couple_app/features/wishlist/domain/wish_model.dart';

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

  group('PhotoBudgetUtils & WishModel', () {
    test('PhotoBudgetUtils enforces max 4 photos and 850KB Firestore document budget', () {
      final small = 'data:image/jpeg;base64,${'A' * 1000}';
      expect(
        PhotoBudgetUtils.canAddPhoto(
          existingDataUris: [small, small, small],
          candidateDataUri: small,
        ),
        isTrue,
      );
      expect(
        PhotoBudgetUtils.canAddPhoto(
          existingDataUris: [small, small, small, small],
          candidateDataUri: small,
        ),
        isFalse,
      );
      final huge = 'data:image/jpeg;base64,${'A' * (900 * 1024)}';
      expect(
        PhotoBudgetUtils.canAddPhoto(
          existingDataUris: const [],
          candidateDataUri: huge,
        ),
        isFalse,
      );
    });

    test('PhotoBudgetUtils decodeCachedBase64 caches decoded bytes', () {
      final uri = 'data:image/jpeg;base64,${base64Encode([1, 2, 3, 4])}';
      final first = PhotoBudgetUtils.decodeCachedBase64(uri);
      final second = PhotoBudgetUtils.decodeCachedBase64(uri);
      expect(first, equals([1, 2, 3, 4]));
      expect(identical(first, second), isTrue);
    });

    test('WishModel parses Brazilian decimal prices and includes isSecretRadar/occasion in equality', () {
      final a = WishModel.fromMap('w1', {
        'title': 'Perfume',
        'estimatedPrice': '150,50',
        'isSecretRadar': true,
        'occasion': 'Aniversário',
      });
      final b = a.copyWith(isSecretRadar: false);
      final c = a.copyWith(occasion: 'Natal');
      expect(a.estimatedPrice, 150.50);
      expect(a == b, isFalse);
      expect(a == c, isFalse);
    });
  });

  group('NotificationRoute mapping', () {
    test('parseRouteToTabIndex maps payloads to exact tabs or pushed screens', () {
      expect(parseRouteToTabIndex('daily_question'), 0);
      expect(parseRouteToTabIndex('couple'), 0);
      expect(parseRouteToTabIndex('tasks'), 1);
      expect(parseRouteToTabIndex('task:abc123'), 1);
      expect(parseRouteToTabIndex('calendar_event:ev1'), 2);
      expect(parseRouteToTabIndex('decide'), 3);
      expect(parseRouteToTabIndex('notes'), isNull);
      expect(parseRouteToTabIndex('cycle'), isNull);
      expect(parseRouteToTabIndex('adult_games'), isNull);
    });
  });
}
