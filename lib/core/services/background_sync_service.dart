import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:couple_app/core/firebase/firebase_config.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

/// Top-level background entry point required by Android `WorkManager`.
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await BackgroundSyncService.runBackgroundSyncOnce();
      return true;
    } catch (e) {
      debugPrint('backgroundSyncCallbackDispatcher error: $e');
      return false;
    }
  });
}

@immutable
class BackgroundSyncResult {
  final bool didNotify;
  final bool didUpdateWidgets;

  const BackgroundSyncResult({
    required this.didNotify,
    required this.didUpdateWidgets,
  });
}

/// 100% Firebase Spark ($0) Android periodic background sync (~15 min).
///
/// Performs **1 Firestore read** on `/couples/{coupleId}/activity_state/latest`,
/// deduplicates partner notifications via `SharedPreferences`, fires a channel-routed
/// local notification when a brand-new partner event arrives, and refreshes all
/// 4 Jetpack Glance home-screen widgets from the embedded compact snapshot.
class BackgroundSyncService {
  static const String uniquePeriodicTaskName = 'krivo_couple_periodic_sync_v1';
  static const String taskIdentifier = 'krivo_couple_periodic_sync';

  static const String prefCoupleId = 'bg_couple_id';
  static const String prefMyUid = 'bg_my_uid';
  static const String prefIsPt = 'bg_is_pt';
  static const String prefLastNotifiedEventId = 'last_notified_event_id';

  static bool _initialized = false;

