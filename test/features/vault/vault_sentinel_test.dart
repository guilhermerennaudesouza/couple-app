import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/crypto/vault_crypto_service.dart';
import 'package:couple_app/features/vault/domain/vault_config_model.dart';

void main() {
  group('Vault Sentinel & Legacy Upgrade Tests', () {
    test('VaultCryptoService verifies sentinel with matching PIN and rejects wrong PIN', () async {
      final crypto = VaultCryptoService();
      const salt = 'krivo_vault_salt_couple1';
      final key1 = await crypto.deriveKey(pin: '123456', salt: salt);
      final key2 = await crypto.deriveKey(pin: '654321', salt: salt);

      final sentinel = await crypto.encrypt(
        plaintext: VaultConfigModel.sentinelPlaintext,
        key: key1,
      );
      final config = VaultConfigModel(sentinel: sentinel);
      final restored = VaultConfigModel.fromMap(config.toMap());

      expect(
        await crypto.decrypt(payload: restored.sentinel, key: key1),
        equals(VaultConfigModel.sentinelPlaintext),
      );
      expect(
        () => crypto.decrypt(payload: restored.sentinel, key: key2),
        throwsA(isA<VaultCryptoException>()),
      );
    });

    test('VaultPinMode resolution enforces legacy backfill when items exist without sentinel', () {
      expect(
        VaultConfigModel.resolveMode(hasConfig: true, hasExistingItems: true),
        equals(VaultPinMode.unlockSentinel),
      );
      expect(
        VaultConfigModel.resolveMode(hasConfig: true, hasExistingItems: false),
        equals(VaultPinMode.unlockSentinel),
      );
      expect(
        VaultConfigModel.resolveMode(hasConfig: false, hasExistingItems: true),
        equals(VaultPinMode.legacyBackfill),
      );
      expect(
        VaultConfigModel.resolveMode(hasConfig: false, hasExistingItems: false),
        equals(VaultPinMode.createNew),
      );
    });
  });
}
