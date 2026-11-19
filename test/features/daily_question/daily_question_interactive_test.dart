import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';

void main() {
  group('DailyQuestionModel reactions, comments & custom questions', () {
    test('legacy map without reactions/comments/isCustom deserializes with safe defaults', () {
      final legacy = DailyQuestionModel.fromMap('2026-11-18', {
        'date': '2026-11-18',
        'prompt': 'Qual a sua música favorita?',
        'isRevealed': true,
      });
      expect(legacy.reactions, isEmpty);
      expect(legacy.comments, isEmpty);
      expect(legacy.isCustom, isFalse);
      expect(legacy.proposedByUid, isNull);
    });

    test('serializes and restores reactions, comments, and custom proposal metadata', () {
      final comment = DailyQuestionComment(
        id: 'c1',
        uid: 'u1',
        authorName: 'Gui',
        text: 'Amei sua resposta! ❤️',
        createdAt: DateTime(2026, 11, 19, 20, 30),
      );
      final model = DailyQuestionModel(
        id: '2026-11-20',
        date: '2026-11-20',
        prompt: 'Onde você quer viajar nas nossas próximas férias?',
        reactions: const {'u1': '❤️', 'u2': '😍'},
        comments: [comment],
        isCustom: true,
        proposedByUid: 'u1',
      );

      final restored = DailyQuestionModel.fromMap('2026-11-20', model.toMap());
      expect(restored.reactions, {'u1': '❤️', 'u2': '😍'});
      expect(restored.comments.length, 1);
      expect(restored.comments.first.text, 'Amei sua resposta! ❤️');
      expect(restored.isCustom, isTrue);
      expect(restored.proposedByUid, 'u1');
    });
  });

  group('Custom future question scheduling & concealed archive filtering', () {
    test('findNextAvailableFutureDateKey picks tomorrow or first unoccupied future date', () {
      final today = DateTime(2026, 11, 19, 14, 0);
      expect(
        DailyQuestionRepository.findNextAvailableFutureDateKey(
          const {},
          now: today,
        ),
        '2026-11-20',
      );
      expect(
        DailyQuestionRepository.findNextAvailableFutureDateKey(
          const {'2026-11-20', '2026-11-21'},
          now: today,
        ),
        '2026-11-22',
      );
    });

    test('filterPastQuestions strictly hides future custom questions and today, and supports text search', () {
      const todayKey = '2026-11-19';
      final items = [
        DailyQuestionModel(
          id: '2026-11-20',
          date: '2026-11-20',
          prompt: 'PERGUNTA_SURPRESA_FUTURA',
          isCustom: true,
          proposedByUid: 'u1',
        ),
        DailyQuestionModel(
          id: '2026-11-19',
          date: '2026-11-19',
          prompt: 'Pergunta de hoje',
          answers: {
            'u1': DailyQuestionAnswer(
              uid: 'u1',
              text: 'Hoje',
              answeredAt: DateTime(2026, 11, 19),
            ),
          },
        ),
        DailyQuestionModel(
          id: '2026-11-18',
          date: '2026-11-18',
          prompt: 'Qual viagem você sonha fazer?',
          answers: {
            'u1': DailyQuestionAnswer(
              uid: 'u1',
              text: 'Japão na primavera',
              answeredAt: DateTime(2026, 11, 18),
            ),
          },
        ),
        DailyQuestionModel(
          id: '2026-11-17',
          date: '2026-11-17',
          prompt: 'Qual nossa comida favorita?',
          answers: {
            'u1': DailyQuestionAnswer(
              uid: 'u1',
              text: 'Lasanha de domingo',
              answeredAt: DateTime(2026, 11, 17),
            ),
          },
        ),
      ];

      final allPast = DailyQuestionRepository.filterPastQuestions(
        items,
        todayKey: todayKey,
      );
      expect(allPast.length, 2);
      expect(allPast.any((q) => q.date == '2026-11-20'), isFalse);
      expect(allPast.any((q) => q.date == '2026-11-19'), isFalse);

      final searchJapan = DailyQuestionRepository.filterPastQuestions(
        items,
        todayKey: todayKey,
        query: 'japão',
        myUid: 'u1',
      );
      expect(searchJapan.length, 1);
      expect(searchJapan.first.id, '2026-11-18');

      // Partner 'u2' has not answered 2026-11-18 yet, so searching 'japão' must not leak u1's answer
      final partnerSearchJapan = DailyQuestionRepository.filterPastQuestions(
        items,
        todayKey: todayKey,
        query: 'japão',
        myUid: 'u2',
      );
      expect(partnerSearchJapan, isEmpty);
    });
  });
}
