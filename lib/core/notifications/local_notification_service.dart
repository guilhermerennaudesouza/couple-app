import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/calendar/domain/calendar_event_model.dart';
import '../../features/home/domain/activity_state_model.dart';
import '../../features/tasks/domain/task_model.dart';

/// Central local notification scheduler for the Couple App.
///
/// Dispatches on-device local notifications using [FlutterLocalNotificationsPlugin]
/// without requiring paid push servers or exceeding Firebase Spark limits:
/// - Channel 1 ("Urgentes do Par"): SOS Carinho, Saudade/Carinho, Convite Picante.
/// - Channel 2 ("Rotina do Casal"): Pergunta do Dia, Tarefas, Calendário, Recados, Cupons.
class LocalNotificationService {
  static const String routineChannelId = 'krivo_couples_channel';
  static const String routineChannelName = 'Rotina do Casal';
  static const String routineChannelDescription =
      'Pergunta do Dia, tarefas, calendário, recados e cupons do casal';

  static const String urgentChannelId = 'krivo_urgent_partner_channel';
  static const String urgentChannelName = 'Urgentes do Par';
  static const String urgentChannelDescription =
      'SOS Carinho, Saudade/Beijo e Convite Picante com alerta prioritário';

  static const String channelId = routineChannelId;
  static const String channelName = routineChannelName;
  static const String channelDescription = routineChannelDescription;

  static const int dailyPromptNotificationId = 1001;
  static const int anniversaryPromptNotificationId = 2001;

  /// Routes an activity event type to either [urgentChannelId] or [routineChannelId].
  static String channelIdForEventType(String eventType) {
    return ActivityStateModel.isUrgentEventType(eventType)
        ? urgentChannelId
        : routineChannelId;
  }

  static FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static void Function(String payload)? _onNotificationTap;

  /// Registers a tap handler for active/background notification clicks.
  static void setNotificationTapHandler(void Function(String payload)? handler) {
    _onNotificationTap = handler;
  }

