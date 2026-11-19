import 'package:flutter/foundation.dart';

/// Represents a couple's shared bucket list activity or curated date idea.
@immutable
class DateIdeaModel {
  static const String categoryCozy = 'Cozy';
  static const String categoryOutdoor = 'Outdoor';
  static const String categoryFoodie = 'Foodie';
  static const String categoryRomance = 'Romance';
  static const String categoryAdventurous = 'Adventurous';
  static const String categoryBudget = 'Budget';

  static const String voteLike = 'like';
  static const String votePass = 'pass';

  static const List<String> allCategories = [
    categoryCozy,
    categoryOutdoor,
    categoryFoodie,
    categoryRomance,
    categoryAdventurous,
    categoryBudget,
  ];

  final String id;
  final String title;
  final String description;
  final String category;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isWeeklyPick;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, String> votes;
  final DateTime? matchedAt;

  DateIdeaModel({
    required this.id,
    required this.title,
    this.description = '',
    this.category = categoryCozy,
    this.isCompleted = false,
    this.completedAt,
    this.isWeeklyPick = false,
    required this.createdBy,
    DateTime? createdAt,
    this.votes = const {},
    this.matchedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String? userVote(String uid) => votes[uid];

  int get likeCount => votes.values.where((v) => v == voteLike).length;

  /// True when both partners liked this idea (or `matchedAt` was explicitly recorded).
  bool get isMatched => matchedAt != null || likeCount >= 2;

  /// Toggles completion state. Sets completedAt when completed, or clears it when unmarked.
  DateIdeaModel toggleCompleted({DateTime? completedAt}) {
    final nextCompleted = !isCompleted;
    return copyWith(
      isCompleted: nextCompleted,
      completedAt: nextCompleted ? (completedAt ?? DateTime.now()) : null,
      clearCompletedAt: !nextCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'isWeeklyPick': isWeeklyPick,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      if (votes.isNotEmpty) 'votes': votes,
      if (matchedAt != null) 'matchedAt': matchedAt!.toIso8601String(),
    };
  }

  factory DateIdeaModel.fromMap(String id, Map<String, dynamic> map) {
    final parsedVotes = <String, String>{};
    final rawVotes = map['votes'];
    if (rawVotes is Map) {
      rawVotes.forEach((key, value) {
        if (value != null) {
          parsedVotes[key.toString()] = value.toString();
        }
      });
    }
    return DateIdeaModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? categoryCozy,
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt:
          map['completedAt'] != null ? _parseDateTime(map['completedAt']) : null,
      isWeeklyPick: map['isWeeklyPick'] as bool? ?? false,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      votes: parsedVotes,
      matchedAt:
          map['matchedAt'] != null ? _parseDateTime(map['matchedAt']) : null,
    );
  }

  DateIdeaModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? isWeeklyPick,
    String? createdBy,
    DateTime? createdAt,
    Map<String, String>? votes,
    DateTime? matchedAt,
    bool clearMatchedAt = false,
  }) {
    return DateIdeaModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isWeeklyPick: isWeeklyPick ?? this.isWeeklyPick,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      votes: votes ?? this.votes,
      matchedAt: clearMatchedAt ? null : (matchedAt ?? this.matchedAt),
    );
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
      other is DateIdeaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          category == other.category &&
          isCompleted == other.isCompleted &&
          isWeeklyPick == other.isWeeklyPick &&
          createdBy == other.createdBy &&
          mapEquals(votes, other.votes) &&
          matchedAt == other.matchedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      category.hashCode ^
      isCompleted.hashCode ^
      isWeeklyPick.hashCode ^
      createdBy.hashCode ^
      votes.length.hashCode ^
      matchedAt.hashCode;

  @override
  String toString() =>
      'DateIdeaModel(id: $id, title: $title, category: $category, isCompleted: $isCompleted, isMatched: $isMatched)';
}
