import 'package:flutter/foundation.dart';

/// Represents an item on the couple's shared wishlist.
///
/// Can represent romantic gifts, vacation bucket lists, home furnishings, or date ideas.
/// Tracks purchase status, estimated cost, and direct product links.
@immutable
class WishModel {
  static const String categoryGifts = 'Gifts';
  static const String categoryTrips = 'Trips';
  static const String categoryHome = 'Home';
  static const String categoryDates = 'Dates';
  static const String categoryOther = 'Other';

  static const List<String> categories = [
    categoryGifts,
    categoryTrips,
    categoryHome,
    categoryDates,
    categoryOther,
  ];

  final String id;
  final String title;
  final String? description;
  final String? url;
  final double? estimatedPrice;
  final String category;
  final bool isPurchased;
  final String? purchasedBy;
  final String createdBy;
  final DateTime createdAt;

  WishModel({
    required this.id,
    required this.title,
    this.description,
    this.url,
    this.estimatedPrice,
    this.category = categoryGifts,
    this.isPurchased = false,
    this.purchasedBy,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converts this wish into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'estimatedPrice': estimatedPrice,
      'category': category,
      'isPurchased': isPurchased,
      'purchasedBy': purchasedBy,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Creates a [WishModel] from Firestore data or raw map with resilient parsing.
  factory WishModel.fromMap(dynamic idOrMap, [dynamic maybeMap]) {
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

    return WishModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      url: map['url'] as String?,
      estimatedPrice: _parsePrice(map['estimatedPrice']),
      category: map['category'] as String? ?? categoryGifts,
      isPurchased: map['isPurchased'] as bool? ?? false,
      purchasedBy: map['purchasedBy'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Creates a copy of this wish with modified fields.
  WishModel copyWith({
    String? id,
    String? title,
    String? description,
    bool clearDescription = false,
    String? url,
    bool clearUrl = false,
    double? estimatedPrice,
    bool clearPrice = false,
    String? category,
    bool? isPurchased,
    String? purchasedBy,
    bool clearPurchasedBy = false,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return WishModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      url: clearUrl ? null : (url ?? this.url),
      estimatedPrice: clearPrice ? null : (estimatedPrice ?? this.estimatedPrice),
      category: category ?? this.category,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasedBy: clearPurchasedBy ? null : (purchasedBy ?? this.purchasedBy),
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static double? _parsePrice(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned);
    }
    return null;
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
      other is WishModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          url == other.url &&
          estimatedPrice == other.estimatedPrice &&
          category == other.category &&
          isPurchased == other.isPurchased &&
          purchasedBy == other.purchasedBy &&
          createdBy == other.createdBy &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        url,
        estimatedPrice,
        category,
        isPurchased,
        purchasedBy,
        createdBy,
        createdAt,
      );

  @override
  String toString() {
    return 'WishModel(id: $id, title: $title, category: $category, isPurchased: $isPurchased, price: $estimatedPrice)';
  }
}
