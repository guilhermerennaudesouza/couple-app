import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import '../../core/l10n/locale_provider.dart';
import '../auth/data/pairing_repository.dart';
import '../auth/domain/couple_model.dart';
import '../daily_question/data/daily_question_repository.dart';
import '../daily_question/domain/daily_question_model.dart';
import '../notes/data/note_repository.dart';
import '../notes/domain/note_model.dart';
import '../tasks/data/task_repository.dart';
import '../tasks/domain/task_model.dart';

/// Riverpod listener provider that automatically keeps Android home widgets synchronized
/// with Firestore state (couple milestones, today's prompt, top tasks, pinned note).
final widgetSyncProvider = Provider.family<void, String>((ref, coupleId) {
  if (coupleId.isEmpty) return;

  final coupleAsync = ref.watch(coupleStreamProvider(coupleId));
  final todayAsync = ref.watch(todayDailyQuestionProvider(coupleId));
  final tasksAsync = ref.watch(tasksStreamProvider(coupleId));
  final notesAsync = ref.watch(notesStreamProvider(coupleId));
  final locale = ref.watch(localeProvider);

  final couple = coupleAsync.valueOrNull;
  final todayQuestion = todayAsync.valueOrNull;
  final tasks = tasksAsync.valueOrNull ?? const [];
  final notes = notesAsync.valueOrNull ?? const [];
  final pinnedNote = notes.where((n) => n.isPinnedToWidget).firstOrNull;
  final myUid = FirebaseAuth.instance.currentUser?.uid;

  WidgetSyncService.syncAllWidgets(
    couple: couple,
    pinnedNote: pinnedNote,
    todayQuestion: todayQuestion,
    tasks: tasks,
    myUid: myUid,
    isPortuguese: locale.languageCode == 'pt',
  );
});

/// Service orchestrating bidirectional synchronization between Krivo's
/// internal data models and Android Home Screen Widgets via Kotlin Jetpack Glance.
class WidgetSyncService {
  static const String androidWidgetName = 'NoteGlanceWidget';
  static const String noteWidgetName = 'NoteGlanceWidget';
  static const String coupleWidgetName = 'CoupleGlanceWidget';
  static const String dailyPromptWidgetName = 'DailyPromptGlanceWidget';
  static const String tasksWidgetName = 'TasksGlanceWidget';
  static const String appGroupId = 'group.com.personal.couple_app';

