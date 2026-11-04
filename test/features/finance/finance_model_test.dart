import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/finance/domain/finance_model.dart';
import 'package:couple_app/features/finance/domain/savings_model.dart';

void main() {
  const user1 = 'uid_alex';
  const user2 = 'uid_sam';

  group('FinanceEntry & BalanceSummary tests', () {
    test('50/50 split calculates equal shares for both partners', () {
      final entry = FinanceEntry(
        id: 'entry_1',
        title: 'Supermarket Groceries',
        amount: 100.0,
        category: 'Groceries',
        paidBy: user1,
        splitRatio: SplitRatio.half,
        date: DateTime(2026, 11, 4),
      );

      expect(entry.shareFor(user1, partnerUid: user2), equals(50.0));
      expect(entry.shareFor(user2, partnerUid: user1), equals(50.0));

      final balance = calculateNetOwed([entry], user1: user1, user2: user2);
      expect(balance.totalSpent, equals(100.0));
      expect(balance.user1Paid, equals(100.0));
      expect(balance.user2Paid, equals(0.0));
      expect(balance.netOwedToUser1, equals(50.0));
      expect(balance.netOwedToUser2, equals(0.0));
      expect(balance.unsettledCount, equals(1));
    });

    test('Uneven / custom percentage split calculation (70/30)', () {
      // Alex pays $200 for a fancy anniversary dinner, Alex covers 70%, Sam covers 30%
      final entry = FinanceEntry(
        id: 'entry_custom',
        title: 'Anniversary Dinner',
        amount: 200.0,
        category: 'Dining',
        paidBy: user1,
        splitRatio: SplitRatio.custom,
        customSplitPercentage: 70.0,
        date: DateTime(2026, 11, 4),
      );

      expect(entry.shareFor(user1, partnerUid: user2), equals(140.0)); // 70% of 200
      expect(entry.shareFor(user2, partnerUid: user1), equals(60.0));  // 30% of 200

      final balance = calculateNetOwed([entry], user1: user1, user2: user2);
      expect(balance.totalSpent, equals(200.0));
      expect(balance.user1Paid, equals(200.0));
      expect(balance.user2Paid, equals(0.0));
      expect(balance.netOwedToUser1, equals(60.0));
      expect(balance.netOwedToUser2, equals(0.0));
    });

    test('paidByOther split (100% partner responsibility)', () {
      // Alex pays $80 for Sam's personal concert ticket
      final entry = FinanceEntry(
        id: 'entry_pbo',
        title: 'Concert Ticket for Sam',
        amount: 80.0,
        category: 'Entertainment',
        paidBy: user1,
        splitRatio: SplitRatio.paidByOther,
        date: DateTime(2026, 11, 4),
      );

      expect(entry.shareFor(user1, partnerUid: user2), equals(0.0));
      expect(entry.shareFor(user2, partnerUid: user1), equals(80.0));

      final balance = calculateNetOwed([entry], user1: user1, user2: user2);
      expect(balance.totalSpent, equals(80.0));
      expect(balance.user1Paid, equals(80.0));
      expect(balance.user2Paid, equals(0.0));
      expect(balance.netOwedToUser1, equals(80.0));
      expect(balance.netOwedToUser2, equals(0.0));
    });

    test('Asymmetric payments where both partners pay different amounts', () {
      // Alex pays $120 for Groceries (50/50 -> Sam owes $60)
      // Sam pays $40 for Movie tickets (50/50 -> Alex owes $20)
      // Net: Sam owes Alex $60 - $20 = $40
      final entries = [
        FinanceEntry(
          id: 'e1',
          title: 'Groceries',
          amount: 120.0,
          category: 'Groceries',
          paidBy: user1,
          splitRatio: SplitRatio.half,
          date: DateTime(2026, 11, 1),
        ),
        FinanceEntry(
          id: 'e2',
          title: 'Movies',
          amount: 40.0,
          category: 'Entertainment',
          paidBy: user2,
          splitRatio: SplitRatio.half,
          date: DateTime(2026, 11, 2),
        ),
      ];

      final balance = calculateNetOwed(entries, user1: user1, user2: user2);
      expect(balance.totalSpent, equals(160.0));
      expect(balance.user1Paid, equals(120.0));
      expect(balance.user2Paid, equals(40.0));
      expect(balance.netOwedToUser1, equals(40.0));
      expect(balance.netOwedToUser2, equals(0.0));
      expect(balance.unsettledCount, equals(2));

      // Inverse perspective: user1 is Sam, user2 is Alex
      final inverseBalance = calculateNetOwed(entries, user1: user2, user2: user1);
      expect(inverseBalance.netOwedToUser1, equals(0.0));
      expect(inverseBalance.netOwedToUser2, equals(40.0));
    });

    test('Settled entries are completely excluded from net balance calculations', () {
      final entries = [
        FinanceEntry(
          id: 'e1',
          title: 'Last Month Electricity',
          amount: 150.0,
          category: 'Utilities',
          paidBy: user1,
          splitRatio: SplitRatio.half,
          date: DateTime(2026, 10, 15),
          isSettled: true,
          settledAt: DateTime(2026, 10, 31),
        ),
        FinanceEntry(
          id: 'e2',
          title: 'This Week Groceries',
          amount: 50.0,
          category: 'Groceries',
          paidBy: user2,
          splitRatio: SplitRatio.half,
          date: DateTime(2026, 11, 3),
          isSettled: false,
        ),
      ];

      final balance = calculateNetOwed(entries, user1: user1, user2: user2);
      expect(balance.totalSpent, equals(50.0));
      expect(balance.user1Paid, equals(0.0));
      expect(balance.user2Paid, equals(50.0));
      expect(balance.netOwedToUser1, equals(0.0));
      expect(balance.netOwedToUser2, equals(25.0)); // Alex owes Sam $25
      expect(balance.unsettledCount, equals(1));
    });

    test('All settled up returns zero balances', () {
      final entries = [
        FinanceEntry(
          id: 'e1',
          title: 'Old Dinner',
          amount: 100.0,
          category: 'Dining',
          paidBy: user1,
          splitRatio: SplitRatio.half,
          date: DateTime(2026, 10, 1),
          isSettled: true,
          settledAt: DateTime(2026, 10, 5),
        ),
      ];

      final balance = calculateNetOwed(entries, user1: user1, user2: user2);
      expect(balance.totalSpent, equals(0.0));
      expect(balance.netOwedToUser1, equals(0.0));
      expect(balance.netOwedToUser2, equals(0.0));
      expect(balance.unsettledCount, equals(0));
    });

    test('FinanceEntry serialization round-trip maintains all fields', () {
      final date = DateTime(2026, 11, 4, 14, 30);
      final entry = FinanceEntry(
        id: 'f_test_123',
        title: 'Weekend Getaway Airbnb',
        amount: 345.50,
        category: 'Travel',
        paidBy: user1,
        splitRatio: SplitRatio.custom,
        customSplitPercentage: 60.0,
        date: date,
        isSettled: false,
        settledAt: null,
        createdAt: date,
      );

      final map = entry.toMap();
      expect(map['id'], equals('f_test_123'));
      expect(map['title'], equals('Weekend Getaway Airbnb'));
      expect(map['amount'], equals(345.50));
      expect(map['category'], equals('Travel'));
      expect(map['paidBy'], equals(user1));
      expect(map['splitRatio'], equals('custom'));
      expect(map['customSplitPercentage'], equals(60.0));
      expect(map['isSettled'], equals(false));

      final restored = FinanceEntry.fromMap('f_test_123', map);
      expect(restored.id, equals(entry.id));
      expect(restored.title, equals(entry.title));
      expect(restored.amount, equals(entry.amount));
      expect(restored.category, equals(entry.category));
      expect(restored.paidBy, equals(entry.paidBy));
      expect(restored.splitRatio, equals(SplitRatio.custom));
      expect(restored.customSplitPercentage, equals(60.0));
      expect(restored.isSettled, isFalse);
      expect(restored.date.isAtSameMomentAs(date), isTrue);
      expect(restored.createdAt.isAtSameMomentAs(date), isTrue);
    });

    test('FinanceEntry copyWith and equality', () {
      final entry = FinanceEntry(
        id: 'f1',
        title: 'Coffee',
        amount: 12.0,
        category: 'Dining',
        paidBy: user1,
        splitRatio: SplitRatio.half,
        date: DateTime(2026, 11, 4),
      );

      final updated = entry.copyWith(
        isSettled: true,
        settledAt: DateTime(2026, 11, 5),
      );

      expect(updated.isSettled, isTrue);
      expect(updated.title, equals('Coffee'));
      expect(entry == updated, isFalse);
      expect(entry == entry.copyWith(), isTrue);
    });
  });

  group('SavingsGoalModel & SavingsContribution tests', () {
    test('Savings goal progress ratio and percentage calculation', () {
      final goal = SavingsGoalModel(
        id: 'goal_1',
        title: 'Trip to Tokyo 🌸',
        targetAmount: 3000.0,
        currentAmount: 1500.0,
        category: 'Vacation',
        createdBy: user1,
        createdAt: DateTime(2026, 11, 1),
      );

      expect(goal.progressRatio, equals(0.5));
      expect(goal.progressPercentage, equals(50));
      expect(goal.remainingAmount, equals(1500.0));
      expect(goal.isTargetReached, isFalse);
    });

    test('Savings goal clamps progress at 1.0 when overfunded', () {
      final goal = SavingsGoalModel(
        id: 'goal_2',
        title: 'New Sofa 🛋️',
        targetAmount: 800.0,
        currentAmount: 950.0,
        category: 'Home',
        createdBy: user2,
        createdAt: DateTime(2026, 11, 1),
      );

      expect(goal.progressRatio, equals(1.0));
      expect(goal.progressPercentage, equals(100));
      expect(goal.remainingAmount, equals(0.0));
      expect(goal.isTargetReached, isTrue);
    });

    test('Contributions tracking and total calculations', () {
      final c1 = SavingsContribution(
        id: 'c1',
        uid: user1,
        amount: 250.0,
        date: DateTime(2026, 11, 1),
        note: 'Paycheck bonus! 🎉',
      );
      final c2 = SavingsContribution(
        id: 'c2',
        uid: user2,
        amount: 150.0,
        date: DateTime(2026, 11, 2),
        note: 'Sold old monitor',
      );

      final goal = SavingsGoalModel(
        id: 'goal_contributions',
        title: 'Emergency Fund',
        targetAmount: 1000.0,
        currentAmount: 400.0,
        category: 'Emergency',
        contributions: [c1, c2],
        createdBy: user1,
        createdAt: DateTime(2026, 11, 1),
      );

      expect(goal.contributions.length, equals(2));
      expect(goal.contributions[0].amount, equals(250.0));
      expect(goal.contributions[1].amount, equals(150.0));
      expect(goal.progressPercentage, equals(40));
    });

    test('SavingsGoalModel serialization round-trip maintains all fields and contributions', () {
      final targetDate = DateTime(2027, 6, 15);
      final createdAt = DateTime(2026, 11, 4, 12, 0);

      final contribution = SavingsContribution(
        id: 'c_sub_1',
        uid: user1,
        amount: 500.0,
        date: createdAt,
        note: 'First joint deposit! 💰',
      );

      final goal = SavingsGoalModel(
        id: 'goal_paris',
        title: 'Paris Honeymoon 🗼',
        targetAmount: 5000.0,
        currentAmount: 500.0,
        targetDate: targetDate,
        category: 'Vacation',
        isCompleted: false,
        contributions: [contribution],
        createdBy: user1,
        createdAt: createdAt,
      );

      final map = goal.toMap();
      expect(map['id'], equals('goal_paris'));
      expect(map['title'], equals('Paris Honeymoon 🗼'));
      expect(map['targetAmount'], equals(5000.0));
      expect(map['currentAmount'], equals(500.0));
      expect(map['category'], equals('Vacation'));
      expect(map['isCompleted'], equals(false));
      expect(map['contributions'], isList);

      final restored = SavingsGoalModel.fromMap('goal_paris', map);
      expect(restored.id, equals(goal.id));
      expect(restored.title, equals(goal.title));
      expect(restored.targetAmount, equals(goal.targetAmount));
      expect(restored.currentAmount, equals(goal.currentAmount));
      expect(restored.category, equals(goal.category));
      expect(restored.targetDate?.isAtSameMomentAs(targetDate), isTrue);
      expect(restored.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(restored.contributions.length, equals(1));
      expect(restored.contributions.first.id, equals('c_sub_1'));
      expect(restored.contributions.first.note, equals('First joint deposit! 💰'));
      expect(restored.contributions.first.amount, equals(500.0));
    });

    test('SavingsContribution copyWith and equality', () {
      final c1 = SavingsContribution(
        id: 'c_eq_1',
        uid: user1,
        amount: 100.0,
        date: DateTime(2026, 11, 4),
        note: 'Test note',
      );
      final c2 = c1.copyWith(note: 'Updated note');

      expect(c2.note, equals('Updated note'));
      expect(c1 == c2, isFalse);
      expect(c1 == c1.copyWith(), isTrue);
    });

    test('SavingsGoalModel.fromMap recognizes target reached when isCompleted is false in map', () {
      final rawMap = {
        'id': 'g_completed',
        'title': 'Emergency Fund',
        'targetAmount': 2000.0,
        'currentAmount': 2100.0,
        'isCompleted': false, // simulate Firestore document with un-updated isCompleted flag
        'category': 'Emergency',
        'createdBy': user1,
      };

      final restored = SavingsGoalModel.fromMap('g_completed', rawMap);
      expect(restored.isTargetReached, isTrue);
      expect(restored.isCompleted, isTrue);
      expect(restored.progressRatio, equals(1.0));
      expect(restored.progressPercentage, equals(100));
    });

    test('FinanceEntry.shareFor returns 0.0 when foreign uid is passed', () {
      final entry = FinanceEntry(
        id: 'fe_unknown',
        title: 'Lunch',
        amount: 50.0,
        paidBy: user1,
        splitRatio: SplitRatio.half,
      );
      expect(entry.shareFor('foreign_uid', partnerUid: user2), equals(0.0));
    });
  });
}
