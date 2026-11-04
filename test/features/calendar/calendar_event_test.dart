import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';

void main() {
  group('CalendarEventModel Tests', () {
    test('CalendarEvent calculates correct days until annual anniversary', () {
      final event = CalendarEventModel(
        id: 'e1',
        title: 'Our Anniversary',
        date: DateTime(2024, 5, 18),
        isAnnual: true,
        category: 'Anniversary',
        reminderDaysBefore: 7,
        createdBy: 'uid_1',
      );
      // When queried on May 10, 2026: next annual date is May 18, 2026 -> 8 days
      final daysUntil = event.daysUntilNext(from: DateTime(2026, 5, 10));
      expect(daysUntil, equals(8));

      // When queried after May 18, 2026: next annual date is May 18, 2027
      final daysUntilNextYear = event.daysUntilNext(from: DateTime(2026, 6, 1));
      expect(daysUntilNextYear, equals(351));
    });

    test('CalendarEvent non-annual events calculate past/future correctly', () {
      final event = CalendarEventModel(
        id: 'e2',
        title: 'Dinner at Italian Place',
        date: DateTime(2026, 11, 10),
        isAnnual: false,
        category: 'Date Night',
        reminderDaysBefore: 1,
        createdBy: 'uid_2',
      );
      expect(event.daysUntilNext(from: DateTime(2026, 11, 4)), equals(6));
      expect(event.isPast(from: DateTime(2026, 11, 12)), isTrue);
      expect(event.isPast(from: DateTime(2026, 11, 8)), isFalse);
    });

    test('CalendarEventModel serialization round-trip maintains all fields', () {
      final originalDate = DateTime(2026, 12, 25, 19, 30);
      final createdAt = DateTime(2026, 11, 1, 10, 0);
      final event = CalendarEventModel(
        id: 'e3',
        title: 'Christmas Getaway',
        description: 'Cabin in the mountains with a fireplace',
        date: originalDate,
        isAnnual: false,
        category: CalendarEventModel.categoryTravel,
        reminderDaysBefore: 3,
        createdBy: 'uid_alex',
        createdAt: createdAt,
      );

      final map = event.toMap();
      final restored = CalendarEventModel.fromMap('e3', map);

      expect(restored.id, equals('e3'));
      expect(restored.title, equals('Christmas Getaway'));
      expect(restored.description, equals('Cabin in the mountains with a fireplace'));
      expect(restored.date.year, equals(2026));
      expect(restored.date.month, equals(12));
      expect(restored.date.day, equals(25));
      expect(restored.isAnnual, isFalse);
      expect(restored.category, equals(CalendarEventModel.categoryTravel));
      expect(restored.reminderDaysBefore, equals(3));
      expect(restored.createdBy, equals('uid_alex'));
      expect(restored.createdAt.isAtSameMomentAs(createdAt), isTrue);
    });

    test('CalendarEventModel copyWith and value equality', () {
      final date = DateTime(2027, 2, 14);
      final event1 = CalendarEventModel(
        id: 'e4',
        title: "Valentine's Day Dinner",
        date: date,
        isAnnual: true,
        category: CalendarEventModel.categoryDateNight,
      );
      final event2 = CalendarEventModel(
        id: 'e4',
        title: "Valentine's Day Dinner",
        date: date,
        isAnnual: true,
        category: CalendarEventModel.categoryDateNight,
        createdAt: event1.createdAt,
      );

      expect(event1, equals(event2));
      expect(event1.hashCode, equals(event2.hashCode));

      final updated = event1.copyWith(
        title: 'Romantic Candlelight Dinner',
        reminderDaysBefore: 2,
      );
      expect(updated.title, equals('Romantic Candlelight Dinner'));
      expect(updated.reminderDaysBefore, equals(2));
      expect(updated.id, equals('e4'));
      expect(updated.isAnnual, isTrue);
    });

    test('CalendarEventModel resilient date parsing handles epoch int and toDate objects', () {
      final fakeTimestamp = _FakeTimestamp(DateTime(2026, 8, 15, 14, 0));
      final mapWithTimestamp = {
        'title': 'Summer Beach Trip',
        'description': 'Weekend at the coast',
        'date': fakeTimestamp,
        'isAnnual': false,
        'category': 'Travel',
        'reminderDaysBefore': 5,
        'createdBy': 'uid_1',
      };

      final eventFromTimestamp =
          CalendarEventModel.fromMap('e_ts', mapWithTimestamp);
      expect(eventFromTimestamp.date.year, equals(2026));
      expect(eventFromTimestamp.date.month, equals(8));
      expect(eventFromTimestamp.date.day, equals(15));

      final mapWithEpoch = {
        'title': 'Partner Birthday',
        'date': 1731628800000,
        'isAnnual': true,
        'category': 'Birthday',
        'reminderDaysBefore': 1,
        'createdBy': 'uid_2',
      };

      final eventFromEpoch = CalendarEventModel.fromMap('e_epoch', mapWithEpoch);
      expect(eventFromEpoch.date.millisecondsSinceEpoch, equals(1731628800000));
    });

    test('CalendarEventModel handles leap year February 29 anniversary properly', () {
      // Leap year leap day anniversary (Feb 29, 2024)
      final leapEvent = CalendarEventModel(
        id: 'leap_1',
        title: 'Leap Day Anniversary',
        date: DateTime(2024, 2, 29),
        isAnnual: true,
        category: 'Anniversary',
      );

      // In non-leap year 2025, queried on Feb 20, 2025: should target Feb 28, 2025 -> 8 days
      final daysInNonLeapYear = leapEvent.daysUntilNext(from: DateTime(2025, 2, 20));
      expect(daysInNonLeapYear, equals(8));

      // In next leap year 2028, queried on Feb 20, 2028: should target Feb 29, 2028 -> 9 days
      final daysInNextLeapYear = leapEvent.daysUntilNext(from: DateTime(2028, 2, 20));
      expect(daysInNextLeapYear, equals(9));
    });

    test('CalendarEventModel DST-safe daysUntilNext computes exact days across clock changes', () {
      final event = CalendarEventModel(
        id: 'dst_event',
        title: 'Spring Date',
        date: DateTime(2026, 3, 15),
        isAnnual: false,
      );
      // Query 5 days before
      final days = event.daysUntilNext(from: DateTime(2026, 3, 10));
      expect(days, equals(5));
    });
  });

  group('LocalNotificationService Tests', () {
    test('LocalNotificationService methods complete safely in test environment', () async {
      await expectLater(LocalNotificationService.initialize(), completes);
      await expectLater(
        LocalNotificationService.scheduleDailyPrompt(hour: 20, minute: 0),
        completes,
      );

      final event = CalendarEventModel(
        id: 'notif_test',
        title: 'Test Date Night',
        date: DateTime.now().add(const Duration(days: 3)),
        reminderDaysBefore: 1,
      );

      await expectLater(
        LocalNotificationService.scheduleEventReminder(event),
        completes,
      );
      await expectLater(
        LocalNotificationService.cancelEventReminder('notif_test'),
        completes,
      );
      await expectLater(LocalNotificationService.cancelAll(), completes);
    });
  });
}

class _FakeTimestamp {
  final DateTime _dt;
  _FakeTimestamp(this._dt);
  DateTime toDate() => _dt;
}
