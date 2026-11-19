import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/calendar/data/calendar_repository.dart';
import '../../features/tasks/data/task_repository.dart';
import 'local_notification_service.dart';

/// Shared pending deep-link route triggered by tapping a local notification
/// or an Android Jetpack Glance home-screen widget.
final pendingNotificationRouteProvider = StateProvider<String?>((ref) => null);

/// Maps a notification/widget route payload to a root [MainNavigationShell] tab index,
/// or returns `null` if the payload should push a secondary feature screen instead.
int? parseRouteToTabIndex(String? payload) {
  if (payload == null || payload.trim().isEmpty) return null;
  final route = payload.trim();
  if (route == 'daily_question' || route == 'couple' || route == 'home') {
    return 0;
  }
  if (route == 'tasks' || route.startsWith('task:')) {
    return 1;
  }
  if (route == 'calendar' || route.startsWith('calendar_event:')) {
    return 2;
  }
  if (route == 'decide' || route.startsWith('decide:')) {
    return 3;
  }
  if (route == 'hub') {
    return 4;
  }
  return null;
}

/// Reactively keeps local calendar event and task reminders scheduled on BOTH
/// partners' Android devices whenever Firestore streams update.
final reminderSyncProvider = Provider.family<void, String>((ref, coupleId) {
  if (coupleId.trim().isEmpty) return;

  final events =
      ref.watch(calendarEventsStreamProvider(coupleId)).valueOrNull ?? const [];
  final tasks =
      ref.watch(tasksStreamProvider(coupleId)).valueOrNull ?? const [];

  final timer = Timer(const Duration(milliseconds: 500), () async {
    for (final event in events) {
      if (!event.isPast()) {
        await LocalNotificationService.scheduleEventReminder(event);
      }
    }
    for (final task in tasks) {
      if (task.dueDate != null) {
        if (task.isCompleted) {
          await LocalNotificationService.cancelTaskReminder(task.id);
        } else {
          await LocalNotificationService.scheduleTaskReminder(task);
        }
      }
    }
  });

  ref.onDispose(timer.cancel);
});