  /// Initializes widget configuration and app group settings if applicable.
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('WidgetSyncService: Error setting app group id: $e');
    }
  }

  /// Updates the home screen Glance sticky note widget with the latest pinned note.
  static Future<void> updateGlanceNote(NoteModel note) async {
    try {
      await HomeWidget.saveWidgetData<String>('note_id', note.id);
      await HomeWidget.saveWidgetData<String>('note_title', note.title);
      await HomeWidget.saveWidgetData<String>('note_content', note.content);
      await HomeWidget.saveWidgetData<String>('note_author', note.authorName);
      await HomeWidget.saveWidgetData<String>('note_color', note.colorHex);
      await HomeWidget.saveWidgetData<String>(
        'note_updated_at',
        note.updatedAt.toIso8601String(),
      );

      await HomeWidget.updateWidget(
        name: noteWidgetName,
        androidName: noteWidgetName,
      );
    } catch (e) {
      // Gracefully log on unsupported platforms or unit test harnesses
      debugPrint('WidgetSyncService.updateGlanceNote error: $e');
    }
  }

  /// Clears active pinned sticky note data from home widget storage.
  static Future<void> clearGlanceNote() async {
    try {
      await HomeWidget.saveWidgetData<String>('note_id', '');
      await HomeWidget.saveWidgetData<String>('note_title', '');
      await HomeWidget.saveWidgetData<String>('note_content', '');
      await HomeWidget.saveWidgetData<String>('note_author', '');
      await HomeWidget.saveWidgetData<String>('note_color', '');

      await HomeWidget.updateWidget(
        name: noteWidgetName,
        androidName: noteWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetSyncService.clearGlanceNote error: $e');
    }
  }

  /// Formats couple milestone metrics into structured widget payload data.
  static Map<String, dynamic> formatCoupleStats({
    required DateTime anniversary,
    DateTime? today,
    required String partnerName,
    bool isPortuguese = false,
  }) {
    final current = today ?? DateTime.now();
    // Normalize to UTC date boundaries (midnight) to prevent timezone and DST drift
    final d1 = DateTime.utc(anniversary.year, anniversary.month, anniversary.day);
    final d2 = DateTime.utc(current.year, current.month, current.day);
    final daysTogether = d2.difference(d1).inDays;
    final formattedDays = isPortuguese ? '$daysTogether dias' : '$daysTogether days';

    return {
      'daysTogether': daysTogether,
      'partnerName': partnerName,
      'formattedDays': formattedDays,
      'anniversary': anniversary.toIso8601String(),
      'days_together': daysTogether,
      'partner_name': partnerName,
      'formatted_days': formattedDays,
    };
  }

  /// Pushes couple anniversary and milestone counter data to widget storage.
  static Future<void> syncCoupleStats({
    required DateTime anniversary,
    required String partnerName,
    DateTime? today,
    bool isPortuguese = false,
  }) async {
    try {
      final stats = formatCoupleStats(
        anniversary: anniversary,
        today: today,
        partnerName: partnerName,
        isPortuguese: isPortuguese,
      );

      await HomeWidget.saveWidgetData<int>(
        'days_together',
        stats['daysTogether'] as int,
      );
      await HomeWidget.saveWidgetData<String>('partner_name', partnerName);
      await HomeWidget.saveWidgetData<String>(
        'formatted_days',
        stats['formattedDays'] as String,
      );
      await HomeWidget.saveWidgetData<String>(
        'anniversary',
        stats['anniversary'] as String,
      );

      await HomeWidget.updateWidget(
        name: coupleWidgetName,
        androidName: coupleWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetSyncService.syncCoupleStats error: $e');
    }
  }

  /// Formats daily question prompt and status for widget display.
  static Map<String, dynamic> formatDailyPrompt({
    required String prompt,
    required bool isAnsweredByMe,
    required bool isRevealed,
    required bool isAnsweredByPartner,
    bool isPortuguese = false,
  }) {
    final String status;
    if (isPortuguese) {
      if (isRevealed) {
        status = 'Ambos responderam! 💕';
      } else if (isAnsweredByMe) {
        status = 'Aguardando seu amor... 🔒';
      } else {
        status = 'Aguardando sua resposta ✍️';
      }
    } else {
      if (isRevealed) {
        status = 'Both answered! Tap to read 💕';
      } else if (isAnsweredByMe) {
        status = 'Waiting for partner... 🔒';
      } else {
        status = 'Waiting for your answer ✍️';
      }
    }

    return {
      'prompt': prompt,
      'status': status,
      'isAnsweredByMe': isAnsweredByMe,
      'isRevealed': isRevealed,
      'isAnsweredByPartner': isAnsweredByPartner,
      'prompt_text': prompt,
      'prompt_status': status,
      'is_revealed': isRevealed,
      'is_answered_by_me': isAnsweredByMe,
      'is_answered_by_partner': isAnsweredByPartner,
    };
  }

  /// Pushes daily question prompt and status to widget storage.
  static Future<void> syncDailyPrompt({
    required String prompt,
    required bool isAnsweredByMe,
    required bool isRevealed,
    required bool isAnsweredByPartner,
    bool isPortuguese = false,
  }) async {
    try {
      final data = formatDailyPrompt(
        prompt: prompt,
        isAnsweredByMe: isAnsweredByMe,
        isRevealed: isRevealed,
        isAnsweredByPartner: isAnsweredByPartner,
        isPortuguese: isPortuguese,
      );

      await HomeWidget.saveWidgetData<String>(
        'prompt_text',
        data['prompt_text'] as String,
      );
      await HomeWidget.saveWidgetData<String>(
        'prompt_status',
        data['prompt_status'] as String,
      );
      await HomeWidget.saveWidgetData<bool>(
        'is_revealed',
        data['is_revealed'] as bool,
      );
      await HomeWidget.saveWidgetData<bool>(
        'is_answered_by_me',
        data['is_answered_by_me'] as bool,
      );
      await HomeWidget.saveWidgetData<bool>(
        'is_answered_by_partner',
        data['is_answered_by_partner'] as bool,
      );

      await HomeWidget.updateWidget(
        name: dailyPromptWidgetName,
        androidName: dailyPromptWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetSyncService.syncDailyPrompt error: $e');
    }
  }

  /// Formats top tasks and remaining count for widget display.
  static Map<String, dynamic> formatTopTasks({
    required List<TaskModel> tasks,
  }) {
    // Sort tasks: incomplete first, then by earliest dueDate (urgent), then general
    final sorted = List<TaskModel>.from(tasks)
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        if (a.dueDate != null && b.dueDate != null) {
          return a.dueDate!.compareTo(b.dueDate!);
        }
        if (a.dueDate != null) return -1;
        if (b.dueDate != null) return 1;
        return a.title.compareTo(b.title);
      });

    final topTasks = sorted.take(3).toList();
    final totalIncomplete = tasks.where((t) => !t.isCompleted).length;
    final incompleteInTop = topTasks.where((t) => !t.isCompleted).length;
    final remainingCount = (totalIncomplete - incompleteInTop).clamp(0, 99999);

    final task1Title = topTasks.isNotEmpty ? topTasks[0].title : '';
    final task1Done = topTasks.isNotEmpty ? topTasks[0].isCompleted : false;
    final task2Title = topTasks.length > 1 ? topTasks[1].title : '';
    final task2Done = topTasks.length > 1 ? topTasks[1].isCompleted : false;
    final task3Title = topTasks.length > 2 ? topTasks[2].title : '';
    final task3Done = topTasks.length > 2 ? topTasks[2].isCompleted : false;

    return {
      'topTasks': topTasks,
      'task_1_title': task1Title,
      'task_1_done': task1Done,
      'task_2_title': task2Title,
      'task_2_done': task2Done,
      'task_3_title': task3Title,
      'task_3_done': task3Done,
      'task1Title': task1Title,
      'task1Done': task1Done,
      'task2Title': task2Title,
      'task2Done': task2Done,
      'task3Title': task3Title,
      'task3Done': task3Done,
      'remaining_tasks_count': remainingCount,
      'remainingTasksCount': remainingCount,
      'remainingCount': remainingCount,
      'totalIncomplete': totalIncomplete,
      'totalTasks': tasks.length,
    };
  }

  /// Pushes top 3 tasks and remaining count to widget storage.
  static Future<void> syncTopTasks({
    required List<TaskModel> tasks,
  }) async {
    try {
      final data = formatTopTasks(tasks: tasks);

      await HomeWidget.saveWidgetData<String>(
        'task_1_title',
        data['task_1_title'] as String,
      );
      await HomeWidget.saveWidgetData<bool>(
        'task_1_done',
        data['task_1_done'] as bool,
      );
      await HomeWidget.saveWidgetData<String>(
        'task_2_title',
        data['task_2_title'] as String,
      );
      await HomeWidget.saveWidgetData<bool>(
        'task_2_done',
        data['task_2_done'] as bool,
      );
      await HomeWidget.saveWidgetData<String>(
        'task_3_title',
        data['task_3_title'] as String,
      );
      await HomeWidget.saveWidgetData<bool>(
        'task_3_done',
        data['task_3_done'] as bool,
      );
      await HomeWidget.saveWidgetData<int>(
        'remaining_tasks_count',
        data['remaining_tasks_count'] as int,
      );

      await HomeWidget.updateWidget(
        name: tasksWidgetName,
        androidName: tasksWidgetName,
      );
    } catch (e) {
      debugPrint('WidgetSyncService.syncTopTasks error: $e');
    }
  }

  /// Synchronizes all couple widgets simultaneously.
  static Future<void> syncAllWidgets({
    required CoupleModel? couple,
    required NoteModel? pinnedNote,
    required DailyQuestionModel? todayQuestion,
    required List<TaskModel> tasks,
    String? myUid,
    bool isPortuguese = true,
  }) async {
    if (couple != null) {
      String partnerName = isPortuguese ? 'Seu Amor' : 'Partner';
      if (myUid != null) {
        final name = couple.getPartnerProfile(myUid)?.displayName;
        partnerName = (name != null && name.trim().isNotEmpty) ? name.trim() : partnerName;
      } else if (couple.partnerProfiles.isNotEmpty) {
        final name = couple.partnerProfiles.values.first.displayName;
        partnerName = name.trim().isNotEmpty ? name.trim() : partnerName;
      }
      await syncCoupleStats(
        anniversary: couple.anniversaryDate,
        partnerName: partnerName,
        isPortuguese: isPortuguese,
      );
    }

    if (pinnedNote != null) {
      await updateGlanceNote(pinnedNote);
    } else {
      await clearGlanceNote();
    }

    if (todayQuestion != null) {
      final bool isAnsweredByMe = myUid != null
          ? todayQuestion.hasUserAnswered(myUid)
          : todayQuestion.answers.isNotEmpty;
      final bool isAnsweredByPartner = myUid != null
          ? todayQuestion.getPartnerAnswer(myUid) != null
          : todayQuestion.answers.length >= 2;

      await syncDailyPrompt(
        prompt: todayQuestion.prompt,
        isAnsweredByMe: isAnsweredByMe,
        isRevealed: todayQuestion.isRevealed,
        isAnsweredByPartner: isAnsweredByPartner,
        isPortuguese: isPortuguese,
      );
    }

    await HomeWidget.saveWidgetData<String>('language', isPortuguese ? 'pt' : 'en');
    await syncTopTasks(tasks: tasks);
  }
}
