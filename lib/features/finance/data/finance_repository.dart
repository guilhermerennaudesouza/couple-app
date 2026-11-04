import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/finance_model.dart';
import '../domain/savings_model.dart';

/// Repository managing shared expenses, split calculations, and joint savings goals
/// for a couple, persisted under Cloud Firestore with offline durability.
///
/// Collections:
/// `/couples/{coupleId}/finance_entries/{entryId}`
/// `/couples/{coupleId}/savings_goals/{goalId}`
class FinanceRepository {
  final FirebaseFirestore _firestore;

  FinanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _entriesCollection(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('finance_entries');
  }

  CollectionReference<Map<String, dynamic>> _savingsCollection(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('savings_goals');
  }

  // ==========================================
  // SHARED EXPENSES API
  // ==========================================

  /// Watches all shared expenses for a couple in real time.
  ///
  /// Sorted chronologically by [date] descending (most recent first).
  Stream<List<FinanceEntry>> watchEntries(String coupleId) {
    return _entriesCollection(coupleId).snapshots().map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => FinanceEntry.fromMap(doc.id, doc.data()))
          .toList();

      entries.sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        if (cmp != 0) return cmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return entries;
    });
  }

  /// Adds or updates a shared expense.
  ///
  /// Uses [SetOptions(merge: true)] for full offline durability.
  Future<void> addExpense(String coupleId, FinanceEntry entry) async {
    final col = _entriesCollection(coupleId);
    final docRef = entry.id.isEmpty ? col.doc() : col.doc(entry.id);
    final toSave = entry.id.isEmpty ? entry.copyWith(id: docRef.id) : entry;
    await docRef.set(toSave.toMap(), SetOptions(merge: true));
  }

  /// Settles all currently unsettled expenses between the couple.
  ///
  /// Marks each unsettled expense with `isSettled: true` and `settledAt: DateTime.now()`.
  Future<void> settleAllBalances(
    String coupleId, {
    required String settledByUid,
  }) async {
    final col = _entriesCollection(coupleId);
    final nowIso = DateTime.now().toIso8601String();

    QuerySnapshot<Map<String, dynamic>>? snapshot;
    try {
      snapshot = await col.where('isSettled', isEqualTo: false).get();
    } catch (e) {
      debugPrint('FinanceRepository.settleAllBalances server get fallback to cache: $e');
      try {
        snapshot = await col
            .where('isSettled', isEqualTo: false)
            .get(const GetOptions(source: Source.cache));
      } catch (cacheErr) {
        debugPrint('FinanceRepository.settleAllBalances cache get failed: $cacheErr');
      }
    }

    if (snapshot == null || snapshot.docs.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.set(doc.reference, {
          'isSettled': true,
          'settledAt': nowIso,
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('FinanceRepository.settleAllBalances batch fallback: $e');
      for (final doc in snapshot.docs) {
        try {
          await doc.reference.set({
            'isSettled': true,
            'settledAt': nowIso,
          }, SetOptions(merge: true));
        } catch (docErr) {
          debugPrint('FinanceRepository.settleAllBalances per-doc update error: $docErr');
        }
      }
    }
  }

  /// Deletes an expense by its ID.
  Future<void> deleteExpense(String coupleId, String entryId) async {
    await _entriesCollection(coupleId).doc(entryId).delete();
  }

  // ==========================================
  // JOINT SAVINGS GOALS API
  // ==========================================

  /// Watches all joint savings goals in real time.
  ///
  /// Sorted with active (incomplete) goals first, then completed goals last,
  /// and secondarily by [createdAt] descending.
  Stream<List<SavingsGoalModel>> watchSavingsGoals(String coupleId) {
    return _savingsCollection(coupleId).snapshots().map((snapshot) {
      final goals = snapshot.docs
          .map((doc) => SavingsGoalModel.fromMap(doc.id, doc.data()))
          .toList();

      goals.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return goals;
    });
  }

  /// Creates a new savings goal with offline persistence.
  Future<void> createSavingsGoal(
    String coupleId,
    SavingsGoalModel goal,
  ) async {
    final col = _savingsCollection(coupleId);
    final docRef = goal.id.isEmpty ? col.doc() : col.doc(goal.id);
    final toSave = goal.id.isEmpty ? goal.copyWith(id: docRef.id) : goal;
    await docRef.set(toSave.toMap(), SetOptions(merge: true));
  }

  /// Records a contribution toward an existing savings goal.
  ///
  /// Increments [SavingsGoalModel.currentAmount], appends the contribution to the history,
  /// and automatically flags [SavingsGoalModel.isCompleted] if the target is reached.
  Future<void> addContribution(
    String coupleId,
    String goalId,
    SavingsContribution contribution,
  ) async {
    final docRef = _savingsCollection(coupleId).doc(goalId);
    final contribToSave = contribution.id.isEmpty
        ? contribution.copyWith(
            id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          )
        : contribution;

    try {
      final doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final goal = SavingsGoalModel.fromMap(doc.id, doc.data()!);
        final updatedAmount = ((goal.currentAmount + contribToSave.amount) * 100)
                .roundToDouble() /
            100.0;
        final updatedContribs = [...goal.contributions, contribToSave];
        final isCompleted =
            goal.targetAmount > 0 && updatedAmount >= goal.targetAmount;

        final updatedGoal = goal.copyWith(
          currentAmount: updatedAmount,
          contributions: updatedContribs,
          isCompleted: isCompleted,
        );

        await docRef.set(updatedGoal.toMap(), SetOptions(merge: true));
        return;
      }
    } catch (e) {
      debugPrint('FinanceRepository.addContribution direct read fallback: $e');
    }

    // Direct atomic write fallback for offline mode
    await docRef.set({
      'currentAmount': FieldValue.increment(contribToSave.amount),
      'contributions': FieldValue.arrayUnion([contribToSave.toMap()]),
    }, SetOptions(merge: true));
  }

  /// Deletes a savings goal by its ID.
  Future<void> deleteSavingsGoal(String coupleId, String goalId) async {
    await _savingsCollection(coupleId).doc(goalId).delete();
  }
}

// ==========================================
// RIVERPOD PROVIDERS
// ==========================================

/// Riverpod provider for [FinanceRepository].
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository();
});

/// Stream provider for all shared finance entries belonging to a couple.
final financeEntriesStreamProvider =
    StreamProvider.family<List<FinanceEntry>, String>((ref, coupleId) {
  final repository = ref.watch(financeRepositoryProvider);
  return repository.watchEntries(coupleId);
});

/// Stream provider for all joint savings goals belonging to a couple.
final savingsGoalsStreamProvider =
    StreamProvider.family<List<SavingsGoalModel>, String>((ref, coupleId) {
  final repository = ref.watch(financeRepositoryProvider);
  return repository.watchSavingsGoals(coupleId);
});

/// Record type parameter for [financeBalanceProvider].
typedef CoupleUserPair = ({
  String coupleId,
  String user1,
  String user2,
});

/// Computed balance summary provider reflecting current unsettled expenses.
final financeBalanceProvider =
    Provider.family<BalanceSummary, CoupleUserPair>((ref, pair) {
  final entriesAsync = ref.watch(financeEntriesStreamProvider(pair.coupleId));
  final entries = entriesAsync.value ?? const [];
  return calculateNetOwed(entries, user1: pair.user1, user2: pair.user2);
});
