import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/crypto/vault_crypto_service.dart';
import 'package:couple_app/features/vault/domain/vault_item_model.dart';
import 'package:couple_app/features/cheatsheet/domain/cheatsheet_model.dart';

void main() {
  group('VaultCryptoService tests', () {
    late VaultCryptoService cryptoService;

    setUp(() {
      cryptoService = VaultCryptoService();
    });

    test('Derives 256-bit key using PBKDF2 with 6-digit PIN and salt', () async {
      const pin = '123456';
      const salt = 'krivo_salt_unit_test';

      final key1 = await cryptoService.deriveKey(pin: pin, salt: salt);
      final bytes1 = await key1.extractBytes();

      // 256 bits = 32 bytes
      expect(bytes1.length, equals(32));

      // Deterministic derivation for identical PIN and salt
      final key2 = await cryptoService.deriveKey(pin: pin, salt: salt);
      final bytes2 = await key2.extractBytes();
      expect(bytes1, equals(bytes2));

      // Different salt produces a distinct key
      final keyDifferentSalt = await cryptoService.deriveKey(
        pin: pin,
        salt: 'different_salt_456',
      );
      final bytesDiff = await keyDifferentSalt.extractBytes();
      expect(bytesDiff, isNot(equals(bytes1)));
    });

    test('Encrypts and decrypts secret plaintext via AES-256-GCM accurately', () async {
      final key = await cryptoService.deriveKey(
        pin: '654321',
        salt: 'aes_gcm_salt',
      );

      const secretNote = 'Meet me under the Eiffel Tower at midnight 💕';
      final payload = await cryptoService.encrypt(
        plaintext: secretNote,
        key: key,
      );

      expect(payload.ciphertextBase64.isNotEmpty, isTrue);
      expect(payload.nonceBase64.isNotEmpty, isTrue);
      expect(payload.macBase64.isNotEmpty, isTrue);

      final decrypted = await cryptoService.decrypt(
        payload: payload,
        key: key,
      );

      expect(decrypted, equals(secretNote));
    });

    test('Rejects decryption when incorrect key or corrupted ciphertext / MAC is passed', () async {
      final correctKey = await cryptoService.deriveKey(
        pin: '112233',
        salt: 'auth_salt_test',
      );
      final wrongKey = await cryptoService.deriveKey(
        pin: '998877',
        salt: 'auth_salt_test',
      );

      const secret = 'Super confidential marriage vow draft';
      final payload = await cryptoService.encrypt(
        plaintext: secret,
        key: correctKey,
      );

      // Decryption with wrong key must fail
      expect(
        () => cryptoService.decrypt(payload: payload, key: wrongKey),
        throwsA(isA<VaultCryptoException>()),
      );

      // Decryption with corrupted ciphertext must fail
      final corruptedCiphertextPayload = payload.copyWith(
        ciphertextBase64: 'AAAA${payload.ciphertextBase64.substring(4)}',
      );
      expect(
        () => cryptoService.decrypt(
          payload: corruptedCiphertextPayload,
          key: correctKey,
        ),
        throwsA(isA<VaultCryptoException>()),
      );

      // Decryption with corrupted MAC must fail
      final corruptedMacPayload = payload.copyWith(
        macBase64: 'FFFF${payload.macBase64.substring(4)}',
      );
      expect(
        () => cryptoService.decrypt(
          payload: corruptedMacPayload,
          key: correctKey,
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('Export and import key bytes preserve decryption capability', () async {
      final originalKey = await cryptoService.deriveKey(
        pin: '789123',
        salt: 'export_import_salt',
      );

      const message = 'Bank account PIN & master password';
      final payload = await cryptoService.encrypt(
        plaintext: message,
        key: originalKey,
      );

      // Export key to base64
      final base64Key = await cryptoService.exportKeyBytes(originalKey);
      expect(base64Key.isNotEmpty, isTrue);

      // Re-import key from base64
      final importedKey = cryptoService.importKeyBytes(base64Key);

      // Decrypt using imported key
      final decrypted = await cryptoService.decrypt(
        payload: payload,
        key: importedKey,
      );
      expect(decrypted, equals(message));
    });
  });

  group('EncryptedVaultPayload tests', () {
    test('EncryptedVaultPayload serialization round-trip', () {
      const payload = EncryptedVaultPayload(
        ciphertextBase64: 'dGVzdF9jaXBoZXI=',
        nonceBase64: 'bm9uY2VfZGF0YQ==',
        macBase64: 'bWFjX2F1dGg=',
      );

      final map = payload.toMap();
      final restored = EncryptedVaultPayload.fromMap(map);

      expect(restored.ciphertextBase64, equals('dGVzdF9jaXBoZXI='));
      expect(restored.nonceBase64, equals('bm9uY2VfZGF0YQ=='));
      expect(restored.macBase64, equals('bWFjX2F1dGg='));
      expect(restored, equals(payload));
      expect(restored.hashCode, equals(payload.hashCode));
    });
  });

  group('VaultItemModel tests', () {
    test('VaultItemModel serialization round-trip preserving EncryptedVaultPayload', () {
      const payload = EncryptedVaultPayload(
        ciphertextBase64: 'c2VjcmV0X2J5dGVz',
        nonceBase64: 'bm9uY2VfYnl0ZXM=',
        macBase64: 'bWFjX2J5dGVz',
      );
      final createdAt = DateTime(2026, 11, 4, 12, 0);
      final updatedAt = DateTime(2026, 11, 4, 14, 30);

      final item = VaultItemModel(
        id: 'v_item_1',
        title: 'Apartment Safe Combination',
        category: 'Personal',
        type: VaultItemModel.typeCode,
        payload: payload,
        createdBy: 'user_alex',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final map = item.toMap();
      final restored = VaultItemModel.fromMap('v_item_1', map);

      expect(restored.id, equals('v_item_1'));
      expect(restored.title, equals('Apartment Safe Combination'));
      expect(restored.category, equals('Personal'));
      expect(restored.type, equals(VaultItemModel.typeCode));
      expect(restored.payload.ciphertextBase64, equals('c2VjcmV0X2J5dGVz'));
      expect(restored.payload.nonceBase64, equals('bm9uY2VfYnl0ZXM='));
      expect(restored.payload.macBase64, equals('bWFjX2J5dGVz'));
      expect(restored.createdBy, equals('user_alex'));
      expect(restored.createdAt.isAtSameMomentAs(createdAt), isTrue);
      expect(restored.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
    });

    test('VaultItemModel copyWith and value equality', () {
      const payload = EncryptedVaultPayload(
        ciphertextBase64: 'cipher123',
        nonceBase64: 'nonce123',
        macBase64: 'mac123',
      );
      final item1 = VaultItemModel(
        id: 'v_item_2',
        title: 'Netflix Account',
        category: 'Passwords',
        type: VaultItemModel.typePassword,
        payload: payload,
        createdBy: 'user_1',
      );
      final item2 = VaultItemModel(
        id: 'v_item_2',
        title: 'Netflix Account',
        category: 'Passwords',
        type: VaultItemModel.typePassword,
        payload: payload,
        createdBy: 'user_1',
        createdAt: item1.createdAt,
        updatedAt: item1.updatedAt,
      );

      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));

      final updated = item1.copyWith(title: 'Disney+ Account');
      expect(updated.title, equals('Disney+ Account'));
      expect(updated.id, equals('v_item_2'));
      expect(updated.category, equals('Passwords'));
    });

    test('VaultItemModel resilient date and map parsing', () {
      final fakeTimestamp = _FakeTimestamp(DateTime(2026, 11, 4, 18, 0));
      final map = {
        'id': 'v_test_resilient',
        'title': 'Test Item',
        'category': 'Romantic',
        'type': 'note',
        'payload': {
          'ciphertextBase64': 'abc',
          'nonceBase64': 'def',
          'macBase64': 'ghi',
        },
        'createdBy': 'user_1',
        'createdAt': 1730728800000,
        'updatedAt': fakeTimestamp,
      };

      final item = VaultItemModel.fromMap(map);
      expect(item.id, equals('v_test_resilient'));
      expect(item.createdAt.millisecondsSinceEpoch, equals(1730728800000));
      expect(item.updatedAt.year, equals(2026));
      expect(item.payload.ciphertextBase64, equals('abc'));
    });
  });

  group('PartnerCheatsheetModel tests', () {
    test('PartnerCheatsheetModel serialization round-trip preserving all preference fields', () {
      final updatedAt = DateTime(2026, 11, 4, 15, 45);
      final cheatsheet = PartnerCheatsheetModel(
        uid: 'uid_partner_emma',
        clothingSize: 'Small / Medium',
        shoeSize: 'US 7.5 / EU 38',
        ringSize: 'Size 6',
        coffeeOrder: 'Iced oat milk latte with 2 pumps vanilla',
        allergies: 'Tree nuts, shellfish, cilantro',
        comfortFood: 'Margherita pizza and dark chocolate gelato',
        favoriteFlowers: 'Pink peonies and white roses',
        notes: 'Loves rose gold jewelry, vintage vinyl records, and cozy oversized sweaters.',
        updatedAt: updatedAt,
      );

      final map = cheatsheet.toMap();
      final restored = PartnerCheatsheetModel.fromMap('uid_partner_emma', map);

      expect(restored.uid, equals('uid_partner_emma'));
      expect(restored.clothingSize, equals('Small / Medium'));
      expect(restored.shoeSize, equals('US 7.5 / EU 38'));
      expect(restored.ringSize, equals('Size 6'));
      expect(restored.coffeeOrder, equals('Iced oat milk latte with 2 pumps vanilla'));
      expect(restored.allergies, equals('Tree nuts, shellfish, cilantro'));
      expect(restored.comfortFood, equals('Margherita pizza and dark chocolate gelato'));
      expect(restored.favoriteFlowers, equals('Pink peonies and white roses'));
      expect(restored.notes, contains('vintage vinyl records'));
      expect(restored.updatedAt.isAtSameMomentAs(updatedAt), isTrue);
      expect(restored.isNotEmpty, isTrue);
      expect(restored.isEmpty, isFalse);
    });

    test('PartnerCheatsheetModel copyWith and clearing flags', () {
      final original = PartnerCheatsheetModel(
        uid: 'uid_1',
        clothingSize: 'Medium',
        shoeSize: '10',
        ringSize: '9',
        coffeeOrder: 'Black drip coffee',
      );

      final cleared = original.copyWith(
        clearCoffeeOrder: true,
        shoeSize: '10.5',
      );

      expect(cleared.coffeeOrder, isNull);
      expect(cleared.shoeSize, equals('10.5'));
      expect(cleared.clothingSize, equals('Medium'));
      expect(cleared.ringSize, equals('9'));

      final emptyModel = PartnerCheatsheetModel(uid: 'uid_empty');
      expect(emptyModel.isEmpty, isTrue);
      expect(emptyModel.isNotEmpty, isFalse);
    });

    test('PartnerCheatsheetModel resilient date and timestamp parsing', () {
      final fakeTimestamp = _FakeTimestamp(DateTime(2026, 11, 4, 20, 0));
      final map = {
        'clothingSize': 'Large',
        'updatedAt': fakeTimestamp,
      };

      final model = PartnerCheatsheetModel.fromMap('uid_timed', map);
      expect(model.uid, equals('uid_timed'));
      expect(model.clothingSize, equals('Large'));
      expect(model.updatedAt.year, equals(2026));
      expect(model.updatedAt.hour, equals(20));
    });
  });
}

class _FakeTimestamp {
  final DateTime _dt;
  _FakeTimestamp(this._dt);
  DateTime toDate() => _dt;
}
