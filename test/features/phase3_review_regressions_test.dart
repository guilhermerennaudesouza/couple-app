import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/widgets/quick_edit_dialogs.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/date_ideas/data/date_ideas_repository.dart';
import 'package:couple_app/features/date_ideas/domain/date_idea_model.dart';
import 'package:couple_app/features/drawing/domain/shared_canvas_model.dart';
import 'package:couple_app/features/finance/domain/savings_model.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';
import 'package:couple_app/features/memories/domain/memory_model.dart';
import 'package:couple_app/features/wishlist/domain/wish_model.dart';

void main() {
  group('Phase 3 Review Regressions (Critical & Important)', () {
    test('Critical #3: edit builders properly clear optional fields and maintain isCompleted & maxUses invariants', () {
      // Memory clearLocation
      final mem = MemoryModel(
        id: 'm1',
        title: 'Praia',
        caption: 'Sol',
        location: 'Floripa',
        date: DateTime(2026, 1, 1),
        createdBy: 'u1',
      );
      final updatedMem = buildEditedMemory(
        mem,
        title: 'Praia 2',
        caption: 'Mar',
        locationInput: '   ',
        date: mem.date,
      );
      expect(updatedMem.location, isNull);

      // Wish clear description, price, url
      final wish = WishModel(
        id: 'w1',
        title: 'Perfume',
        description: 'Cheiroso',
        estimatedPrice: 250.0,
        url: 'https://example.com',
        createdBy: 'u1',
      );
      final updatedWish = buildEditedWish(
        wish,
        title: 'Perfume Novo',
        descriptionInput: '',
        priceInput: '',
        urlInput: '',
      );
      expect(updatedWish, isNotNull);
      expect(updatedWish!.description, isNull);
      expect(updatedWish.estimatedPrice, isNull);
      expect(updatedWish.url, isNull);

      // Invalid non-empty price rejected (returns null)
      final invalidPriceWish = buildEditedWish(
        wish,
        title: 'Perfume',
        descriptionInput: 'Desc',
        priceInput: 'abc',
        urlInput: '',
      );
      expect(invalidPriceWish, isNull);

      // Savings goal recomputes isCompleted when target rises above currentAmount
      final completedGoal = SavingsGoalModel(
        id: 'g1',
        title: 'Viagem',
        targetAmount: 1000,
        currentAmount: 1000,
        isCompleted: true,
        createdBy: 'u1',
      );
      final raisedGoal = buildEditedSavingsGoal(
        completedGoal,
        title: 'Viagem Europa',
        targetAmount: 5000,
        category: 'Vacation',
      );
      expect(raisedGoal.isCompleted, isFalse);

      // Coupon maxUses lower bound respects usedCount
      final coupon = LoyaltyCouponModel(
        id: 'c1',
        title: 'Massagem',
        description: 'Boa',
        maxUses: 5,
        usedCount: 3,
        createdBy: 'u1',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(minAllowedCouponMaxUses(coupon), 3);
      expect(maxAllowedCouponMaxUses(coupon), 20);
      final highCoupon = coupon.copyWith(maxUses: 30);
      expect(maxAllowedCouponMaxUses(highCoupon), 30);
    });

    test('Critical #4: passed catalog cards are excluded from personal List view and Random Picker', () {
      final ideas = [
        DateIdeaModel(
          id: 'cat_pt_01',
          title: 'Rejeitada do catálogo',
          createdBy: 'catalog',
          votes: const {'u1': DateIdeaModel.votePass},
        ),
        DateIdeaModel(
          id: 'cat_pt_02',
          title: 'Curtida do catálogo',
          createdBy: 'catalog',
          votes: const {'u1': DateIdeaModel.voteLike},
        ),
        DateIdeaModel(
          id: 'personal_1',
          title: 'Ideia nossa',
          createdBy: 'u1',
        ),
      ];

      final listVisible = DateIdeasRepository.filterIdeasForPersonalList(ideas);
      expect(listVisible.any((i) => i.id == 'cat_pt_01'), isFalse);
      expect(listVisible.any((i) => i.id == 'cat_pt_02'), isTrue);
      expect(listVisible.any((i) => i.id == 'personal_1'), isTrue);

      final onlyRejectedCatalog = [ideas.first];
      expect(
        DateIdeasRepository.pickRandomIdea(
          onlyRejectedCatalog,
          random: Random(1),
        ),
        isNull,
      );
    });

    test('Important #1: trimStrokesToBudget caps even a single giant continuous stroke under 200 KB', () {
      final hugePoints = List.generate(
        9000,
        (i) => CanvasPoint((i % 1000) / 1000.0, (i / 9000.0)),
      );
      final singleGiantStroke = [
        CanvasStroke(
          id: 'giant_1',
          authorUid: 'u1',
          colorHex: '#E91E63',
          strokeWidth: 4.0,
          points: hugePoints,
        ),
      ];

      final trimmed = SharedCanvasModel.trimStrokesToBudget(
        singleGiantStroke,
        maxBytes: SharedCanvasModel.maxStrokesPayloadBytes,
      );
      final encodedBytes = utf8
          .encode(jsonEncode(trimmed.map((s) => s.toMap()).toList()))
          .length;
      expect(encodedBytes, lessThanOrEqualTo(SharedCanvasModel.maxStrokesPayloadBytes));
      expect(trimmed.length, 1);
      expect(trimmed.first.points.length, lessThan(hugePoints.length));
    });

    test('Important #2: filterPastQuestions search does NOT leak partner secret answer on unrevealed questions', () {
      final unrevealed = DailyQuestionModel(
        id: '2026-11-18',
        date: '2026-11-18',
        prompt: 'Qual nossa música favorita?',
        isRevealed: false,
        answers: {
          'u2': DailyQuestionAnswer(
            uid: 'u2',
            text: 'SEGREDO_OCULTO_DO_PARCEIRO',
            answeredAt: DateTime(2026, 11, 18),
          ),
        },
      );

      final leakAttempt = DailyQuestionRepository.filterPastQuestions(
        [unrevealed],
        todayKey: '2026-11-19',
        query: 'segredo_oculto',
        myUid: 'u1',
      );
      expect(leakAttempt, isEmpty);

      // Prompt search still works on unrevealed questions
      final promptSearch = DailyQuestionRepository.filterPastQuestions(
        [unrevealed],
        todayKey: '2026-11-19',
        query: 'música',
        myUid: 'u1',
      );
      expect(promptSearch.length, 1);
    });
  });
}
