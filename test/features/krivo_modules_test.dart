import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';
import 'package:couple_app/features/loyalty/data/loyalty_repository.dart';
import 'package:couple_app/features/adult_games/domain/adult_game_model.dart';
import 'package:couple_app/features/adult_games/data/adult_games_repository.dart';
import 'package:couple_app/features/cycle/domain/cycle_model.dart';
import 'package:couple_app/features/stats/presentation/couple_stats_screen.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';
import 'package:couple_app/features/notes/presentation/scratch_and_doodle_widgets.dart';
import 'package:couple_app/features/wishlist/domain/wish_model.dart';

void main() {
  group('Krivo Modules & pt-BR Localization Verification', () {
    test('1. LoyaltyCouponModel & defaultLoveCoupons in pt-BR', () {
      final defaults = LoyaltyRepository.defaultLoveCoupons(DateTime(2026, 1, 1));
      expect(defaults.length, greaterThanOrEqualTo(8));

      final coupon = LoyaltyCouponModel(
        id: 'c1',
        title: 'Vale Massagem Relaxante 💆‍♀️',
        description: '20 minutos de massagem sem reclamar!',
        emoji: '💆‍♀️',
        category: 'coupon',
        maxUses: 2,
        usedCount: 0,
        createdBy: 'uid_a',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(coupon.isLoyaltyCard, isFalse);
      expect(coupon.canRedeem, isTrue);
      expect(coupon.remainingUses, 2);

      final map = coupon.toMap();
      final restored = LoyaltyCouponModel.fromMap('c1', map);
      expect(restored.title, 'Vale Massagem Relaxante 💆‍♀️');
      expect(restored.remainingUses, 2);

      final exhausted = restored.copyWith(usedCount: 2);
      expect(exhausted.isExhausted, isTrue);
      expect(exhausted.canRedeem, isFalse);
    });

    test('2. AdultGameCardModel & 24 curated pt-BR cards across 3 levels', () {
      final cards = AdultGamesRepository.curatedDeck;
      expect(cards.length, 24);

      final gentleCount =
          cards.where((c) => c.level == AdultGameCardModel.levelGentle).length;
      final boldCount =
          cards.where((c) => c.level == AdultGameCardModel.levelBold).length;
      final spicyCount =
          cards.where((c) => c.level == AdultGameCardModel.levelSpicy).length;

      expect(gentleCount, 8);
      expect(boldCount, 8);
      expect(spicyCount, 8);

      const card = AdultGameCardModel(
        id: 'ag_1',
        title: 'Beijo no Pescoço',
        prompt: 'Beije o pescoço do seu amor lentamente por 30 segundos.',
        level: AdultGameCardModel.levelBold,
        cardType: AdultGameCardModel.typeDare,
        isCompleted: false,
        createdBy: 'system',
      );

      expect(card.cardTypeLabelPt, 'Desafio a Dois 🔥');
      expect(card.levelLabelPt, 'Ousado 🔥');

      final restored = AdultGameCardModel.fromMap('ag_1', card.toMap());
      expect(restored.prompt, card.prompt);
      expect(restored.level, AdultGameCardModel.levelBold);
    });

    test('3. CycleDataModel phases, countdown & partner care tips in pt-BR', () {
      final now = DateTime.now();
      // Day 2 of cycle -> Menstrual
      final menstrualCycle = CycleDataModel(
        lastPeriodStart: now.subtract(const Duration(days: 1)),
        cycleLength: 28,
        periodDuration: 5,
        currentSymptoms: const ['Cólica leve 🩸', 'Sensível 🥺'],
        activeCareRequest: 'Chocolate 🍫',
        careRequestedByName: 'Amor',
        updatedAt: now,
      );

      expect(menstrualCycle.currentCycleDay(today: now), 2);
      expect(menstrualCycle.currentPhase(today: now), CycleDataModel.phaseMenstrual);
      expect(menstrualCycle.phaseTitlePt(today: now), contains('Menstrual'));
      expect(menstrualCycle.phasePartnerTipPt(today: now), isNotEmpty);

      // Day 14 of cycle -> Ovulation
      final ovulationCycle = menstrualCycle.copyWith(
        lastPeriodStart: now.subtract(const Duration(days: 13)),
      );
      expect(ovulationCycle.currentPhase(today: now), CycleDataModel.phaseOvulation);

      // Day 24 of cycle -> Luteal
      final lutealCycle = menstrualCycle.copyWith(
        lastPeriodStart: now.subtract(const Duration(days: 23)),
      );
      expect(lutealCycle.currentPhase(today: now), CycleDataModel.phaseLuteal);
      expect(lutealCycle.daysUntilNextPeriod(today: now), greaterThan(0));
    });

    test('4. CoupleStatsSummary XP & Level calculation in pt-BR', () {
      const summary = CoupleStatsSummary(
        daysTogether: 100,
        questionsAnswered: 10,
        tasksCompleted: 8,
        datesCompleted: 4,
        memoriesCount: 5,
        capsulesCount: 2,
        wishesFulfilled: 2,
        notesCount: 6,
        couponsRedeemed: 3,
        totalSavedInPiggyBank: 1500.0,
      );

      expect(summary.totalXp, greaterThan(500));
      expect(summary.level, greaterThanOrEqualTo(3));
      expect(summary.rankTitlePt, isNotEmpty);
      expect(summary.currentLevelProgress, inInclusiveRange(0.0, 1.0));
    });

    test('5. NoteModel Scratch Card & Freehand Doodle serialization', () {
      const strokes = [
        DoodleStroke(
          points: [Offset(10, 20), Offset(30, 40)],
          colorValue: 0xFFE91E63,
          strokeWidth: 4.0,
        ),
      ];
      final encoded = DoodleStroke.encodeStrokes(strokes);
      final decoded = DoodleStroke.decodeStrokes(encoded);
      expect(decoded.length, 1);
      expect(decoded.first.points.length, 2);
      expect(decoded.first.colorValue, 0xFFE91E63);

      final note = NoteModel(
        id: 'n1',
        title: 'Surpresa!',
        content: 'Jantar romântico hoje às 20h 🍷',
        colorHex: '#FFCDD2',
        isPinnedToWidget: true,
        isScratchCard: true,
        isScratched: false,
        drawingDataJson: encoded,
        authorUid: 'uid_a',
        authorName: 'Amor',
        updatedAt: DateTime(2026, 2, 1),
      );

      expect(note.hasDrawing, isTrue);
      expect(note.isScratchCard, isTrue);
      expect(note.isScratched, isFalse);
      expect(NoteModel.colorNamesPt['#FFCDD2'], 'Rosa Blush');

      final restored = NoteModel.fromMap('n1', note.toMap());
      expect(restored.isScratchCard, isTrue);
      expect(restored.isScratched, isFalse);
      expect(restored.hasDrawing, isTrue);
    });

    test('6. WishModel Secret Gift Radar serialization', () {
      final secretWish = WishModel(
        id: 'w1',
        title: 'Relógio Minimalista',
        category: 'Gifts',
        estimatedPrice: 450.0,
        description: 'Cor prata, pulseira de couro',
        isSecretRadar: true,
        occasion: 'Aniversário de Namoro 💝',
        createdBy: 'uid_a',
        createdAt: DateTime(2026, 3, 1),
      );

      expect(secretWish.isSecretRadar, isTrue);
      expect(secretWish.occasion, 'Aniversário de Namoro 💝');

      final restored = WishModel.fromMap('w1', secretWish.toMap());
      expect(restored.isSecretRadar, isTrue);
      expect(restored.occasion, 'Aniversário de Namoro 💝');
    });
  });
}
