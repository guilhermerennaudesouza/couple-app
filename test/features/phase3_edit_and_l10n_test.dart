import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/utils/currency_parser.dart';
import 'package:couple_app/features/finance/domain/finance_model.dart';
import 'package:couple_app/features/finance/domain/savings_model.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';
import 'package:couple_app/features/memories/domain/memory_model.dart';
import 'package:couple_app/features/stats/presentation/couple_stats_screen.dart';
import 'package:couple_app/features/tasks/domain/checklist_model.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';
import 'package:couple_app/features/wishlist/domain/wish_model.dart';

void main() {
  group('Phase 3 Edit preservation & BRL currency parsing', () {
    test('editing models via copyWith preserves id, completion, settlement, and usage counters', () {
      final task = TaskModel(
        id: 't1',
        title: 'Old',
        isCompleted: true,
        createdBy: 'u1',
      );
      final editedTask = task.copyWith(title: 'New', category: 'Romance');
      expect(editedTask.id, 't1');
      expect(editedTask.isCompleted, isTrue);
      expect(editedTask.createdBy, 'u1');

      final list = ChecklistModel(
        id: 'l1',
        title: 'Old list',
        category: 'Home',
        items: const [ChecklistItem(id: 'i1', text: 'Milk', isDone: true)],
      );
      final editedList = list.copyWith(title: 'New list', category: 'Shopping');
      expect(editedList.id, 'l1');
      expect(editedList.items.length, 1);

      final expense = FinanceEntry(
        id: 'f1',
        title: 'Jantar',
        amount: 120.0,
        paidBy: 'u1',
        isSettled: true,
      );
      final editedExpense = expense.copyWith(
        title: 'Jantar Especial',
        amount: parseBrlCurrency('1.250,90') ?? expense.amount,
      );
      expect(editedExpense.id, 'f1');
      expect(editedExpense.amount, closeTo(1250.90, 0.001));
      expect(editedExpense.isSettled, isTrue);

      final goal = SavingsGoalModel(
        id: 'g1',
        title: 'Viagem',
        targetAmount: 5000,
        currentAmount: 1200,
        createdBy: 'u1',
      );
      final editedGoal = goal.copyWith(
        title: 'Viagem Itália',
        targetAmount: parseBrlCurrency('8.500,00') ?? goal.targetAmount,
      );
      expect(editedGoal.id, 'g1');
      expect(editedGoal.currentAmount, 1200);
      expect(editedGoal.targetAmount, 8500);

      final memory = MemoryModel(
        id: 'm1',
        title: 'Praia',
        caption: 'Sol e mar',
        date: DateTime(2026, 1, 10),
        createdBy: 'u1',
      );
      final editedMemory = memory.copyWith(title: 'Praia do Rosa');
      expect(editedMemory.id, 'm1');
      expect(editedMemory.createdBy, 'u1');

      final wish = WishModel(
        id: 'w1',
        title: 'Perfume',
        estimatedPrice: 300,
        isPurchased: true,
        createdBy: 'u1',
      );
      final editedWish = wish.copyWith(title: 'Perfume Importado');
      expect(editedWish.id, 'w1');
      expect(editedWish.isPurchased, isTrue);

      final coupon = LoyaltyCouponModel(
        id: 'c1',
        title: 'Massagem',
        description: '20 min',
        usedCount: 2,
        maxUses: 5,
        createdBy: 'u1',
        createdAt: DateTime(2026, 1, 1),
      );
      final editedCoupon = coupon.copyWith(title: 'Massagem Relaxante', maxUses: 6);
      expect(editedCoupon.id, 'c1');
      expect(editedCoupon.usedCount, 2);
      expect(editedCoupon.maxUses, 6);
    });
  });

  group('Phase 3 v1.0.4 PT-BR / EN localization', () {
    test('CoupleStatsSummary.rankTitle supports both Portuguese and English', () {
      const summary = CoupleStatsSummary(
        daysTogether: 400,
        questionsAnswered: 20,
        tasksCompleted: 10,
        datesCompleted: 5,
        memoriesCount: 5,
        capsulesCount: 1,
        wishesFulfilled: 2,
        notesCount: 5,
        couponsRedeemed: 3,
        totalSavedInPiggyBank: 1000,
      );

      expect(summary.rankTitle(isPortuguese: true), isNotEmpty);
      expect(summary.rankTitle(isPortuguese: false), isNotEmpty);
      expect(
        summary.rankTitle(isPortuguese: true),
        isNot(equals(summary.rankTitle(isPortuguese: false))),
      );
    });
  });
}
