import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exception thrown when cryptographic operations fail (e.g., authentication failure or tampering).
class VaultCryptoException implements Exception {
  final String message;
  final Object? cause;

  const VaultCryptoException(this.message, [this.cause]);

  @override
  String toString() =>
      'VaultCryptoException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Represents an encrypted payload containing ciphertext, initialization vector (nonce),
/// and Galois Message Authentication Code (MAC) for authenticated AES-256-GCM encryption.
@immutable
class EncryptedVaultPayload {
  final String ciphertextBase64;
  final String nonceBase64;
  final String macBase64;

  const EncryptedVaultPayload({
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  /// Serializes payload to a Firestore-compatible JSON map.
  Map<String, dynamic> toMap() {
    return {
      'ciphertextBase64': ciphertextBase64,
      'nonceBase64': nonceBase64,
      'macBase64': macBase64,
    };
  }

  /// Deserializes payload from a Firestore map.
  factory EncryptedVaultPayload.fromMap(Map<String, dynamic> map) {
    return EncryptedVaultPayload(
      ciphertextBase64: map['ciphertextBase64'] as String? ?? '',
      nonceBase64: map['nonceBase64'] as String? ?? '',
      macBase64: map['macBase64'] as String? ?? '',
    );
  }

  EncryptedVaultPayload copyWith({
    String? ciphertextBase64,
    String? nonceBase64,
    String? macBase64,
  }) {
    return EncryptedVaultPayload(
      ciphertextBase64: ciphertextBase64 ?? this.ciphertextBase64,
      nonceBase64: nonceBase64 ?? this.nonceBase64,
      macBase64: macBase64 ?? this.macBase64,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EncryptedVaultPayload &&
          runtimeType == other.runtimeType &&
          ciphertextBase64 == other.ciphertextBase64 &&
          nonceBase64 == other.nonceBase64 &&
          macBase64 == other.macBase64;

  @override
  int get hashCode =>
      ciphertextBase64.hashCode ^ nonceBase64.hashCode ^ macBase64.hashCode;

  @override
  String toString() =>
      'EncryptedVaultPayload(ciphertextBase64: $ciphertextBase64, nonceBase64: $nonceBase64, macBase64: $macBase64)';
}

/// Cryptographic service providing zero-knowledge client-side encryption
/// using AES-256-GCM and PBKDF2 key derivation with HMAC-SHA256.
class VaultCryptoService {
  final Cipher _cipher;
  final Pbkdf2 _pbkdf2;

  VaultCryptoService({
    Cipher? cipher,
    Pbkdf2? pbkdf2,
  })  : _cipher = cipher ?? AesGcm.with256Bits(),
        _pbkdf2 = pbkdf2 ??
            Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: 100000,
              bits: 256,
            );

  /// Derives a 256-bit [SecretKey] from a 6-digit user PIN and salt using PBKDF2 (100,000 iterations).
  Future<SecretKey> deriveKey({
    required String pin,
    required String salt,
  }) async {
    return await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: utf8.encode(salt),
    );
  }

  /// Encrypts UTF-8 [plaintext] using AES-256-GCM authenticated cipher with the provided [key].
  Future<EncryptedVaultPayload> encrypt({
    required String plaintext,
    required SecretKey key,
  }) async {
    try {
      final secretBox = await _cipher.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
      );
      return EncryptedVaultPayload(
        ciphertextBase64: base64Encode(secretBox.cipherText),
        nonceBase64: base64Encode(secretBox.nonce),
        macBase64: base64Encode(secretBox.mac.bytes),
      );
    } catch (e) {
      throw VaultCryptoException('Failed to encrypt plaintext', e);
    }
  }

  /// Decrypts [payload] using AES-256-GCM authenticated cipher with the provided [key].
  ///
  /// Throws [VaultCryptoException] if MAC verification fails, key is incorrect, or payload is corrupt.
  Future<String> decrypt({
    required EncryptedVaultPayload payload,
    required SecretKey key,
  }) async {
    try {
      final secretBox = SecretBox(
        base64Decode(payload.ciphertextBase64),
        nonce: base64Decode(payload.nonceBase64),
        mac: Mac(base64Decode(payload.macBase64)),
      );
      final clearTextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: key,
      );
      return utf8.decode(clearTextBytes);
    } catch (e) {
      throw VaultCryptoException(
        'Decryption failed: incorrect key or tampered payload',
        e,
      );
    }
  }

  /// Exports [key] raw bytes as a Base64-encoded string for secure storage in hardware secure enclave.
  Future<String> exportKeyBytes(SecretKey key) async {
    final bytes = await key.extractBytes();
    return base64Encode(bytes);
  }

  /// Reconstitutes a [SecretKey] from a Base64-encoded raw key string.
  SecretKey importKeyBytes(String base64Key) {
    final bytes = base64Decode(base64Key);
    return SecretKey(bytes);
  }
}

/// Riverpod provider for [VaultCryptoService].
final vaultCryptoServiceProvider = Provider<VaultCryptoService>((ref) {
  return VaultCryptoService();
});
