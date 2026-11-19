import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/utils/couple_streak_utils.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/stats/presentation/couple_stats_screen.dart';

DailyQuestionModel _q(String date, {required bool revealed}) {
  return DailyQuestionModel(
    id: date,
    date: date,
    prompt: 'Prompt $date',
    isRevealed: revealed,
    answers: revealed
        ? {
            'u1': DailyQuestionAnswer(uid: 'u1', text: 'A', answeredAt: DateTime(2026, 11, 19)),
            'u2': DailyQuestionAnswer(uid: 'u2', text: 'B', answeredAt: DateTime(2026, 11, 19)),
          }
        : const {},
  );
}

void main() {
  group('CoupleStreakUtils.calculateDailyStreak', () {
    final today = DateTime(2026, 11, 19, 15, 0);

    test('returns 0 for empty list', () {
      expect(CoupleStreakUtils.calculateDailyStreak(const [], now: today), 0);
    });

    test('counts consecutive revealed days ending today', () {
      final questions = [
        _q('2026-11-19', revealed: true),
        _q('2026-11-18', revealed: true),
        _q('2026-11-17', revealed: true),
        _q('2026-11-15', revealed: true), // gap on 16th
      ];
      expect(CoupleStreakUtils.calculateDailyStreak(questions, now: today), 3);
    });

    test('counts consecutive revealed days ending yesterday when today is not revealed yet', () {
      final questions = [
        _q('2026-11-19', revealed: false),
        _q('2026-11-18', revealed: true),
        _q('2026-11-17', revealed: true),
      ];
      expect(CoupleStreakUtils.calculateDailyStreak(questions, now: today), 2);
    });

    test('returns 0 when last revealed question was 2+ days ago', () {
      final questions = [
        _q('2026-11-17', revealed: true),
        _q('2026-11-16', revealed: true),
      ];
      expect(CoupleStreakUtils.calculateDailyStreak(questions, now: today), 0);
    });

    test('deduplicates duplicate date entries and ignores unrevealed', () {
      final questions = [
        _q('2026-11-18', revealed: true),
        _q('2026-11-19', revealed: true),
        _q('2026-11-19', revealed: true),
        _q('2026-11-17', revealed: false),
      ];
      expect(CoupleStreakUtils.calculateDailyStreak(questions, now: today), 2);
    });
  });

  group('CoupleStatsSummary streak and pulses', () {
    test('supports dailyStreak and totalPulsesCount with backward-compatible defaults', () {
      const summary = CoupleStatsSummary(
        daysTogether: 100,
        questionsAnswered: 10,
        tasksCompleted: 5,
        datesCompleted: 2,
        memoriesCount: 3,
        capsulesCount: 1,
        wishesFulfilled: 1,
        notesCount: 4,
        couponsRedeemed: 2,
        totalSavedInPiggyBank: 500,
        dailyStreak: 7,
        totalPulsesCount: 15,
      );

      expect(summary.dailyStreak, 7);
      expect(summary.totalPulsesCount, 15);
      expect(summary.totalXp, greaterThan(0));
    });
  });
}
