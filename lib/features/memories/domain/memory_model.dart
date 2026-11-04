import 'package:flutter/foundation.dart';

/// Represents a shared memory or milestone in the couple's photo timeline.
///
/// Stores metadata including title, date the moment occurred, romantic caption,
/// location, and cloud photo URLs.
@immutable
class MemoryModel {
  final String id;
  final String title;
  final DateTime date;
  final String caption;
  final List<String> photoUrls;
  final String? location;
  final String createdBy;
  final DateTime createdAt;

  MemoryModel({
    required this.id,
    required this.title,
    required this.date,
    required this.caption,
    this.photoUrls = const [],
    this.location,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converts this memory into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'caption': caption,
      'photoUrls': photoUrls,
      'location': location,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a [MemoryModel] from Firestore data or raw map with resilient parsing.
  ///
  /// Supports both `fromMap(doc.id, doc.data())` and `fromMap(map)`.
  factory MemoryModel.fromMap(dynamic idOrMap, [dynamic maybeMap]) {
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

    return MemoryModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      date: _parseDateTime(map['date']),
      caption: map['caption'] as String? ?? '',
      photoUrls: _parsePhotoUrls(map['photoUrls']),
      location: map['location'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Creates a copy of this memory with modified fields.
  MemoryModel copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? caption,
    List<String>? photoUrls,
    String? location,
    bool clearLocation = false,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return MemoryModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      caption: caption ?? this.caption,
      photoUrls: photoUrls ?? this.photoUrls,
      location: clearLocation ? null : (location ?? this.location),
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
      other is MemoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          date == other.date &&
          caption == other.caption &&
          listEquals(photoUrls, other.photoUrls) &&
          location == other.location &&
          createdBy == other.createdBy &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        date,
        caption,
        Object.hashAll(photoUrls),
        location,
        createdBy,
        createdAt,
      );

  @override
  String toString() {
    return 'MemoryModel(id: $id, title: $title, date: $date, photoUrlsCount: ${photoUrls.length}, location: $location)';
  }
}
