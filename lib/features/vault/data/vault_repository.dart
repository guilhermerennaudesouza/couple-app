import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/vault_item_model.dart';

/// Repository managing encrypted private vault items with Cloud Firestore synchronization.
///
/// Persisted under:
/// `/couples/{coupleId}/vault_items/{itemId}`
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
