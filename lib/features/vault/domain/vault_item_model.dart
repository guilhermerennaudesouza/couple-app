import 'package:flutter/foundation.dart';
import '../../../core/crypto/vault_crypto_service.dart';

/// Domain entity representing a zero-knowledge encrypted item stored in the couple's private vault.
@immutable
class VaultItemModel {
  static const String typeNote = 'note';
  static const String typePassword = 'password';
  static const String typeDocument = 'document';
  static const String typeCode = 'code';

  static const List<String> standardTypes = [
    typeNote,
    typePassword,
    typeDocument,
    typeCode,
  ];

  static const List<String> standardCategories = [
    'Personal',
    'Passwords',
    'Financial',
    'Romantic',
    'Important Codes',
    'Documents',
    'Other',
  ];

  final String id;
  final String title;
  final String category;
  final String type; // 'note' | 'password' | 'document' | 'code'
  final EncryptedVaultPayload payload;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultItemModel({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.payload,
    required this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Converts this entity into a Firestore-compatible JSON map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'type': type,
      'payload': payload.toMap(),
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Deserializes a [VaultItemModel] from a document snapshot or test map.
  ///
  /// Supports both `fromMap(id, map)` and `fromMap(map)` parameter shapes.
  factory VaultItemModel.fromMap(
    dynamic idOrMap, [
    Map<String, dynamic>? maybeMap,
  ]) {
    final String id;
    final Map<String, dynamic> map;

    if (idOrMap is String && maybeMap != null) {
      id = idOrMap;
      map = maybeMap;
    } else if (idOrMap is Map<String, dynamic>) {
      id = idOrMap['id'] as String? ?? '';
      map = idOrMap;
    } else if (idOrMap is Map) {
      id = idOrMap['id']?.toString() ?? '';
      map = Map<String, dynamic>.from(idOrMap);
    } else {
      id = idOrMap?.toString() ?? '';
      map = maybeMap ?? {};
    }

    final rawPayload = map['payload'];
    final EncryptedVaultPayload payload;
    if (rawPayload is EncryptedVaultPayload) {
      payload = rawPayload;
    } else if (rawPayload is Map<String, dynamic>) {
      payload = EncryptedVaultPayload.fromMap(rawPayload);
    } else if (rawPayload is Map) {
      payload =
          EncryptedVaultPayload.fromMap(Map<String, dynamic>.from(rawPayload));
    } else {
      payload = const EncryptedVaultPayload(
        ciphertextBase64: '',
        nonceBase64: '',
        macBase64: '',
      );
    }

    return VaultItemModel(
      id: id,
      title: map['title'] as String? ?? 'Untitled',
      category: map['category'] as String? ?? 'Personal',
      type: map['type'] as String? ?? typeNote,
      payload: payload,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  VaultItemModel copyWith({
    String? id,
    String? title,
    String? category,
    String? type,
    EncryptedVaultPayload? payload,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
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
      other is VaultItemModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          type == other.type &&
          payload == other.payload &&
          createdBy == other.createdBy &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      category.hashCode ^
      type.hashCode ^
      payload.hashCode ^
      createdBy.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'VaultItemModel(id: $id, title: $title, category: $category, type: $type, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
