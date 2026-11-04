import 'package:flutter/foundation.dart';

/// Represents a digital time capsule sealed by a partner, scheduled to unlock
/// on a future milestone or anniversary date.
///
/// Contains secret love letters, predictions, reflections, and throwback photos.
/// The contents remain locked and sealed until [unlockDate].
@immutable
class TimeCapsuleModel {
  final String id;
  final String title;
  final DateTime unlockDate;
  final List<String> photoUrls;
  final String message;
  final bool isOpened;
  final DateTime? openedAt;
  final String createdBy;
  final DateTime createdAt;

  TimeCapsuleModel({
    required this.id,
    required this.title,
    required this.unlockDate,
    this.photoUrls = const [],
    required this.message,
    this.isOpened = false,
    this.openedAt,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Whether this capsule can be opened right now (or at the given [at] timestamp).
  ///
  /// Returns `true` if already opened, or if [at] is on/after [unlockDate].
  bool canOpen({DateTime? at}) {
    if (isOpened) return true;
    final current = at ?? DateTime.now();
    return current.isAfter(unlockDate) || current.isAtSameMomentAs(unlockDate);
  }

  /// Calculates the duration remaining until unlock date.
  ///
  /// Returns [Duration.zero] if the unlock date has arrived or passed.
  Duration timeRemaining({DateTime? at}) {
    final current = at ?? DateTime.now();
    if (current.isAfter(unlockDate) || current.isAtSameMomentAs(unlockDate)) {
      return Duration.zero;
    }
    return unlockDate.difference(current);
  }

  /// Returns a copy of this capsule marked as opened.
  TimeCapsuleModel open({DateTime? openedAt}) {
    return copyWith(
      isOpened: true,
      openedAt: openedAt ?? DateTime.now(),
    );
  }

  /// Converts this time capsule into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'unlockDate': unlockDate.toIso8601String(),
      'photoUrls': photoUrls,
      'message': message,
      'isOpened': isOpened,
      'openedAt': openedAt?.toIso8601String(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a [TimeCapsuleModel] from Firestore data or raw map with resilient parsing.
  factory TimeCapsuleModel.fromMap(dynamic idOrMap, [dynamic maybeMap]) {
    final String id;
    final Map<String, dynamic> map;

    if (idOrMap is String) {
      id = idOrMap;
      map = (maybeMap as Map<String, dynamic>?) ?? {};
    } else if (idOrMap is Map<String, dynamic>) {
      map = idOrMap;
      id = (maybeMap as String?) ?? (map['id'] as String? ?? '');
    } else {
      id = '';
      map = {};
    }

    return TimeCapsuleModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      unlockDate: _parseDateTime(map['unlockDate']),
      photoUrls: _parsePhotoUrls(map['photoUrls']),
      message: map['message'] as String? ?? '',
      isOpened: map['isOpened'] as bool? ?? false,
      openedAt: map['openedAt'] != null ? _parseDateTime(map['openedAt']) : null,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Creates a copy of this time capsule with modified fields.
  TimeCapsuleModel copyWith({
    String? id,
    String? title,
    DateTime? unlockDate,
    List<String>? photoUrls,
    String? message,
    bool? isOpened,
    DateTime? openedAt,
    bool clearOpenedAt = false,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return TimeCapsuleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      unlockDate: unlockDate ?? this.unlockDate,
      photoUrls: photoUrls ?? this.photoUrls,
      message: message ?? this.message,
      isOpened: isOpened ?? this.isOpened,
      openedAt: clearOpenedAt ? null : (openedAt ?? this.openedAt),
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
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

  static List<String> _parsePhotoUrls(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) {
      return [value];
    }
    return const [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeCapsuleModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          unlockDate == other.unlockDate &&
          listEquals(photoUrls, other.photoUrls) &&
          message == other.message &&
          isOpened == other.isOpened &&
          openedAt == other.openedAt &&
          createdBy == other.createdBy &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        unlockDate,
        Object.hashAll(photoUrls),
        message,
        isOpened,
        openedAt,
        createdBy,
        createdAt,
      );

  @override
  String toString() {
    return 'TimeCapsuleModel(id: $id, title: $title, unlockDate: $unlockDate, isOpened: $isOpened, createdBy: $createdBy)';
  }
}
