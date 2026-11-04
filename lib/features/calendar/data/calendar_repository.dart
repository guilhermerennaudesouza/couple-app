import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/couple_model.dart';
import '../../core/notifications/local_notification_service.dart';
import '../domain/calendar_event_model.dart';

/// Repository managing shared calendar events, date nights, anniversaries, and reminders.
///
/// Persisted under Cloud Firestore collection:
/// `/couples/{coupleId}/calendar_events/{eventId}`
class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _eventsCollection(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('calendar_events');
  }

  /// Watches all calendar events for a couple in real time.
  ///
  /// The stream returns events sorted chronologically by their next upcoming occurrence:
  /// upcoming events are listed first in ascending order of days remaining,
  /// followed by past non-annual events at the bottom.
  Stream<List<CalendarEventModel>> watchEvents(String coupleId) {
    return _eventsCollection(coupleId).snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => CalendarEventModel.fromMap(doc.id, doc.data()))
          .toList();

      events.sort((a, b) {
        // Active/upcoming events first, past non-annual events last
        final aPast = a.isPast();
        final bPast = b.isPast();
        if (aPast != bPast) {
          return aPast ? 1 : -1;
        }

        final aDays = a.daysUntilNext();
        final bDays = b.daysUntilNext();
        if (aDays != bDays) {
          return aDays.compareTo(bDays);
        }

        return a.title.compareTo(b.title);
      });

      return events;
    });
  }

  /// Adds or updates a calendar event with offline durability (`SetOptions(merge: true)`).
  ///
  /// Also schedules an on-device reminder alarm via [LocalNotificationService].
  Future<void> addEvent(String coupleId, CalendarEventModel event) async {
    final col = _eventsCollection(coupleId);
    final docRef = event.id.isEmpty ? col.doc() : col.doc(event.id);
    final eventToSave = event.id.isEmpty ? event.copyWith(id: docRef.id) : event;

    try {
      await docRef.set(eventToSave.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('CalendarRepository.addEvent error: $e');
    }

    // Schedule on-device notification reminder
    await LocalNotificationService.scheduleEventReminder(eventToSave);
  }

  /// Alias for [addEvent] to support save workflows.
  Future<void> saveEvent(String coupleId, CalendarEventModel event) =>
      addEvent(coupleId, event);

  /// Deletes a calendar event and cancels its scheduled local notification.
  Future<void> deleteEvent(String coupleId, String eventId) async {
    final docRef = _eventsCollection(coupleId).doc(eventId);
    try {
      await docRef.delete();
    } catch (e) {
      debugPrint('CalendarRepository.deleteEvent error: $e');
    }

    // Cancel pending notification
    await LocalNotificationService.cancelEventReminder(eventId);
  }

  /// Seeds an initial annual anniversary event into the couple's calendar
  /// if one does not already exist, derived from [couple.anniversaryDate].
  Future<void> seedAnniversaryEventIfMissing(
    String coupleId,
    CoupleModel couple,
  ) async {
    try {
      final col = _eventsCollection(coupleId);
      final snapshot = await col
          .where('category', isEqualTo: CalendarEventModel.categoryAnniversary)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        final anniversaryEvent = CalendarEventModel(
          id: 'anniversary_default',
          title: 'Our Anniversary',
          description: 'The day our love story began ❤️',
          date: couple.anniversaryDate,
          isAnnual: true,
          category: CalendarEventModel.categoryAnniversary,
          reminderDaysBefore: 7,
          createdBy: couple.members.isNotEmpty ? couple.members.first : 'system',
        );

        await col.doc(anniversaryEvent.id).set(
              anniversaryEvent.toMap(),
              SetOptions(merge: true),
            );

        await LocalNotificationService.scheduleEventReminder(anniversaryEvent);
      }
    } catch (e) {
      debugPrint('CalendarRepository.seedAnniversaryEventIfMissing error: $e');
    }
  }
}

/// Riverpod provider for [CalendarRepository].
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository();
});

/// Stream provider for all shared calendar events belonging to a couple.
final calendarEventsStreamProvider =
    StreamProvider.family<List<CalendarEventModel>, String>((ref, coupleId) {
  final repository = ref.watch(calendarRepositoryProvider);
  return repository.watchEvents(coupleId);
});