  /// Returns the notification payload if the app was cold-launched by tapping
  /// a local notification, or `null` otherwise.
  static Future<String?> consumeLaunchRoute() async {
    try {
      final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final payload = details.notificationResponse?.payload;
        if (payload != null && payload.trim().isNotEmpty) {
          return payload.trim();
        }
      }
    } catch (e) {
      debugPrint('LocalNotificationService.consumeLaunchRoute error: $e');
    }
    return null;
  }

  /// Allows replacing the notification plugin in unit tests.
  @visibleForTesting
  static void setMockPlugin(FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
  }

  /// Initializes the local notification plugin, real device timezone (with
  /// `America/Sao_Paulo` fallback), and high-importance Android channel.
  static Future<void> initialize({
    void Function(String payload)? onNotificationTap,
  }) async {
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    try {
      // Initialize timezone database and set actual device local timezone
      try {
        tz.initializeTimeZones();
        String tzId = 'America/Sao_Paulo';
        try {
          final info = await FlutterTimezone.getLocalTimezone();
          if (info.identifier.trim().isNotEmpty) {
            tzId = info.identifier.trim();
          }
        } catch (tzLookupErr) {
          debugPrint('LocalNotificationService: timezone lookup fallback to BRT: $tzLookupErr');
        }
        try {
          tz.setLocalLocation(tz.getLocation(tzId));
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
        }
      } catch (tzErr) {
        debugPrint('LocalNotificationService: timezone init fallback: $tzErr');
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          final payload = details.payload;
          debugPrint('LocalNotificationService: payload clicked: $payload');
          if (payload != null && payload.trim().isNotEmpty) {
            _onNotificationTap?.call(payload.trim());
          }
        },
      );

      // Configure both Android notification channels (Urgent vs Routine)
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        const routineChannel = AndroidNotificationChannel(
          routineChannelId,
          routineChannelName,
          description: routineChannelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
        const urgentChannel = AndroidNotificationChannel(
          urgentChannelId,
          urgentChannelName,
          description: urgentChannelDescription,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidImplementation.createNotificationChannel(routineChannel);
        await androidImplementation.createNotificationChannel(urgentChannel);
        await androidImplementation.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('LocalNotificationService.initialize error: $e');
    }
  }

  /// Builds standard high-priority notification details.
  static NotificationDetails _notificationDetails({
    String channelId = channelId,
    String channelName = channelName,
    String channelDescription = channelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Computes the next occurrence of a specific time in the local timezone.
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      return scheduledDate;
    } catch (_) {
      // Fallback for uninitialized local timezone in test environments
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      return tz.TZDateTime.from(scheduledDate, tz.UTC);
    }
  }

  /// Schedules the recurring daily notification prompting partners to answer
  /// today's Daily Question.
  ///
  /// Uses zonedSchedule targeting exact local time (default 20:00 / 8:00 PM) daily:
  /// "Time for your Daily Question! Answer together tonight ✨"
  static Future<void> scheduleDailyPrompt({
    int hour = 20,
    int minute = 0,
  }) async {
    try {
      final scheduledTime = _nextInstanceOfTime(hour, minute);
      await _notificationsPlugin.zonedSchedule(
        dailyPromptNotificationId,
        'Pergunta do Dia ✨',
        'Hora da Pergunta do Dia! Respondam juntos hoje à noite ✨',
        scheduledTime,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_question',
      );
    } catch (e) {
      debugPrint('LocalNotificationService.scheduleDailyPrompt error: $e');
      // Graceful fallback to periodicallyShow if zoned scheduling fails in test/headless
      try {
        await _notificationsPlugin.periodicallyShow(
          dailyPromptNotificationId,
          'Pergunta do Dia ✨',
          'Hora da Pergunta do Dia! Respondam juntos hoje à noite ✨',
          RepeatInterval.daily,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (_) {}
    }
  }

  /// Schedules an event or anniversary alarm [event.reminderDaysBefore] days
  /// prior to the event date at 10:00 AM using exact zoned scheduling.
  ///
  /// When [showIfDueNow] is `false` (default for reactive background sync),
  /// alarms whose trigger time has already passed are skipped instead of
  /// repeatedly firing immediate `show()` notifications.
  static Future<void> scheduleEventReminder(
    CalendarEventModel event, {
    bool showIfDueNow = false,
  }) async {
    try {
      final reminderId = (event.id.hashCode.abs() % 100000) + 3000;
      final title = event.category == CalendarEventModel.categoryAnniversary
          ? 'Lembrete de Aniversário ❤️'
          : 'Em breve: ${event.title}';

      final String body;
      if (event.reminderDaysBefore == 0) {
        body = 'Hoje é ${event.title}! Aproveitem momentos especiais juntos 💕';
      } else if (event.reminderDaysBefore == 1) {
        body = 'Amanhã é ${event.title}! Já está tudo pronto? 💕';
      } else {
        body = 'Faltam ${event.reminderDaysBefore} dias para ${event.title}! 💕';
      }

      final nextOcc = event.nextOccurrenceDate();
      final reminderDay =
          nextOcc.subtract(Duration(days: event.reminderDaysBefore));

      tz.TZDateTime scheduledDate;
      try {
        scheduledDate = tz.TZDateTime(
          tz.local,
          reminderDay.year,
          reminderDay.month,
          reminderDay.day,
          10, // 10:00 AM
          0,
        );
      } catch (_) {
        scheduledDate = tz.TZDateTime.from(
          DateTime(reminderDay.year, reminderDay.month, reminderDay.day, 10, 0),
          tz.UTC,
        );
      }

      final tz.TZDateTime now = tz.TZDateTime.now(scheduledDate.location);

      if (scheduledDate.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          reminderId,
          title,
          body,
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'calendar_event:${event.id}',
        );
      } else if (showIfDueNow && !event.isPast()) {
        // Explicit user-initiated immediate reminder when due today
        await _notificationsPlugin.show(
          reminderId,
          title,
          body,
          _notificationDetails(),
          payload: 'calendar_event:${event.id}',
        );
      }
    } catch (e) {
      debugPrint('LocalNotificationService.scheduleEventReminder error: $e');
    }
  }

  /// Cancels an active reminder for a specific calendar event.
  static Future<void> cancelEventReminder(String eventId) async {
    try {
      final reminderId = (eventId.hashCode.abs() % 100000) + 3000;
      await _notificationsPlugin.cancel(reminderId);
    } catch (e) {
      debugPrint('LocalNotificationService.cancelEventReminder error: $e');
    }
  }

  /// Schedules a local 09:00 reminder on [task.dueDate] for incomplete tasks.
  static Future<void> scheduleTaskReminder(TaskModel task) async {
    if (task.isCompleted || task.dueDate == null) return;
    try {
      final due = task.dueDate!;
      final reminderId = (task.id.hashCode.abs() % 50000) + 140000;
      tz.TZDateTime scheduledDate;
      try {
        scheduledDate = tz.TZDateTime(
          tz.local,
          due.year,
          due.month,
          due.day,
          9,
          0,
        );
      } catch (_) {
        scheduledDate = tz.TZDateTime.from(
          DateTime(due.year, due.month, due.day, 9, 0),
          tz.UTC,
        );
      }

      final now = tz.TZDateTime.now(scheduledDate.location);
      if (scheduledDate.isAfter(now)) {
        await _notificationsPlugin.zonedSchedule(
          reminderId,
          'Tarefa de Hoje ☑️',
          'Lembrete do casal: ${task.title}',
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'task:${task.id}',
        );
      }
    } catch (e) {
      debugPrint('LocalNotificationService.scheduleTaskReminder error: $e');
    }
  }

  /// Cancels a scheduled task due-date reminder.
  static Future<void> cancelTaskReminder(String taskId) async {
    try {
      final reminderId = (taskId.hashCode.abs() % 50000) + 140000;
      await _notificationsPlugin.cancel(reminderId);
    } catch (e) {
      debugPrint('LocalNotificationService.cancelTaskReminder error: $e');
    }
  }

  /// Displays an immediate partner alert routed to either the Urgent or Routine
  /// Android channel based on [eventType].
  static Future<void> showPartnerAlert({
    required String eventId,
    required String eventType,
    required String title,
    required String body,
    required String route,
  }) async {
    try {
      final isUrgent = ActivityStateModel.isUrgentEventType(eventType);
      final notifId = (eventId.hashCode.abs() % 50000) + 200000;
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          isUrgent ? urgentChannelId : routineChannelId,
          isUrgent ? urgentChannelName : routineChannelName,
          channelDescription:
              isUrgent ? urgentChannelDescription : routineChannelDescription,
          importance: isUrgent ? Importance.max : Importance.high,
          priority: isUrgent ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        notifId,
        title.trim().isNotEmpty ? title.trim() : 'Novidade do seu amor 💕',
        body.trim().isNotEmpty ? body.trim() : 'Abra o app para ver!',
        details,
        payload: route.trim().isNotEmpty ? route.trim() : 'home',
      );
    } catch (e) {
      debugPrint('LocalNotificationService.showPartnerAlert error: $e');
    }
  }

  /// Cancels all scheduled local notifications and alarms.
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('LocalNotificationService.cancelAll error: $e');
    }
  }
}
