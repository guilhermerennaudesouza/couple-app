import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/auth/domain/partner_profile.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetSyncService.formatCoupleStats', () {
    test('calculates exact milestone days for regular dates and leap years', () {
      // Leap year 2024 includes Feb 29
      final leapAnniversary = DateTime(2024, 2, 28);
      final leapTarget = DateTime(2024, 3, 1);
      final leapStats = WidgetSyncService.formatCoupleStats(
        anniversary: leapAnniversary,
        today: leapTarget,
        partnerName: 'Maya',
      );
      expect(leapStats['daysTogether'], equals(2));
      expect(leapStats['days_together'], equals(2));
      expect(leapStats['partnerName'], equals('Maya'));
      expect(leapStats['partner_name'], equals('Maya'));
      expect(leapStats['formattedDays'], equals('2 days'));

      // Standard multi-year span across leap year 2024 (2024-05-18 to 2026-11-04 is 900 days)
      final multiYearStats = WidgetSyncService.formatCoupleStats(
        anniversary: DateTime(2024, 5, 18),
        today: DateTime(2026, 11, 4),
        partnerName: 'Leo',
      );
      expect(multiYearStats['daysTogether'], equals(900));
      expect(multiYearStats['partnerName'], equals('Leo'));
      expect(multiYearStats['formattedDays'], equals('900 days'));
      expect(multiYearStats['anniversary'], equals(DateTime(2024, 5, 18).toIso8601String()));
    });

    test('calculates zero days when anniversary is today', () {
      final now = DateTime(2026, 11, 4, 15, 30);
      final stats = WidgetSyncService.formatCoupleStats(
        anniversary: DateTime(2026, 11, 4, 9, 0),
        today: now,
        partnerName: 'Elena',
      );
      expect(stats['daysTogether'], equals(0));
      expect(stats['formattedDays'], equals('0 days'));
    });
  });

  group('WidgetSyncService.formatDailyPrompt', () {
    const prompt = 'What was your favorite moment this week?';

    test('resolves status when both partners answered and isRevealed is true', () {
      final result = WidgetSyncService.formatDailyPrompt(
        prompt: prompt,
        isAnsweredByMe: true,
        isRevealed: true,
        isAnsweredByPartner: true,
      );

      expect(result['prompt'], equals(prompt));
      expect(result['status'], equals('Both answered! Tap to read 💕'));
      expect(result['prompt_status'], equals('Both answered! Tap to read 💕'));
      expect(result['isRevealed'], isTrue);
      expect(result['is_revealed'], isTrue);
      expect(result['isAnsweredByMe'], isTrue);
      expect(result['isAnsweredByPartner'], isTrue);
    });

    test('resolves status when answered by me but waiting for partner', () {
      final result = WidgetSyncService.formatDailyPrompt(
        prompt: prompt,
        isAnsweredByMe: true,
        isRevealed: false,
        isAnsweredByPartner: false,
      );

      expect(result['prompt'], equals(prompt));
      expect(result['status'], equals('Waiting for partner... 🔒'));
      expect(result['prompt_status'], equals('Waiting for partner... 🔒'));
      expect(result['isRevealed'], isFalse);
      expect(result['is_revealed'], isFalse);
      expect(result['isAnsweredByMe'], isTrue);
    });

    test('resolves status when user has not answered yet', () {
      final result = WidgetSyncService.formatDailyPrompt(
        prompt: prompt,
        isAnsweredByMe: false,
        isRevealed: false,
        isAnsweredByPartner: true,
      );

      expect(result['prompt'], equals(prompt));
      expect(result['status'], equals('Waiting for your answer ✍️'));
      expect(result['prompt_status'], equals('Waiting for your answer ✍️'));
      expect(result['isRevealed'], isFalse);
      expect(result['isAnsweredByMe'], isFalse);
    });
  });

  group('WidgetSyncService.formatTopTasks', () {
    test('extracts top 3 incomplete tasks sorted by urgency and counts remaining', () {
      final tasks = [
        TaskModel(
          id: 't1',
          title: 'Buy groceries',
          isCompleted: false,
          dueDate: DateTime(2026, 11, 6),
        ),
        TaskModel(
          id: 't2',
          title: 'Urgent vet visit',
          isCompleted: false,
          dueDate: DateTime(2026, 11, 4), // Most urgent incomplete
        ),
        TaskModel(
          id: 't3',
          title: 'Already finished dishes',
          isCompleted: true,
        ),
        TaskModel(
          id: 't4',
          title: 'Book anniversary dinner',
          isCompleted: false,
          dueDate: DateTime(2026, 11, 10),
        ),
        TaskModel(
          id: 't5',
          title: 'Plan weekend trip',
          isCompleted: false,
        ),
      ];

      final result = WidgetSyncService.formatTopTasks(tasks: tasks);

      // Top 3 should be incomplete, with earlier due date first
      expect(result['task_1_title'], equals('Urgent vet visit'));
      expect(result['task_1_done'], isFalse);
      expect(result['task_2_title'], equals('Buy groceries'));
      expect(result['task_2_done'], isFalse);
      expect(result['task_3_title'], equals('Book anniversary dinner'));
      expect(result['task_3_done'], isFalse);

      // Total incomplete = 4 ('Urgent vet visit', 'Buy groceries', 'Book anniversary dinner', 'Plan weekend trip')
      // Top 3 contains 3 incomplete -> remaining = 1
      expect(result['remaining_tasks_count'], equals(1));
      expect(result['remainingCount'], equals(1));
      expect(result['totalIncomplete'], equals(4));
    });

    test('handles fewer than 3 tasks and includes completed ones if needed', () {
      final tasks = [
        const TaskModel(
          id: 't1',
          title: 'Water plants',
          isCompleted: false,
        ),
        const TaskModel(
          id: 't2',
          title: 'Take out trash',
          isCompleted: true,
        ),
      ];

      final result = WidgetSyncService.formatTopTasks(tasks: tasks);

      expect(result['task_1_title'], equals('Water plants'));
      expect(result['task_1_done'], isFalse);
      expect(result['task_2_title'], equals('Take out trash'));
      expect(result['task_2_done'], isTrue);
      expect(result['task_3_title'], equals(''));
      expect(result['task_3_done'], isFalse);
      expect(result['remaining_tasks_count'], equals(0));
    });

    test('handles empty task list gracefully', () {
      final result = WidgetSyncService.formatTopTasks(tasks: []);

      expect(result['task_1_title'], equals(''));
      expect(result['task_1_done'], isFalse);
      expect(result['task_2_title'], equals(''));
      expect(result['task_2_done'], isFalse);
      expect(result['task_3_title'], equals(''));
      expect(result['task_3_done'], isFalse);
      expect(result['remaining_tasks_count'], equals(0));
      expect(result['totalIncomplete'], equals(0));
    });
  });

  group('WidgetSyncService platform sync methods', () {
    test('syncCoupleStats executes gracefully in test harness', () async {
      await expectLater(
        WidgetSyncService.syncCoupleStats(
          anniversary: DateTime(2024, 1, 1),
          partnerName: 'Sweetheart',
        ),
        completes,
      );
    });

    test('syncDailyPrompt executes gracefully in test harness', () async {
      await expectLater(
        WidgetSyncService.syncDailyPrompt(
          prompt: 'Where should our next date be?',
          isAnsweredByMe: true,
          isRevealed: false,
          isAnsweredByPartner: false,
        ),
        completes,
      );
    });

    test('syncTopTasks executes gracefully in test harness', () async {
      final tasks = [
        const TaskModel(id: '1', title: 'Task 1', isCompleted: false),
      ];
      await expectLater(
        WidgetSyncService.syncTopTasks(tasks: tasks),
        completes,
      );
    });

    test('syncAllWidgets executes gracefully with full and partial models', () async {
      final couple = CoupleModel(
        id: 'c1',
        members: ['u1', 'u2'],
        anniversaryDate: DateTime(2024, 6, 1),
        inviteCode: 'LOVE24',
        partnerProfiles: {
          'u1': const PartnerProfile(uid: 'u1', displayName: 'Me'),
          'u2': const PartnerProfile(uid: 'u2', displayName: 'Sweetheart'),
        },
      );

      final note = NoteModel(
        id: 'n1',
        title: 'Morning Note',
        content: 'Love you lots!',
        authorUid: 'u1',
        authorName: 'Me',
      );

      final question = DailyQuestionModel(
        id: 'q1',
        date: '2026-11-04',
        prompt: 'Favorite memory together?',
        answers: {
          'u1': DailyQuestionAnswer(
            uid: 'u1',
            text: 'Our beach trip',
            answeredAt: DateTime.now(),
          ),
          'u2': DailyQuestionAnswer(
            uid: 'u2',
            text: 'Cooking pizza',
            answeredAt: DateTime.now(),
          ),
        },
        isRevealed: true,
      );

      final tasks = [
        const TaskModel(id: 't1', title: 'Feed cat', isCompleted: true),
        const TaskModel(id: 't2', title: 'Make dinner', isCompleted: false),
      ];

      // Test with all models present
      await expectLater(
        WidgetSyncService.syncAllWidgets(
          couple: couple,
          pinnedNote: note,
          todayQuestion: question,
          tasks: tasks,
          myUid: 'u1',
        ),
        completes,
      );

      // Test with nullable defaults (e.g. no pinned note, no today question)
      await expectLater(
        WidgetSyncService.syncAllWidgets(
          couple: null,
          pinnedNote: null,
          todayQuestion: null,
          tasks: [],
        ),
        completes,
      );
    });
  });
}
