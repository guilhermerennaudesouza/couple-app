import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';

void main() {
  group('DailyQuestion dual-answer reveal logic', () {
    test('DailyQuestion remains hidden until both partners answer', () {
      var dq = DailyQuestionModel(
        id: 'q1',
        date: '2026-11-04',
        prompt: 'What was your favorite memory together this week?',
        answers: {
          'uid_1': DailyQuestionAnswer(
            uid: 'uid_1',
            text: 'Going to the beach',
            answeredAt: DateTime.now(),
          ),
        },
      );
      expect(dq.isRevealed, isFalse);
      expect(dq.hasUserAnswered('uid_1'), isTrue);
      expect(dq.hasUserAnswered('uid_2'), isFalse);

      dq = dq.copyWithAnswer('uid_2', 'Cooking dinner together', DateTime.now());
      expect(dq.isRevealed, isTrue);
      expect(dq.answers.length, equals(2));
      expect(dq.answers['uid_2']?.text, equals('Cooking dinner together'));
    });

    test('DailyQuestion handles serialization round-trip cleanly', () {
      final dq = DailyQuestionModel(
        id: 'q2',
        date: '2026-11-04',
        prompt: 'What is a dream trip you want to take with me?',
        answers: {
          'uid_1': DailyQuestionAnswer(
            uid: 'uid_1',
            text: 'Japan in autumn',
            answeredAt: DateTime(2026, 11, 4, 10, 0),
          ),
          'uid_2': DailyQuestionAnswer(
            uid: 'uid_2',
            text: 'Iceland road trip',
            answeredAt: DateTime(2026, 11, 4, 11, 30),
          ),
        },
        isRevealed: true,
      );
      final map = dq.toMap();
      final restored = DailyQuestionModel.fromMap('q2', map);

      expect(restored.isRevealed, isTrue);
      expect(restored.answers['uid_1']?.text, equals('Japan in autumn'));
      expect(restored.answers['uid_2']?.text, equals('Iceland road trip'));
      expect(restored.id, equals('q2'));
      expect(restored.date, equals('2026-11-04'));
      expect(
        restored.prompt,
        equals('What is a dream trip you want to take with me?'),
      );
    });

    test('DailyQuestionAnswer serialization round-trip', () {
      final answer = DailyQuestionAnswer(
        uid: 'user_a',
        text: 'Morning coffee together',
        answeredAt: DateTime(2026, 11, 4, 8, 15, 30),
      );
      final map = answer.toMap();
      final restored = DailyQuestionAnswer.fromMap(map);

      expect(restored.uid, equals('user_a'));
      expect(restored.text, equals('Morning coffee together'));
      expect(restored.answeredAt.year, equals(2026));
      expect(restored.answeredAt.month, equals(11));
      expect(restored.answeredAt.day, equals(4));
    });

    test('DailyQuestionModel helper methods work accurately', () {
      final dq = DailyQuestionModel(
        id: '2026-11-04',
        date: '2026-11-04',
        prompt: 'What is something small that made you smile today?',
        answers: {
          'user_a': DailyQuestionAnswer(
            uid: 'user_a',
            text: 'Your good morning text',
            answeredAt: DateTime(2026, 11, 4, 9, 0),
          ),
        },
      );

      expect(dq.isRevealed, isFalse);
      expect(dq.isAnsweredByBoth, isFalse);
      expect(dq.hasUserAnswered('user_a'), isTrue);
      expect(dq.hasUserAnswered('user_b'), isFalse);
      expect(dq.getAnswer('user_a')?.text, equals('Your good morning text'));
      expect(dq.getPartnerAnswer('user_a'), isNull);

      final completedDq = dq.copyWithAnswer(
        'user_b',
        'Finding our old photo album',
        DateTime(2026, 11, 4, 12, 0),
      );

      expect(completedDq.isRevealed, isTrue);
      expect(completedDq.isAnsweredByBoth, isTrue);
      expect(
        completedDq.getPartnerAnswer('user_a')?.text,
        equals('Finding our old photo album'),
      );
      expect(
        completedDq.getPartnerAnswer('user_b')?.text,
        equals('Your good morning text'),
      );
    });

    test('DailyQuestionRepository question bank and date helper verification', () {
      expect(DailyQuestionRepository.defaultQuestionBank.length, greaterThanOrEqualTo(50));
      for (final question in DailyQuestionRepository.defaultQuestionBank) {
        expect(question.trim().isNotEmpty, isTrue);
        expect(question.endsWith('?'), isTrue);
      }

      final dateStr = DailyQuestionRepository.formatDate(DateTime(2026, 11, 4));
      expect(dateStr, equals('2026-11-04'));

      final prompt1 = DailyQuestionRepository.getPromptForDate('2026-11-04');
      final prompt2 = DailyQuestionRepository.getPromptForDate('2026-11-04');
      expect(prompt1, equals(prompt2));
      expect(DailyQuestionRepository.defaultQuestionBank.contains(prompt1), isTrue);
    });

    test('DailyQuestionModel value equality and copyWith', () {
      final answer1 = DailyQuestionAnswer(
        uid: 'u1',
        text: 'Sunrise',
        answeredAt: DateTime(2026, 11, 4, 7, 0),
      );
      final answer2 = DailyQuestionAnswer(
        uid: 'u2',
        text: 'Sunset',
        answeredAt: DateTime(2026, 11, 4, 19, 0),
      );

      final dq1 = DailyQuestionModel(
        id: 'q1',
        date: '2026-11-04',
        prompt: 'Favorite time of day?',
        answers: {'u1': answer1, 'u2': answer2},
        isRevealed: true,
      );

      final dq2 = DailyQuestionModel(
        id: 'q1',
        date: '2026-11-04',
        prompt: 'Favorite time of day?',
        answers: {'u1': answer1, 'u2': answer2},
        isRevealed: true,
      );

      expect(dq1, equals(dq2));
      expect(dq1.hashCode, equals(dq2.hashCode));

      final updated = dq1.copyWith(prompt: 'Updated prompt?');
      expect(updated.prompt, equals('Updated prompt?'));
      expect(updated.id, equals('q1'));
      expect(updated.isRevealed, isTrue);
    });
  });
}
