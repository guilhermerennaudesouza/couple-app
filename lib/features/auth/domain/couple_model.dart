import 'package:flutter/foundation.dart';
import 'partner_profile.dart';

@immutable
class CoupleModel {
  final String id;
  final List<String> members;
  final DateTime anniversaryDate;
  final String inviteCode;
  final Map<String, PartnerProfile> partnerProfiles;
  final DateTime createdAt;

  CoupleModel({
    required this.id,
    required this.members,
    required this.anniversaryDate,
    required this.inviteCode,
    this.partnerProfiles = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isFull => members.length >= 2;

  String? getOtherUid(String myUid) {
    if (!isFull || !members.contains(myUid)) return null;
    for (final member in members) {
      if (member != myUid) return member;
    }
    return null;
  }

  PartnerProfile? getPartnerProfile(String myUid) {
    final otherUid = getOtherUid(myUid);
    if (otherUid == null) return null;
    return partnerProfiles[otherUid];
  }

  PartnerProfile? getMyProfile(String myUid) {
    return partnerProfiles[myUid];
  }

  Map<String, dynamic> toMap() {
    return {
      'members': members,
      'anniversaryDate': anniversaryDate.toIso8601String(),
      'inviteCode': inviteCode,
      'partnerProfiles': partnerProfiles.map((k, v) => MapEntry(k, v.toMap())),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CoupleModel.fromMap(String id, Map<String, dynamic> map) {
    final rawMembers = map['members'];
    final List<String> members = rawMembers is List
        ? rawMembers.map((e) => e.toString()).toList()
        : <String>[];

    final rawProfiles = map['partnerProfiles'];
    final Map<String, PartnerProfile> partnerProfiles = {};
    if (rawProfiles is Map) {
      rawProfiles.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          partnerProfiles[key.toString()] = PartnerProfile.fromMap(value);
        } else if (value is Map) {
          partnerProfiles[key.toString()] = PartnerProfile.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return CoupleModel(
      id: id,
      members: members,
      anniversaryDate: _parseDateTime(map['anniversaryDate']),
      inviteCode: map['inviteCode'] as String? ?? '',
      partnerProfiles: partnerProfiles,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  CoupleModel copyWith({
    String? id,
    List<String>? members,
    DateTime? anniversaryDate,
    String? inviteCode,
    Map<String, PartnerProfile>? partnerProfiles,
    DateTime? createdAt,
  }) {
    return CoupleModel(
      id: id ?? this.id,
      members: members ?? this.members,
      anniversaryDate: anniversaryDate ?? this.anniversaryDate,
      inviteCode: inviteCode ?? this.inviteCode,
      partnerProfiles: partnerProfiles ?? this.partnerProfiles,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoupleModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          listEquals(members, other.members) &&
          anniversaryDate == other.anniversaryDate &&
          inviteCode == other.inviteCode &&
          mapEquals(partnerProfiles, other.partnerProfiles) &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      members.hashCode ^
      anniversaryDate.hashCode ^
      inviteCode.hashCode ^
      partnerProfiles.hashCode ^
      createdAt.hashCode;

  @override
  String toString() {
    return 'CoupleModel(id: $id, members: $members, anniversaryDate: $anniversaryDate, inviteCode: $inviteCode, isFull: $isFull, partnerProfiles: $partnerProfiles)';
  }
}
