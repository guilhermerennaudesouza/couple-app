import 'package:flutter/foundation.dart';

/// Represents a single checklist item in an interactive shared checklist.
@immutable
class ChecklistItem {
  final String id;
  final String text;
  final bool isDone;
  final String addedBy;

  const ChecklistItem({
    required this.id,
    required this.text,
    this.isDone = false,
    this.addedBy = '',
  });

  /// Returns a new item with its completion state toggled or set to [done].
  ChecklistItem toggle([bool? done]) {
    return copyWith(isDone: done ?? !isDone);
  }

  /// Converts this [ChecklistItem] into a Map for Firestore persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isDone': isDone,
      'addedBy': addedBy,
    };
  }

  /// Creates a [ChecklistItem] from a Map.
  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isDone: map['isDone'] as bool? ?? false,
      addedBy: map['addedBy'] as String? ?? '',
    );
  }

  ChecklistItem copyWith({
    String? id,
    String? text,
    bool? isDone,
    String? addedBy,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      addedBy: addedBy ?? this.addedBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          isDone == other.isDone &&
          addedBy == other.addedBy;

  @override
  int get hashCode =>
      id.hashCode ^ text.hashCode ^ isDone.hashCode ^ addedBy.hashCode;

  @override
  String toString() {
    return 'ChecklistItem(id: $id, text: $text, isDone: $isDone, addedBy: $addedBy)';
  }
}

/// Represents an interactive shared checklist (e.g., Groceries, Packing, Date Night Prep).
@immutable
class ChecklistModel {
  final String id;
  final String title;
  final String category;
  final List<ChecklistItem> items;
  final DateTime updatedAt;

  ChecklistModel({
    required this.id,
    required this.title,
    this.category = 'General',
    this.items = const [],
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Number of completed items.
  int get completedCount => items.where((i) => i.isDone).length;

  /// Total count of items.
  int get totalCount => items.length;

  /// Completion percentage from `0.0` to `1.0`.
  double get progressPercentage =>
      totalCount == 0 ? 0.0 : completedCount / totalCount;

  /// True if all items are completed and list is not empty.
  bool get isFullyCompleted => totalCount > 0 && completedCount == totalCount;

  /// Toggles an item by [itemId], updating `updatedAt`.
  ChecklistModel toggleItem(String itemId, [bool? isDone]) {
    final updatedList = items.map((item) {
      if (item.id == itemId) {
        return item.toggle(isDone);
      }
      return item;
    }).toList();

    return copyWith(
      items: updatedList,
      updatedAt: DateTime.now(),
    );
  }

  /// Appends a new item to this checklist, updating `updatedAt`.
  ChecklistModel addItem(String text, String uid, [String? itemId]) {
    final newItem = ChecklistItem(
      id: itemId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      text: text.trim(),
      isDone: false,
      addedBy: uid,
    );

    return copyWith(
      items: [...items, newItem],
      updatedAt: DateTime.now(),
    );
  }

  /// Removes an item from this checklist by [itemId], updating `updatedAt`.
  ChecklistModel removeItem(String itemId) {
    final updatedList = items.where((i) => i.id != itemId).toList();
    return copyWith(
      items: updatedList,
      updatedAt: DateTime.now(),
    );
  }

  /// Converts this [ChecklistModel] into a Map for Firestore persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'items': items.map((i) => i.toMap()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Creates a [ChecklistModel] from a Firestore map with resilient parsing.
  factory ChecklistModel.fromMap(String id, Map<String, dynamic> map) {
    final rawItems = map['items'];
    final List<ChecklistItem> items = [];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          items.add(ChecklistItem.fromMap(raw));
        } else if (raw is Map) {
          items.add(ChecklistItem.fromMap(Map<String, dynamic>.from(raw)));
        }
      }
    }

    return ChecklistModel(
      id: id,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      items: items,
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  ChecklistModel copyWith({
    String? id,
    String? title,
    String? category,
    List<ChecklistItem>? items,
    DateTime? updatedAt,
  }) {
    return ChecklistModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      items: items ?? this.items,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          listEquals(items, other.items) &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      category.hashCode ^
      items.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'ChecklistModel(id: $id, title: $title, category: $category, progress: $completedCount/$totalCount)';
  }
}
