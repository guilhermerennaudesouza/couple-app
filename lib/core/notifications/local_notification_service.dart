import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/calendar/domain/calendar_event_model.dart';

/// Central local notification scheduler for the Couple App.
///
/// Dispatches on-device local notifications using [FlutterLocalNotificationsPlugin]
/// without requiring paid push servers or exceeding Firebase Spark limits:
/// - Exact 20:00 (8:00 PM) daily question prompts using [zonedSchedule].
/// - Calendar anniversary countdowns and event alarms scheduled N days prior at 10:00 AM.
class LocalNotificationService {
  static const String channelId = 'krivo_couples_channel';
  static const String channelName = 'Lembretes e Perguntas do Casal';
  static const String channelDescription =
      'Perguntas diárias, aniversários e lembretes de encontros';

  static const int dailyPromptNotificationId = 1001;
  static const int anniversaryPromptNotificationId = 2001;

  static FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Allows replacing the notification plugin in unit tests.
  @visibleForTesting
  static void setMockPlugin(FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
  }

  /// Initializes the local notification plugin, timezones, and configures the Android
  /// high-importance notification channel.
  ///
  /// Executed safely in a try/catch block to avoid crashing on unsupported
  /// test harnesses or missing OS permissions.
  static Future<void> initialize() async {
    try {
      // Initialize timezone database for zoned scheduling
      try {
        tz.initializeTimeZones();
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
          debugPrint('LocalNotificationService: payload clicked: ${details.payload}');
        },
      );

      // Configure Android notification channel with high priority
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );
        await androidImplementation.createNotificationChannel(channel);
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
  static Future<void> scheduleEventReminder(CalendarEventModel event) async {
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
      } else if (!event.isPast()) {
        // Notification is due today or immediately
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

  /// Cancels all scheduled local notifications and alarms.
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('LocalNotificationService.cancelAll error: $e');
    }
  }
}
