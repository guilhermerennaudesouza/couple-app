import 'package:flutter/foundation.dart';

/// Represents a single monetary contribution made by one partner towards a savings goal.
@immutable
class SavingsContribution {
  final String id;
  final String uid;
  final double amount;
  final DateTime date;
  final String? note;

  SavingsContribution({
    required this.id,
    required this.uid,
    required this.amount,
    DateTime? date,
    this.note,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'amount': amount,
      'date': date.toIso8601String(),
      if (note != null) 'note': note,
    };
  }

  factory SavingsContribution.fromMap(Map<String, dynamic> map) {
    return SavingsContribution(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      amount: _parseAmount(map['amount']),
      date: _parseDateTime(map['date']),
      note: map['note'] as String?,
    );
  }

  SavingsContribution copyWith({
    String? id,
    String? uid,
    double? amount,
    DateTime? date,
    String? note,
  }) {
    return SavingsContribution(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
      other is SavingsContribution &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uid == other.uid &&
          amount == other.amount &&
          date == other.date &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      uid.hashCode ^
      amount.hashCode ^
      date.hashCode ^
      note.hashCode;

  @override
  String toString() {
    return 'SavingsContribution(id: $id, uid: $uid, amount: $amount, date: $date, note: $note)';
  }
}

/// Represents a joint savings goal (digital piggy bank) for a couple.
@immutable
class SavingsGoalModel {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String category;
  final bool isCompleted;
  final List<SavingsContribution> contributions;
  final String createdBy;
  final DateTime createdAt;

  /// Curated romantic and practical savings categories for couples.
  static const List<String> categories = [
    'Vacation',
    'Wedding',
    'Home',
    'Emergency',
    'Date Night',
    'Vehicle',
    'Other',
  ];

  SavingsGoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    this.category = 'Other',
    this.isCompleted = false,
    this.contributions = const [],
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Progress ratio clamped strictly between 0.0 and 1.0 for UI progress bars.
  double get progressRatio =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Progress percentage integer (0 to 100).
  int get progressPercentage => (progressRatio * 100).round();

  /// Remaining amount needed to reach the target.
  double get remainingAmount => (targetAmount - currentAmount) > 0
      ? ((targetAmount - currentAmount) * 100).roundToDouble() / 100.0
      : 0.0;

  /// Whether the target amount has been achieved.
  bool get isTargetReached => currentAmount >= targetAmount && targetAmount > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate?.toIso8601String(),
      'category': category,
      'isCompleted': isCompleted || isTargetReached,
      'contributions': contributions.map((c) => c.toMap()).toList(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoalModel.fromMap(String id, Map<String, dynamic> map) {
    final rawContributions = map['contributions'];
    final List<SavingsContribution> parsedContributions = [];
    if (rawContributions is List) {
      for (final item in rawContributions) {
        if (item is Map<String, dynamic>) {
          parsedContributions.add(SavingsContribution.fromMap(item));
        } else if (item is Map) {
          parsedContributions.add(
            SavingsContribution.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final target = _parseAmount(map['targetAmount']);
    final current = _parseAmount(map['currentAmount']);
    final completed = map['isCompleted'] as bool? ?? (current >= target && target > 0);

    return SavingsGoalModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      targetAmount: target,
      currentAmount: current,
      targetDate: map['targetDate'] != null
          ? _parseDateTime(map['targetDate'])
          : null,
      category: map['category'] as String? ?? 'Other',
      isCompleted: completed,
      contributions: parsedContributions,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  SavingsGoalModel copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? category,
    bool? isCompleted,
    List<SavingsContribution>? contributions,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      contributions: contributions ?? this.contributions,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
      other is SavingsGoalModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          targetAmount == other.targetAmount &&
          currentAmount == other.currentAmount &&
          targetDate == other.targetDate &&
          category == other.category &&
          isCompleted == other.isCompleted &&
          listEquals(contributions, other.contributions) &&
          createdBy == other.createdBy &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      targetAmount.hashCode ^
      currentAmount.hashCode ^
      targetDate.hashCode ^
      category.hashCode ^
      isCompleted.hashCode ^
      Object.hashAll(contributions) ^
      createdBy.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'SavingsGoalModel(id: $id, title: $title, targetAmount: $targetAmount, currentAmount: $currentAmount, category: $category, isCompleted: $isCompleted)';
  }
}
