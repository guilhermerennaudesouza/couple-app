import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a romantic Love Coupon ("Cupom de Amor") or shared Loyalty/Gift Card
/// ("Cartão Fidelidade / Vale-Presente") in the couple's space.
class LoyaltyCouponModel {
  static const String typeCoupon = 'coupon';
  static const String typeCard = 'loyalty_card';

  static const String categoryRomance = 'Romance';
  static const String categoryCare = 'Carinho';
  static const String categoryFun = 'Diversão';
  static const String categoryFood = 'Gastronomia';
  static const String categoryStore = 'Fidelidade';

  static const List<String> couponCategories = [
    categoryRomance,
    categoryCare,
    categoryFun,
    categoryFood,
  ];

  final String id;
  final String title;
  final String description;
  final String emoji;
  final String category;
  final String type; // 'coupon' or 'loyalty_card'
  final int maxUses;
  final int usedCount;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? lastRedeemedAt;
  final String? lastRedeemedBy;
  final String? cardCode; // Barcode / gift card number / store loyalty code
  final String? storeName;

  const LoyaltyCouponModel({
    required this.id,
    required this.title,
    required this.description,
    this.emoji = '🎟️',
    this.category = categoryRomance,
    this.type = typeCoupon,
    this.maxUses = 1,
    this.usedCount = 0,
    required this.createdBy,
    required this.createdAt,
    this.lastRedeemedAt,
    this.lastRedeemedBy,
    this.cardCode,
    this.storeName,
  });

  bool get isLoyaltyCard => type == typeCard;
  int get remainingUses => (maxUses - usedCount).clamp(0, 999);
  bool get isExhausted => !isLoyaltyCard && usedCount >= maxUses;
  bool get canRedeem => !isLoyaltyCard && remainingUses > 0;

  LoyaltyCouponModel redeem({
    required String redeemedByUid,
    DateTime? redeemedAt,
  }) {
    if (isExhausted) return this;
    return copyWith(
      usedCount: usedCount + 1,
      lastRedeemedAt: redeemedAt ?? DateTime.now(),
      lastRedeemedBy: redeemedByUid,
    );
  }

  LoyaltyCouponModel copyWith({
    String? id,
    String? title,
    String? description,
    String? emoji,
    String? category,
    String? type,
    int? maxUses,
    int? usedCount,
    String? createdBy,
    DateTime? createdAt,
    DateTime? lastRedeemedAt,
    String? lastRedeemedBy,
    String? cardCode,
    String? storeName,
  }) {
    return LoyaltyCouponModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      category: category ?? this.category,
      type: type ?? this.type,
      maxUses: maxUses ?? this.maxUses,
      usedCount: usedCount ?? this.usedCount,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      lastRedeemedAt: lastRedeemedAt ?? this.lastRedeemedAt,
      lastRedeemedBy: lastRedeemedBy ?? this.lastRedeemedBy,
      cardCode: cardCode ?? this.cardCode,
      storeName: storeName ?? this.storeName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'emoji': emoji,
      'category': category,
      'type': type,
      'maxUses': maxUses,
      'usedCount': usedCount,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastRedeemedAt':
          lastRedeemedAt != null ? Timestamp.fromDate(lastRedeemedAt!) : null,
      'lastRedeemedBy': lastRedeemedBy,
      'cardCode': cardCode,
      'storeName': storeName,
    };
  }

  factory LoyaltyCouponModel.fromMap(String id, Map<String, dynamic> map) {
    return LoyaltyCouponModel(
      id: id,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      emoji: (map['emoji'] as String?) ?? '🎟️',
      category: (map['category'] as String?) ?? categoryRomance,
      type: (map['type'] as String?) ?? typeCoupon,
      maxUses: (map['maxUses'] as num?)?.toInt() ?? 1,
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      createdBy: (map['createdBy'] as String?) ?? 'system',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      lastRedeemedAt: _parseDate(map['lastRedeemedAt']),
      lastRedeemedBy: map['lastRedeemedBy'] as String?,
      cardCode: map['cardCode'] as String?,
      storeName: map['storeName'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
