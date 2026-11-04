import 'package:flutter/foundation.dart';

/// Domain entity holding romantic cheatsheet preferences and sizes for a partner.
@immutable
class PartnerCheatsheetModel {
  final String uid;
  final String? clothingSize;
  final String? shoeSize;
  final String? ringSize;
  final String? coffeeOrder;
  final String? allergies;
  final String? comfortFood;
  final String? favoriteFlowers;
  final String? notes;
  final DateTime updatedAt;

  PartnerCheatsheetModel({
    required this.uid,
    this.clothingSize,
    this.shoeSize,
    this.ringSize,
    this.coffeeOrder,
    this.allergies,
    this.comfortFood,
    this.favoriteFlowers,
    this.notes,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Returns true if all preference fields are null or empty.
  bool get isEmpty =>
      (clothingSize == null || clothingSize!.trim().isEmpty) &&
      (shoeSize == null || shoeSize!.trim().isEmpty) &&
      (ringSize == null || ringSize!.trim().isEmpty) &&
      (coffeeOrder == null || coffeeOrder!.trim().isEmpty) &&
      (allergies == null || allergies!.trim().isEmpty) &&
      (comfortFood == null || comfortFood!.trim().isEmpty) &&
      (favoriteFlowers == null || favoriteFlowers!.trim().isEmpty) &&
      (notes == null || notes!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  /// Serializes cheatsheet data to a Firestore map.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'clothingSize': clothingSize,
      'shoeSize': shoeSize,
      'ringSize': ringSize,
      'coffeeOrder': coffeeOrder,
      'allergies': allergies,
      'comfortFood': comfortFood,
      'favoriteFlowers': favoriteFlowers,
      'notes': notes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes a [PartnerCheatsheetModel] from a Firestore map or test data.
  ///
  /// Supports both `fromMap(uid, map)` and `fromMap(map)` parameter shapes.
  factory PartnerCheatsheetModel.fromMap(
    dynamic uidOrMap, [
    Map<String, dynamic>? maybeMap,
  ]) {
    final String uid;
    final Map<String, dynamic> map;

    if (uidOrMap is String && maybeMap != null) {
      uid = uidOrMap;
      map = maybeMap;
    } else if (uidOrMap is Map<String, dynamic>) {
      uid = uidOrMap['uid'] as String? ?? '';
      map = uidOrMap;
    } else if (uidOrMap is Map) {
      uid = uidOrMap['uid']?.toString() ?? '';
      map = Map<String, dynamic>.from(uidOrMap);
    } else {
      uid = uidOrMap?.toString() ?? '';
      map = maybeMap ?? {};
    }

    return PartnerCheatsheetModel(
      uid: uid,
      clothingSize: map['clothingSize'] as String?,
      shoeSize: map['shoeSize'] as String?,
      ringSize: map['ringSize'] as String?,
      coffeeOrder: map['coffeeOrder'] as String?,
      allergies: map['allergies'] as String?,
      comfortFood: map['comfortFood'] as String?,
      favoriteFlowers: map['favoriteFlowers'] as String?,
      notes: map['notes'] as String?,
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  PartnerCheatsheetModel copyWith({
    String? uid,
    String? clothingSize,
    String? shoeSize,
    String? ringSize,
    String? coffeeOrder,
    String? allergies,
    String? comfortFood,
    String? favoriteFlowers,
    String? notes,
    DateTime? updatedAt,
    bool clearClothingSize = false,
    bool clearShoeSize = false,
    bool clearRingSize = false,
    bool clearCoffeeOrder = false,
    bool clearAllergies = false,
    bool clearComfortFood = false,
    bool clearFavoriteFlowers = false,
    bool clearNotes = false,
  }) {
    return PartnerCheatsheetModel(
      uid: uid ?? this.uid,
      clothingSize:
          clearClothingSize ? null : (clothingSize ?? this.clothingSize),
      shoeSize: clearShoeSize ? null : (shoeSize ?? this.shoeSize),
      ringSize: clearRingSize ? null : (ringSize ?? this.ringSize),
      coffeeOrder: clearCoffeeOrder ? null : (coffeeOrder ?? this.coffeeOrder),
      allergies: clearAllergies ? null : (allergies ?? this.allergies),
      comfortFood:
          clearComfortFood ? null : (comfortFood ?? this.comfortFood),
      favoriteFlowers:
          clearFavoriteFlowers ? null : (favoriteFlowers ?? this.favoriteFlowers),
      notes: clearNotes ? null : (notes ?? this.notes),
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
    } catch (_) {}
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerCheatsheetModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          clothingSize == other.clothingSize &&
          shoeSize == other.shoeSize &&
          ringSize == other.ringSize &&
          coffeeOrder == other.coffeeOrder &&
          allergies == other.allergies &&
          comfortFood == other.comfortFood &&
          favoriteFlowers == other.favoriteFlowers &&
          notes == other.notes &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      uid.hashCode ^
      clothingSize.hashCode ^
      shoeSize.hashCode ^
      ringSize.hashCode ^
      coffeeOrder.hashCode ^
      allergies.hashCode ^
      comfortFood.hashCode ^
      favoriteFlowers.hashCode ^
      notes.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'PartnerCheatsheetModel(uid: $uid, clothingSize: $clothingSize, shoeSize: $shoeSize, ringSize: $ringSize, coffeeOrder: $coffeeOrder, allergies: $allergies, comfortFood: $comfortFood, favoriteFlowers: $favoriteFlowers, notes: $notes, updatedAt: $updatedAt)';
  }
}
