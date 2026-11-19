import 'package:flutter/foundation.dart';
import '../../../core/crypto/vault_crypto_service.dart';

/// Determines the PIN gate state for the couple's zero-knowledge Vault.
enum VaultPinMode {
  /// No sentinel exists and no vault items exist: first-time PIN creation.
  createNew,

  /// Shared Firestore sentinel exists: unlock and verify against it.
  unlockSentinel,

  /// Legacy upgrade: items exist without sentinel. Require existing PIN,
  /// verify by decrypting an existing item, then backfill the sentinel.
  legacyBackfill,
}

/// Stored at `/couples/{coupleId}/vault_meta/config` to guarantee both partners
/// derive and validate the exact same AES-256-GCM master key.
@immutable
class VaultConfigModel {
  static const String sentinelPlaintext = 'KRIVO_VAULT_OK_V1';

  final EncryptedVaultPayload sentinel;
  final DateTime updatedAt;

  VaultConfigModel({
    required this.sentinel,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Resolves the safe lock-gate mode given remote config and item presence.
  static VaultPinMode resolveMode({
    required bool hasConfig,
    required bool hasExistingItems,
  }) {
    if (hasConfig) return VaultPinMode.unlockSentinel;
    if (hasExistingItems) return VaultPinMode.legacyBackfill;
    return VaultPinMode.createNew;
  }

  Map<String, dynamic> toMap() {
    return {
      'sentinel': sentinel.toMap(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VaultConfigModel.fromMap(Map<String, dynamic> map) {
    final rawSentinel = map['sentinel'];
    final sentinelMap = rawSentinel is Map<String, dynamic>
        ? rawSentinel
        : (rawSentinel is Map
            ? Map<String, dynamic>.from(rawSentinel)
            : const <String, dynamic>{});
    return VaultConfigModel(
      sentinel: EncryptedVaultPayload.fromMap(sentinelMap),
      updatedAt: _parseDateTime(map['updatedAt']),
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
}
