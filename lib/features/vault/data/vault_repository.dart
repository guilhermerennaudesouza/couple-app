import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/vault_config_model.dart';
import '../domain/vault_item_model.dart';

/// Repository managing encrypted private vault items and shared PIN sentinel
/// verification with Cloud Firestore synchronization.
///
/// Persisted under:
/// - `/couples/{coupleId}/vault_items/{itemId}`
/// - `/couples/{coupleId}/vault_meta/config`
class VaultRepository {
  final FirebaseFirestore _firestore;

  VaultRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _vaultCollection(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('vault_items');
  }

  DocumentReference<Map<String, dynamic>> _configDoc(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('vault_meta')
        .doc('config');
  }

  /// Reads the shared couple PIN verification sentinel if configured.
  Future<VaultConfigModel?> getVaultConfig(String coupleId) async {
    try {
      final snap = await _configDoc(coupleId).get();
      if (!snap.exists || snap.data() == null) return null;
      return VaultConfigModel.fromMap(snap.data()!);
    } catch (e) {
      debugPrint('VaultRepository.getVaultConfig error: $e');
      return null;
    }
  }

  /// Saves the shared couple PIN verification sentinel.
  Future<void> saveVaultConfig(String coupleId, VaultConfigModel config) async {
    await _configDoc(coupleId).set(config.toMap(), SetOptions(merge: true));
  }

  /// Fetches all current encrypted vault items once (used for legacy upgrade & PIN rotation).
  Future<List<VaultItemModel>> getAllVaultItemsOnce(String coupleId) async {
    final snap = await _vaultCollection(coupleId).get();
    return snap.docs
        .map((doc) => VaultItemModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Resolves the safe lock-gate mode for [coupleId].
  Future<VaultPinMode> resolveVaultPinMode(String coupleId) async {
    final config = await getVaultConfig(coupleId);
    if (config != null) return VaultPinMode.unlockSentinel;
    final itemsSnap = await _vaultCollection(coupleId).limit(1).get();
    return VaultConfigModel.resolveMode(
      hasConfig: false,
      hasExistingItems: itemsSnap.docs.isNotEmpty,
    );
  }

  /// Atomically replaces all re-encrypted vault items and the PIN sentinel during PIN change.
  Future<void> reencryptAllItemsAndSentinel(
    String coupleId, {
    required List<VaultItemModel> reencryptedItems,
    required VaultConfigModel newConfig,
  }) async {
    final batch = _firestore.batch();
    for (final item in reencryptedItems) {
      batch.set(
        _vaultCollection(coupleId).doc(item.id),
        item.toMap(),
        SetOptions(merge: true),
      );
    }
    batch.set(_configDoc(coupleId), newConfig.toMap());
    await batch.commit();
  }

  /// Permanently wipes all encrypted vault items and the shared PIN sentinel.
  Future<void> resetVault(String coupleId) async {
    final snap = await _vaultCollection(coupleId).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_configDoc(coupleId));
    await batch.commit();
  }

  /// Watches all encrypted vault items for a couple in real time.
  ///
  /// Sorted by [updatedAt] descending (most recently updated items first).
  Stream<List<VaultItemModel>> watchVaultItems(String coupleId) {
    return _vaultCollection(coupleId).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => VaultItemModel.fromMap(doc.id, doc.data()))
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    });
  }

  /// Saves or updates an encrypted vault item with offline-first merge durability.
  ///
  /// If [item.id] is empty, Firestore automatically provisions a new unique ID.
  Future<void> saveVaultItem(String coupleId, VaultItemModel item) async {
    final col = _vaultCollection(coupleId);
    final docRef = item.id.isEmpty ? col.doc() : col.doc(item.id);
    final itemToSave = item.id.isEmpty ? item.copyWith(id: docRef.id) : item;

    try {
      await docRef.set(itemToSave.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('VaultRepository.saveVaultItem error: $e');
      rethrow;
    }
  }

  /// Deletes an encrypted vault item by [itemId].
  Future<void> deleteVaultItem(String coupleId, String itemId) async {
    final docRef = _vaultCollection(coupleId).doc(itemId);
    try {
      await docRef.delete();
    } catch (e) {
      debugPrint('VaultRepository.deleteVaultItem error: $e');
      rethrow;
    }
  }
}

/// Riverpod provider for [VaultRepository].
final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository();
});

/// Stream provider for all encrypted vault items belonging to a couple.
final vaultItemsStreamProvider =
    StreamProvider.family<List<VaultItemModel>, String>((ref, coupleId) {
  final repository = ref.watch(vaultRepositoryProvider);
  return repository.watchVaultItems(coupleId);
});
