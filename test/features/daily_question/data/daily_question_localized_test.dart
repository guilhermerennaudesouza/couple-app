import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';
import 'package:couple_app/features/date_ideas/data/date_ideas_repository.dart';

void main() {
  group('DailyQuestionRepository Localization Tests', () {
    test('Question bank has equal number of EN and PT prompts', () {
      expect(DailyQuestionRepository.defaultQuestionBank.length,
          DailyQuestionRepository.defaultQuestionBankPt.length);
      expect(DailyQuestionRepository.defaultQuestionBank.length, 50);
    });

    test('getPromptForDate returns Portuguese prompt by default or when pt specified', () {
      final promptPt = DailyQuestionRepository.getPromptForDate('2026-11-05', languageCode: 'pt');
      final promptEn = DailyQuestionRepository.getPromptForDate('2026-11-05', languageCode: 'en');

      expect(promptPt, isNotEmpty);
      expect(promptEn, isNotEmpty);
      expect(promptPt, isNot(equals(promptEn)));
    });

    test('translatePrompt translates between English and Portuguese seamlessly', () {
      final enFirst = DailyQuestionRepository.defaultQuestionBank[0];
      final ptFirst = DailyQuestionRepository.defaultQuestionBankPt[0];

      expect(DailyQuestionRepository.translatePrompt(enFirst, languageCode: 'pt'), ptFirst);
      expect(DailyQuestionRepository.translatePrompt(ptFirst, languageCode: 'en'), enFirst);
    });
  });

  group('DateIdeasRepository Localization Tests', () {
    test('defaultCuratedIdeas returns Portuguese ideas when requested', () {
      final ideasPt = DateIdeasRepository.defaultCuratedIdeas(createdBy: 'uid1', languageCode: 'pt');
      expect(ideasPt.first.title, contains('Luz de Velas'));
      expect(ideasPt.first.description, contains('telas'));

      final ideasEn = DateIdeasRepository.defaultCuratedIdeas(createdBy: 'uid1', languageCode: 'en');
      expect(ideasEn.first.title, contains('Candlelight'));
    });

    test('translateIdeaTitle and translateIdeaDescription localize curated ideas', () {
      expect(
        DateIdeasRepository.translateIdeaTitle('Candlelight Home Dinner & No Phones', languageCode: 'pt'),
        contains('Luz de Velas'),
      );
    });
  });
}
