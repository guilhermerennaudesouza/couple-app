import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/widgets/quick_edit_dialogs.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/date_ideas/data/date_ideas_repository.dart';
import 'package:couple_app/features/date_ideas/domain/date_idea_model.dart';
import 'package:couple_app/features/finance/domain/finance_model.dart';
import 'package:couple_app/features/finance/domain/savings_model.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';
import 'package:couple_app/features/tasks/data/task_repository.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

void main() {
  group('PT-BR First Default & Legacy English Translation Audit', () {
    test('DateIdeasRepository translates categories and legacy v1.0.0 English curated ideas to PT-BR', () {
      expect(
        DateIdeasRepository.translateCategory(DateIdeaModel.categoryCozy),
        'Aconchegante',
      );
      expect(
        DateIdeasRepository.translateCategory(DateIdeaModel.categoryOutdoor),
        'Ao Ar Livre',
      );
      expect(
        DateIdeasRepository.translateCategory(DateIdeaModel.categoryFoodie),
        'Gastronômico',
      );
      expect(
        DateIdeasRepository.translateCategory(DateIdeaModel.categoryRomance),
        'Romântico',
      );
      expect(
        DateIdeasRepository.translateCategory(DateIdeaModel.categoryAdventurous),
        'Aventura',
      );
      expect(
        DateIdeasRepository.translateCategory(DateIdeaModel.categoryBudget),
        'Econômico',
      );

      expect(
        DateIdeasRepository.translateIdeaTitle(
          'Candlelight Home Dinner & No Phones',
        ),
        'Jantar à Luz de Velas em Casa & Sem Celulares',
      );
      expect(
        DateIdeasRepository.translateIdeaDescription(
          'Sunset Beach Walk & Ice Cream',
          'Catch the golden hour by the water followed by your favorite scoops.',
        ),
        contains('hora de ouro'),
      );
    });

    test('TaskRepository seeds default checklist templates in PT-BR and translates legacy EN titles', () {
      final templates = TaskRepository.defaultChecklistTemplates;
      expect(templates.first.title, 'Compras da Semana');
      expect(templates.any((t) => t.title == 'Weekly Groceries'), isFalse);
      expect(
        TaskRepository.translateChecklistTitle('Weekly Groceries', isPt: true),
        'Compras da Semana',
      );
    });

    test('DailyQuestionRepository defaults getPromptForDate to PT-BR and searches legacy EN prompts in PT-BR', () {
      final prompt = DailyQuestionRepository.getPromptForDate('2026-11-19');
      expect(DailyQuestionRepository.defaultQuestionBankPt, contains(prompt));

      final legacyEnPrompt = DailyQuestionRepository.defaultQuestionBank.first;
      final ptEquivalent = DailyQuestionRepository.defaultQuestionBankPt.first;
      final keyword = ptEquivalent.split(' ').firstWhere((w) => w.length >= 5);

      final matches = DailyQuestionRepository.filterPastQuestions(
        [
          DailyQuestionModel(
            id: '2026-11-10',
            date: '2026-11-10',
            prompt: legacyEnPrompt,
            answers: {
              'u1': DailyQuestionAnswer(
                uid: 'u1',
                text: 'Sim',
                answeredAt: DateTime(2026, 11, 10),
              ),
            },
          ),
        ],
        todayKey: '2026-11-19',
        query: keyword,
      );
      expect(matches.length, 1);
    });

    test('CalendarEventModel localizes legacy EN anniversary and curated date titles to PT-BR', () {
      expect(CalendarEventModel.localizeTitle('Our Anniversary'), 'Nosso Aniversário ❤️');
      expect(CalendarEventModel.localizeTitle('Our Anniversary ❤️'), 'Nosso Aniversário ❤️');
      expect(CalendarEventModel.localizeTitle('Our Anniversary 💕'), 'Nosso Aniversário de Namoro 💕');
      expect(
        CalendarEventModel.localizeDescription('The day our love story began ❤️'),
        'O dia em que nossa história de amor começou ❤️',
      );
    });

    test('PartnerMood translates cross-locale EN preset mood labels to PT-BR', () {
      final enMood = PartnerMood(
        emoji: '🤗',
        label: 'Need hugs',
        dateKey: '2026-11-19',
        updatedAt: DateTime(2026, 11, 19),
      );
      expect(enMood.localizedLabel(isPortuguese: true), 'Carente');
      expect(enMood.localizedLabel(isPortuguese: false), 'Need hugs');
    });

    test('Quick edit category dropdown helpers translate every canonical category to PT-BR', () {
      for (final c in TaskRepository.standardCategories) {
        final label = localizeTaskCategoryLabel(c, isPt: true);
        expect(label, isNotEmpty);
        expect(label == 'Shopping' || label == 'Home' || label == 'Errands', isFalse);
      }
      for (final c in FinanceEntry.categories) {
        final label = localizeExpenseCategoryLabel(c, isPt: true);
        expect(label, isNotEmpty);
        expect(label == 'Dining' || label == 'Groceries' || label == 'Utilities', isFalse);
      }
      for (final c in SavingsGoalModel.categories) {
        final label = localizeSavingsCategoryLabel(c, isPt: true);
        expect(label, isNotEmpty);
        expect(label == 'Vacation' || label == 'Wedding' || label == 'Vehicle', isFalse);
      }
    });

    test('WidgetSyncService defaults to PT-BR when isPortuguese is omitted', () {
      final stats = WidgetSyncService.formatCoupleStats(
        anniversary: DateTime(2026, 11, 10),
        today: DateTime(2026, 11, 19),
        partnerName: 'Amor',
      );
      expect(stats['formattedDays'], '9 dias');

      final promptData = WidgetSyncService.formatDailyPrompt(
        prompt: 'Pergunta',
        isAnsweredByMe: false,
        isRevealed: false,
        isAnsweredByPartner: false,
      );
      expect(promptData['prompt_status'], 'Aguardando sua resposta ✍️');
    });
  });
}
