import 'package:flutter/foundation.dart';

/// Defines how an expense is split between two partners.
enum SplitRatio {
  /// Split evenly 50/50 between both partners.
  half,

  /// Non-paying partner is responsible for 100% of the expense (e.g. paying for their personal item).
  paidByOther,

  /// Custom percentage split based on [FinanceEntry.customSplitPercentage].
  custom;

  static SplitRatio fromString(String? value) {
    if (value == null) return SplitRatio.half;
    for (final ratio in SplitRatio.values) {
      if (ratio.name == value) return ratio;
    }
    return SplitRatio.half;
  }
}

/// Represents an individual shared expense logged by one partner.
@immutable
class FinanceEntry {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String paidBy;
  final SplitRatio splitRatio;
  final double? customSplitPercentage; // Percentage of total paid by paidBy (0.0 to 100.0)
  final DateTime date;
  final bool isSettled;
  final DateTime? settledAt;
  final DateTime createdAt;

  /// Standard expense categories tailored for couples.
  static const List<String> categories = [
    'Dining',
    'Groceries',
    'Travel',
    'Home',
    'Entertainment',
    'Utilities',
    'Other',
  ];

  FinanceEntry({
    required this.id,
    required this.title,
    required this.amount,
    this.category = 'Other',
    required this.paidBy,
    this.splitRatio = SplitRatio.half,
    this.customSplitPercentage,
    DateTime? date,
    this.isSettled = false,
    this.settledAt,
    DateTime? createdAt,
  })  : date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Calculates the exact monetary share this specific [uid] is responsible for.
  ///
  /// - For [SplitRatio.half]: each partner is responsible for 50%.
  /// - For [SplitRatio.paidByOther]: payer is responsible for 0%, partner is responsible for 100%.
  /// - For [SplitRatio.custom]: payer is responsible for [customSplitPercentage]%,
  ///   and partner is responsible for (100 - [customSplitPercentage])%.
  double shareFor(String uid, {required String partnerUid}) {
    final payerPercent = switch (splitRatio) {
      SplitRatio.half => 50.0,
      SplitRatio.paidByOther => 0.0,
      SplitRatio.custom => (customSplitPercentage ?? 50.0).clamp(0.0, 100.0),
    };

    final percentage = uid == paidBy ? payerPercent : (100.0 - payerPercent);
    final calculated = amount * (percentage / 100.0);
    return (calculated * 100).roundToDouble() / 100.0;
  }

  /// Converts this expense into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'paidBy': paidBy,
      'splitRatio': splitRatio.name,
      'customSplitPercentage': customSplitPercentage,
      'date': date.toIso8601String(),
      'isSettled': isSettled,
      'settledAt': settledAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a [FinanceEntry] from Firestore data with resilient parsing.
  factory FinanceEntry.fromMap(String id, Map<String, dynamic> map) {
    return FinanceEntry(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      amount: _parseAmount(map['amount']),
      category: map['category'] as String? ?? 'Other',
      paidBy: map['paidBy'] as String? ?? '',
      splitRatio: SplitRatio.fromString(map['splitRatio'] as String?),
      customSplitPercentage: _parseDoubleNullable(map['customSplitPercentage']),
      date: _parseDateTime(map['date']),
      isSettled: map['isSettled'] as bool? ?? false,
      settledAt: map['settledAt'] != null ? _parseDateTime(map['settledAt']) : null,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Creates a copy of this expense with modified fields.
  FinanceEntry copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? paidBy,
    SplitRatio? splitRatio,
    double? customSplitPercentage,
    DateTime? date,
    bool? isSettled,
    DateTime? settledAt,
    DateTime? createdAt,
  }) {
    return FinanceEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      splitRatio: splitRatio ?? this.splitRatio,
      customSplitPercentage:
          customSplitPercentage ?? this.customSplitPercentage,
      date: date ?? this.date,
      isSettled: isSettled ?? this.isSettled,
      settledAt: settledAt ?? this.settledAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return (value as dynamic).toDate();
    } catch (_) {}
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinanceEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          amount == other.amount &&
          category == other.category &&
          paidBy == other.paidBy &&
          splitRatio == other.splitRatio &&
          customSplitPercentage == other.customSplitPercentage &&
          date == other.date &&
          isSettled == other.isSettled &&
          settledAt == other.settledAt &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      amount.hashCode ^
      category.hashCode ^
      paidBy.hashCode ^
      splitRatio.hashCode ^
      customSplitPercentage.hashCode ^
      date.hashCode ^
      isSettled.hashCode ^
      settledAt.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'FinanceEntry(id: $id, title: $title, amount: $amount, category: $category, paidBy: $paidBy, splitRatio: $splitRatio, isSettled: $isSettled)';
  }
}

