import 'package:couple_app/core/utils/couple_date_utils.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';

/// Computes consecutive daily revealed-question streaks for a couple.
class CoupleStreakUtils {
  /// Returns the number of consecutive calendar days with `isRevealed == true`
  /// ending either today or yesterday (so the streak does not reset before
  /// midnight while partners still have time to answer today).
  static int calculateDailyStreak(
    Iterable<DailyQuestionModel> questions, {
    DateTime? now,
  }) {
    final revealedKeys = <String>{};
    for (final q in questions) {
      if (q.isRevealed && q.date.trim().length >= 10) {
        revealedKeys.add(q.date.trim().substring(0, 10));
      }
    }
    if (revealedKeys.isEmpty) return 0;

    final refNow = now ?? DateTime.now();
    final today = DateTime(refNow.year, refNow.month, refNow.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime cursor;
    if (revealedKeys.contains(CoupleDateUtils.formatDateKey(today))) {
      cursor = today;
    } else if (revealedKeys.contains(CoupleDateUtils.formatDateKey(yesterday))) {
      cursor = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (revealedKeys.contains(CoupleDateUtils.formatDateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
