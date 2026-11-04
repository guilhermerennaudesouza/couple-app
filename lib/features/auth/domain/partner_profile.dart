import 'package:flutter/foundation.dart';

@immutable
class PartnerProfile {
  final String uid;
  final String name;
  final String? avatarUrl;
  final String? fcmToken;
  final DateTime joinedAt;

  String get displayName => name;

  PartnerProfile({
    required this.uid,
    String? name,
    String? displayName,
    this.avatarUrl,
    this.fcmToken,
    DateTime? joinedAt,
  })  : name = name ?? displayName ?? '',
        joinedAt = joinedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (fcmToken != null) 'fcmToken': fcmToken,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }

  factory PartnerProfile.fromMap(Map<String, dynamic> map) {
    return PartnerProfile(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String?,
      fcmToken: map['fcmToken'] as String?,
      joinedAt: _parseDateTime(map['joinedAt']),
    );
  }

  PartnerProfile copyWith({
    String? uid,
    String? name,
    String? avatarUrl,
    String? fcmToken,
    DateTime? joinedAt,
  }) {
    return PartnerProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      joinedAt: joinedAt ?? this.joinedAt,
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
      other is PartnerProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          name == other.name &&
          avatarUrl == other.avatarUrl &&
          fcmToken == other.fcmToken &&
          joinedAt == other.joinedAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      name.hashCode ^
      avatarUrl.hashCode ^
      fcmToken.hashCode ^
      joinedAt.hashCode;

  @override
  String toString() {
    return 'PartnerProfile(uid: $uid, name: $name, avatarUrl: $avatarUrl, fcmToken: $fcmToken, joinedAt: $joinedAt)';
  }
}