/// Summary of current unsettled financial balance between two partners.
@immutable
class BalanceSummary {
  final double totalSpent;
  final double user1Paid;
  final double user2Paid;
  final double netOwedToUser1;
  final double netOwedToUser2;
  final int unsettledCount;

  const BalanceSummary({
    this.totalSpent = 0.0,
    this.user1Paid = 0.0,
    this.user2Paid = 0.0,
    this.netOwedToUser1 = 0.0,
    this.netOwedToUser2 = 0.0,
    this.unsettledCount = 0,
  });

  /// True if there is no pending debt between partners.
  bool get isSettledUp => netOwedToUser1 <= 0.001 && netOwedToUser2 <= 0.001;

  BalanceSummary copyWith({
    double? totalSpent,
    double? user1Paid,
    double? user2Paid,
    double? netOwedToUser1,
    double? netOwedToUser2,
    int? unsettledCount,
  }) {
    return BalanceSummary(
      totalSpent: totalSpent ?? this.totalSpent,
      user1Paid: user1Paid ?? this.user1Paid,
      user2Paid: user2Paid ?? this.user2Paid,
      netOwedToUser1: netOwedToUser1 ?? this.netOwedToUser1,
      netOwedToUser2: netOwedToUser2 ?? this.netOwedToUser2,
      unsettledCount: unsettledCount ?? this.unsettledCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BalanceSummary &&
          runtimeType == other.runtimeType &&
          totalSpent == other.totalSpent &&
          user1Paid == other.user1Paid &&
          user2Paid == other.user2Paid &&
          netOwedToUser1 == other.netOwedToUser1 &&
          netOwedToUser2 == other.netOwedToUser2 &&
          unsettledCount == other.unsettledCount;

  @override
  int get hashCode =>
      totalSpent.hashCode ^
      user1Paid.hashCode ^
      user2Paid.hashCode ^
      netOwedToUser1.hashCode ^
      netOwedToUser2.hashCode ^
      unsettledCount.hashCode;

  @override
  String toString() {
    return 'BalanceSummary(totalSpent: $totalSpent, user1Paid: $user1Paid, user2Paid: $user2Paid, netOwedToUser1: $netOwedToUser1, netOwedToUser2: $netOwedToUser2, unsettledCount: $unsettledCount)';
  }
}

/// Calculates net balance owed between [user1] and [user2] from a list of entries.
///
/// Excludes already settled entries (`isSettled == true`).
BalanceSummary calculateNetOwed(
  List<FinanceEntry> entries, {
  required String user1,
  required String user2,
}) {
  final unsettled = entries.where((e) => !e.isSettled).toList();

  double totalSpent = 0.0;
  double user1Paid = 0.0;
  double user2Paid = 0.0;
  double owedToUser1 = 0.0;
  double owedToUser2 = 0.0;

  for (final entry in unsettled) {
    totalSpent += entry.amount;
    if (entry.paidBy == user1) {
      user1Paid += entry.amount;
      owedToUser1 += entry.shareFor(user2, partnerUid: user1);
    } else if (entry.paidBy == user2) {
      user2Paid += entry.amount;
      owedToUser2 += entry.shareFor(user1, partnerUid: user2);
    }
  }

  final net = owedToUser1 - owedToUser2;
  double netOwedToUser1 = 0.0;
  double netOwedToUser2 = 0.0;

  if (net > 0.0001) {
    netOwedToUser1 = (net * 100).roundToDouble() / 100.0;
  } else if (net < -0.0001) {
    netOwedToUser2 = ((-net) * 100).roundToDouble() / 100.0;
  }

  return BalanceSummary(
    totalSpent: (totalSpent * 100).roundToDouble() / 100.0,
    user1Paid: (user1Paid * 100).roundToDouble() / 100.0,
    user2Paid: (user2Paid * 100).roundToDouble() / 100.0,
    netOwedToUser1: netOwedToUser1,
    netOwedToUser2: netOwedToUser2,
    unsettledCount: unsettled.length,
  );
}