  /// Initializes Android WorkManager with [backgroundSyncCallbackDispatcher].
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Workmanager().initialize(backgroundSyncCallbackDispatcher);
      _initialized = true;
    } catch (e) {
      debugPrint('BackgroundSyncService.initialize warning: $e');
    }
  }

  /// Stores the active paired session context in `SharedPreferences` (safe when
  /// device screen is locked in Doze mode) and registers the 15-min periodic worker.
  static Future<void> registerPeriodicSync({
    required String coupleId,
    required String myUid,
    required bool isPortuguese,
    String? seedLastEventId,
  }) async {
    if (coupleId.trim().isEmpty || myUid.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefCoupleId, coupleId.trim());
      await prefs.setString(prefMyUid, myUid.trim());
      await prefs.setBool(prefIsPt, isPortuguese);
      if (seedLastEventId != null &&
          seedLastEventId.isNotEmpty &&
          (prefs.getString(prefLastNotifiedEventId)?.isEmpty ?? true)) {
        await prefs.setString(prefLastNotifiedEventId, seedLastEventId);
      }

      await Workmanager().registerPeriodicTask(
        uniquePeriodicTaskName,
        taskIdentifier,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('BackgroundSyncService.registerPeriodicSync warning: $e');
    }
  }

  /// Records an event ID already seen in the foreground so WorkManager won't
  /// re-notify the same event later.
  static Future<void> markEventSeenInForeground(String eventId) async {
    if (eventId.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefLastNotifiedEventId, eventId.trim());
    } catch (_) {}
  }

  /// Cancels the periodic worker and clears background session metadata on Unpair.
  static Future<void> cancelPeriodicSync() async {
    try {
      await Workmanager().cancelByUniqueName(uniquePeriodicTaskName);
    } catch (e) {
      debugPrint('BackgroundSyncService.cancelPeriodicSync warning: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefCoupleId);
      await prefs.remove(prefMyUid);
      await prefs.remove(prefIsPt);
      await prefs.remove(prefLastNotifiedEventId);
    } catch (e) {
      debugPrint('BackgroundSyncService.clearPrefs warning: $e');
    }
  }

  /// Pure unit-testable evaluator for a fetched [ActivityStateModel].
  static Future<BackgroundSyncResult> processActivityPayload({
    required ActivityStateModel state,
    required String myUid,
    required String? lastNotifiedEventId,
    required Future<void> Function({
      required String eventId,
      required String eventType,
      required String title,
      required String body,
      required String route,
    }) onNotify,
    required Future<void> Function(String eventId) onSaveLastNotifiedId,
    required Future<void> Function(Map<String, dynamic> snapshot) onSyncWidgets,
  }) async {
    bool didNotify = false;
    bool didUpdateWidgets = false;

    final hasNewPartnerEvent = state.lastEventId.isNotEmpty &&
        state.lastEventId != lastNotifiedEventId &&
        state.lastActorUid.isNotEmpty &&
        state.lastActorUid != myUid;

    if (hasNewPartnerEvent) {
      await onNotify(
        eventId: state.lastEventId,
        eventType: state.lastEventType,
        title: state.title,
        body: state.body,
        route: state.route,
      );
      await onSaveLastNotifiedId(state.lastEventId);
      didNotify = true;
    }

    if (state.widgetSnapshot.isNotEmpty) {
      await onSyncWidgets(state.widgetSnapshot);
      didUpdateWidgets = true;
    }

    return BackgroundSyncResult(
      didNotify: didNotify,
      didUpdateWidgets: didUpdateWidgets,
    );
  }

  /// Executes a single background sync cycle (1 Firestore read).
  static Future<void> runBackgroundSyncOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final coupleId = prefs.getString(prefCoupleId)?.trim() ?? '';
    final myUid = prefs.getString(prefMyUid)?.trim() ?? '';
    final isPt = prefs.getBool(prefIsPt) ?? true;
    final lastNotifiedId = prefs.getString(prefLastNotifiedEventId);

    // Unpaired device: exit cleanly with 0 network reads
    if (coupleId.isEmpty || myUid.isEmpty) return;

    await FirebaseConfig.initialize();
    await LocalNotificationService.initialize();
    await WidgetSyncService.initialize();

    final doc = await FirebaseFirestore.instance
        .collection('couples')
        .doc(coupleId)
        .collection('activity_state')
        .doc('latest')
        .get();

    if (!doc.exists || doc.data() == null) return;
    final state = ActivityStateModel.fromMap(doc.data());

    await processActivityPayload(
      state: state,
      myUid: myUid,
      lastNotifiedEventId: lastNotifiedId,
      onNotify: ({
        required eventId,
        required eventType,
        required title,
        required body,
        required route,
      }) async {
        await LocalNotificationService.showPartnerAlert(
          eventId: eventId,
          eventType: eventType,
          title: title,
          body: body,
          route: route,
        );
      },
      onSaveLastNotifiedId: (eventId) async {
        await prefs.setString(prefLastNotifiedEventId, eventId);
      },
      onSyncWidgets: (snapshot) async {
        await applyCompactWidgetSnapshotToGlance(
          snapshot: snapshot,
          myUid: myUid,
          isPortuguese: isPt,
        );
      },
    );
  }

  /// Updates all 4 Jetpack Glance widgets directly from `activity_state/latest`'s
  /// compact `widgetSnapshot` map without requiring additional Firestore reads.
  static Future<void> applyCompactWidgetSnapshotToGlance({
    required Map<String, dynamic> snapshot,
    required String myUid,
    required bool isPortuguese,
  }) async {
    try {
      final lang = isPortuguese ? 'pt' : 'en';
      await HomeWidget.saveWidgetData<String>('language', lang);
      await HomeWidget.saveWidgetData<String>('app_locale', lang);

      // 1. Couple Stats + Streak widget
      final annivIso = snapshot['anniversaryIso'] as String?;
      final streak = (snapshot['dailyStreak'] as num?)?.toInt() ?? 0;
      String partnerName = isPortuguese ? 'Seu Amor' : 'Partner';
      final rawNames = snapshot['partnerNames'];
      if (rawNames is Map) {
        for (final entry in rawNames.entries) {
          if (entry.key.toString() != myUid &&
              entry.value.toString().trim().isNotEmpty) {
            partnerName = entry.value.toString().trim();
            break;
          }
        }
      }
      if (annivIso != null && annivIso.isNotEmpty) {
        final parsed = DateTime.tryParse(annivIso);
        if (parsed != null) {
          await WidgetSyncService.syncCoupleStats(
            anniversary: parsed,
            partnerName: partnerName,
            dailyStreak: streak,
            isPortuguese: isPortuguese,
          );
        }
      }

      // 2. Pinned Note widget (already privacy-masked when saved)
      final rawNote = snapshot['pinnedNote'];
      if (rawNote is Map) {
        await HomeWidget.saveWidgetData<String>(
          'note_id',
          rawNote['id']?.toString() ?? '',
        );
        await HomeWidget.saveWidgetData<String>(
          'note_title',
          rawNote['title']?.toString() ?? '',
        );
        await HomeWidget.saveWidgetData<String>(
          'note_content',
          rawNote['content']?.toString() ?? '',
        );
        await HomeWidget.saveWidgetData<String>(
          'note_author',
          rawNote['author']?.toString() ?? '',
        );
        await HomeWidget.saveWidgetData<String>(
          'note_color',
          rawNote['color']?.toString() ?? '#FFE4E8',
        );
        await HomeWidget.saveWidgetData<String>(
          'note_updated_at',
          rawNote['updatedAt']?.toString() ?? '',
        );
        await HomeWidget.updateWidget(
          name: WidgetSyncService.noteWidgetName,
          androidName: WidgetSyncService.noteWidgetName,
        );
      } else if (snapshot.containsKey('pinnedNote') && rawNote == null) {
        await WidgetSyncService.clearGlanceNote();
      }

      // 3. Daily Prompt widget
      final rawPrompt = snapshot['todayPrompt'];
      if (rawPrompt is Map) {
        final promptText = rawPrompt['prompt']?.toString() ?? '';
        final isRevealed = rawPrompt['isRevealed'] == true;
        final rawAnswered = rawPrompt['answeredUids'];
        final answeredUids = rawAnswered is List
            ? rawAnswered.map((e) => e.toString()).toSet()
            : <String>{};
        final isAnsweredByMe = answeredUids.contains(myUid);
        final isAnsweredByPartner =
            answeredUids.any((u) => u.isNotEmpty && u != myUid);

        if (promptText.isNotEmpty) {
          await WidgetSyncService.syncDailyPrompt(
            prompt: promptText,
            isAnsweredByMe: isAnsweredByMe,
            isRevealed: isRevealed,
            isAnsweredByPartner: isAnsweredByPartner,
            isPortuguese: isPortuguese,
          );
        }
      }

      // 4. Tasks widget
      final rawTasks = snapshot['tasks'];
      if (rawTasks is Map) {
        await HomeWidget.saveWidgetData<String>(
          'task_1_title',
          rawTasks['task_1_title']?.toString() ?? '',
        );
        await HomeWidget.saveWidgetData<bool>(
          'task_1_done',
          rawTasks['task_1_done'] == true,
        );
        await HomeWidget.saveWidgetData<String>(
          'task_2_title',
          rawTasks['task_2_title']?.toString() ?? '',
        );
        await HomeWidget.saveWidgetData<bool>(
          'task_2_done',
          rawTasks['task_2_done'] == true,
        );
        await HomeWidget.saveWidgetData<String>(
          'task_3_title',
          rawTasks['task_3_title']?.toString() ?? '',
        );
        await HomeWidget.saveWidgetData<bool>(
          'task_3_done',
          rawTasks['task_3_done'] == true,
        );
        await HomeWidget.saveWidgetData<int>(
          'remaining_tasks_count',
          (rawTasks['remaining_tasks_count'] as num?)?.toInt() ?? 0,
        );
        await HomeWidget.updateWidget(
          name: WidgetSyncService.tasksWidgetName,
          androidName: WidgetSyncService.tasksWidgetName,
        );
      }
    } catch (e) {
      debugPrint('BackgroundSyncService.applyCompactWidgetSnapshotToGlance error: $e');
    }
  }
}
