import 'package:flutter/foundation.dart';

/// Represents a shared task or chore between partners.
@immutable
class TaskModel {
  final String id;
  final String title;
  final String description;
  final String? assignedTo;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final String createdBy;
  final String category;

  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.assignedTo,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.createdBy = '',
    this.category = 'General',
  });

  /// Returns a new [TaskModel] with its completion state toggled.
  /// If completed, sets `completedAt` to the current timestamp;
  /// if uncompleted, resets `completedAt` to `null`.
  TaskModel toggle() {
    final nextCompleted = !isCompleted;
    return copyWith(
      isCompleted: nextCompleted,
      completedAt: nextCompleted ? DateTime.now() : null,
      clearCompletedAt: !nextCompleted,
    );
  }

  /// Converts this [TaskModel] into a Map for Firestore persistence.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdBy': createdBy,
      'category': category,
    };
  }

  /// Creates a [TaskModel] from a Firestore map with resilient date parsing.
  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      assignedTo: map['assignedTo'] as String?,
      dueDate: _parseNullableDateTime(map['dueDate']),
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: _parseNullableDateTime(map['completedAt']),
      createdBy: map['createdBy'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
    );
  }

  /// Returns a copy of this task with the specified fields replaced.
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    bool clearAssignedTo = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? createdBy,
    String? category,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdBy: createdBy ?? this.createdBy,
      category: category ?? this.category,
    );
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          assignedTo == other.assignedTo &&
          dueDate == other.dueDate &&
          isCompleted == other.isCompleted &&
          completedAt == other.completedAt &&
          createdBy == other.createdBy &&
          category == other.category;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      assignedTo.hashCode ^
      dueDate.hashCode ^
      isCompleted.hashCode ^
      completedAt.hashCode ^
      createdBy.hashCode ^
      category.hashCode;

  @override
  String toString() {
    return 'TaskModel(id: $id, title: $title, assignedTo: $assignedTo, dueDate: $dueDate, isCompleted: $isCompleted, category: $category)';
  }
}
