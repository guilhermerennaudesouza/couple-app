import 'package:flutter/foundation.dart';

/// Represents a shared calendar event, anniversary, date night, or milestone
/// in the couple space.
@immutable
class CalendarEventModel {
  static const String categoryAnniversary = 'Anniversary';
  static const String categoryBirthday = 'Birthday';
  static const String categoryDateNight = 'Date Night';
  static const String categoryTravel = 'Travel';
  static const String categorySpecial = 'Special';

  static const List<String> categories = [
    categoryAnniversary,
    categoryBirthday,
    categoryDateNight,
    categoryTravel,
    categorySpecial,
  ];

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final bool isAnnual;
  final String category;
  final int reminderDaysBefore;
  final String createdBy;
  final DateTime createdAt;

  CalendarEventModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.date,
    this.isAnnual = false,
    this.category = categorySpecial,
    this.reminderDaysBefore = 0,
    this.createdBy = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Calculates whether a given year is a leap year.
  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Returns the date adjusted for a specific target year, safely handling
  /// February 29th in non-leap years by mapping to February 28th.
  DateTime _dateForYear(int year) {
    if (date.month == 2 && date.day == 29) {
      return _isLeapYear(year) ? DateTime(year, 2, 29) : DateTime(year, 2, 28);
    }
    return DateTime(year, date.month, date.day);
  }

  /// Returns the next upcoming occurrence of this event on or after [from].
  ///
  /// For non-annual events, returns the normalized date of the event.
  /// For annual recurring events, calculates this year's occurrence or rolls
  /// over to the following year if this year's occurrence has already passed.
  DateTime nextOccurrenceDate({DateTime? from}) {
    final ref = from ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    if (!isAnnual) {
      return DateTime(date.year, date.month, date.day);
    }

    final thisYearDate = _dateForYear(today.year);
    if (thisYearDate.isBefore(today)) {
      return _dateForYear(today.year + 1);
    }
    return thisYearDate;
  }

  /// Calculates the number of days until the next occurrence relative to [from].
  ///
  /// Uses UTC calendar dates to guarantee DST (Daylight Saving Time) resilience.
  /// Returns 0 if the next occurrence is today.
  int daysUntilNext({DateTime? from}) {
    final ref = from ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final next = nextOccurrenceDate(from: from);
    return DateTime.utc(next.year, next.month, next.day)
        .difference(DateTime.utc(today.year, today.month, today.day))
        .inDays;
  }

  /// Returns whether this event is strictly in the past relative to [from].
  ///
  /// Annual events recur perpetually, so they are never in the past.
  bool isPast({DateTime? from}) {
    if (isAnnual) return false;
    final ref = from ?? DateTime.now();
    final todayUtc = DateTime.utc(ref.year, ref.month, ref.day);
    final eventUtc = DateTime.utc(date.year, date.month, date.day);
    return eventUtc.isBefore(todayUtc);
  }

  /// Serializes this event into a Cloud Firestore document map.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'isAnnual': isAnnual,
      'category': category,
      'reminderDaysBefore': reminderDaysBefore,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Restores a [CalendarEventModel] from a document snapshot map with resilient
  /// date parsing for ISO strings, unix epoch timestamps, and Firestore Timestamp objects.
  factory CalendarEventModel.fromMap(String id, Map<String, dynamic> map) {
    return CalendarEventModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      date: _parseDateTime(map['date']),
      isAnnual: map['isAnnual'] as bool? ?? false,
      category: map['category'] as String? ?? categorySpecial,
      reminderDaysBefore: (map['reminderDaysBefore'] as num?)?.toInt() ?? 0,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Resilient multi-type date parsing.
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

  /// Creates a copy of this event with optional modified fields.
  CalendarEventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? isAnnual,
    String? category,
    int? reminderDaysBefore,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isAnnual: isAnnual ?? this.isAnnual,
      category: category ?? this.category,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          date.isAtSameMomentAs(other.date) &&
          isAnnual == other.isAnnual &&
          category == other.category &&
          reminderDaysBefore == other.reminderDaysBefore &&
          createdBy == other.createdBy &&
          createdAt.isAtSameMomentAs(other.createdAt);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      date.hashCode ^
      isAnnual.hashCode ^
      category.hashCode ^
      reminderDaysBefore.hashCode ^
      createdBy.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'CalendarEventModel(id: $id, title: $title, date: $date, isAnnual: $isAnnual, category: $category, reminderDaysBefore: $reminderDaysBefore)';
  }
}
