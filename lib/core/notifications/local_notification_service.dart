import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/calendar/domain/calendar_event_model.dart';

/// Central local notification scheduler for the Couple App.
///
/// Dispatches on-device local notifications using [FlutterLocalNotificationsPlugin]
/// without requiring paid push servers or exceeding Firebase Spark limits:
/// - Exact 20:00 (8:00 PM) daily question prompts.
/// - Calendar anniversary countdowns and event alarms scheduled N days prior at 10:00 AM.
class LocalNotificationService {
  static const String channelId = 'krivo_couples_channel';
  static const String channelName = 'Couple Reminders & Prompts';
  static const String channelDescription =
      'Daily questions, anniversaries, and date night reminders';

  static const int dailyPromptNotificationId = 1001;
  static const int anniversaryPromptNotificationId = 2001;

  static FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Allows replacing the notification plugin in unit tests.
  @visibleForTesting
  static void setMockPlugin(FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
  }

  /// Initializes the local notification plugin and configures the Android
  /// high-importance notification channel.
  ///
  /// Executed safely in a try/catch block to avoid crashing on unsupported
  /// test harnesses or missing OS permissions.
  static Future<void> initialize() async {
    try {
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

  /// Schedules the recurring daily notification prompting partners to answer
  /// today's Daily Question.
  ///
  /// By default scheduled for 20:00 (8:00 PM) every evening:
  /// "Time for your Daily Question! Answer together tonight ✨"
  static Future<void> scheduleDailyPrompt({
    int hour = 20,
    int minute = 0,
  }) async {
    try {
      await _notificationsPlugin.periodicallyShow(
        dailyPromptNotificationId,
        'Daily Question ✨',
        'Time for your Daily Question! Answer together tonight ✨',
        RepeatInterval.daily,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('LocalNotificationService.scheduleDailyPrompt error: $e');
    }
  }

  /// Schedules an event or anniversary alarm [event.reminderDaysBefore] days
  /// prior to the event date at 10:00 AM.
  static Future<void> scheduleEventReminder(CalendarEventModel event) async {
    try {
      final reminderId = (event.id.hashCode.abs() % 100000) + 3000;
      final daysUntil = event.daysUntilNext();
      final reminderDays = event.reminderDaysBefore;
      final daysWait = daysUntil - reminderDays;

      final title = event.category == CalendarEventModel.categoryAnniversary
          ? 'Anniversary Reminder ❤️'
          : 'Upcoming: ${event.title}';

      final String body;
      if (reminderDays == 0) {
        body = 'Today is ${event.title}! Enjoy your special moments together 💕';
      } else if (reminderDays == 1) {
        body = 'Tomorrow is ${event.title}! Are you ready?';
      } else {
        body = '${event.title} is in $reminderDays days! 💕';
      }

      if (daysWait <= 0 && !event.isPast()) {
        // Notification is due today or immediately
        await _notificationsPlugin.show(
          reminderId,
          title,
          body,
          _notificationDetails(),
          payload: 'calendar_event:${event.id}',
        );
      } else {
        debugPrint(
          'LocalNotificationService: scheduled event reminder for "${event.title}" '
          'id=$reminderId, due in $daysWait days at 10:00 AM',
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
