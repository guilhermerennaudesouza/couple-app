import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/memory_model.dart';
import '../../wishlist/domain/wish_model.dart';

/// Repository managing shared memories album and wishlist with offline-first
/// Firestore durability and Firebase Storage photo uploads.
///
/// Persisted under:
/// - `/couples/{coupleId}/memories/{memoryId}`
/// - `/couples/{coupleId}/wishlist/{wishId}`
/// - Storage: `/couples/{coupleId}/photos/{filename}`
class MemoriesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  MemoriesRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _memoriesCollection(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).collection('memories');
  }

  CollectionReference<Map<String, dynamic>> _wishlistCollection(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).collection('wishlist');
  }

  Reference _photosStorageRef(String coupleId, String filename) {
    return _storage.ref().child('couples').child(coupleId).child('photos').child(filename);
  }

  // ==========================================
  // Memories Timeline Methods
  // ==========================================

  /// Watches all shared memories for a couple in real time.
  ///
  /// Ordered by memory [date] descending (most recent memories first).
  Stream<List<MemoryModel>> watchMemories(String coupleId) {
    return _memoriesCollection(coupleId).snapshots().map((snapshot) {
      final memories = snapshot.docs
          .map((doc) => MemoryModel.fromMap(doc.id, doc.data()))
          .toList();

      memories.sort((a, b) {
        final dateComparison = b.date.compareTo(a.date);
        if (dateComparison != 0) return dateComparison;
        return b.createdAt.compareTo(a.createdAt);
      });

      return memories;
    });
  }

  /// Adds a new memory to the couple's shared timeline with offline merge durability.
  Future<void> addMemory(String coupleId, MemoryModel memory) async {
    final col = _memoriesCollection(coupleId);
    final docRef = memory.id.isEmpty ? col.doc() : col.doc(memory.id);
    final memoryToSave = memory.id.isEmpty ? memory.copyWith(id: docRef.id) : memory;

    await docRef.set(memoryToSave.toMap(), SetOptions(merge: true));
  }

  /// Updates an existing memory with offline merge durability.
  Future<void> updateMemory(String coupleId, MemoryModel memory) async {
    final docRef = _memoriesCollection(coupleId).doc(memory.id);
    await docRef.set(memory.toMap(), SetOptions(merge: true));
  }

  /// Deletes a memory from the couple's timeline.
  Future<void> deleteMemory(String coupleId, String memoryId) async {
    await _memoriesCollection(coupleId).doc(memoryId).delete();
  }

  /// Uploads photo bytes to Firebase Storage if available, or seamlessly returns
  /// a Base64 Data URI on the free Spark tier (zero cloud storage cost).
  Future<String> uploadPhoto(
    String coupleId,
    Uint8List bytes,
    String filename, {
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final photoRef = _photosStorageRef(coupleId, filename);
      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'coupleId': coupleId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      await photoRef.putData(bytes, metadata);
      return await photoRef.getDownloadURL();
    } catch (_) {
      // Free Spark Tier Fallback: encode as Base64 Data URI for direct Firestore storage
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }
  }

  // ==========================================
  // Shared Wishlist Methods
  // ==========================================

  /// Watches all items on the couple's shared wishlist.
  ///
  /// Ordered with unpurchased items first (`isPurchased` ascending),
  /// followed by newest additions first (`createdAt` descending).
  Stream<List<WishModel>> watchWishlist(String coupleId) {
    return _wishlistCollection(coupleId).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => WishModel.fromMap(doc.id, doc.data()))
          .toList();

      items.sort((a, b) {
        if (a.isPurchased != b.isPurchased) {
          return a.isPurchased ? 1 : -1; // false (unpurchased) first
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      return items;
    });
  }

  /// Adds an item to the couple's shared wishlist with offline merge durability.
  Future<void> addWish(String coupleId, WishModel wish) async {
    final col = _wishlistCollection(coupleId);
    final docRef = wish.id.isEmpty ? col.doc() : col.doc(wish.id);
    final wishToSave = wish.id.isEmpty ? wish.copyWith(id: docRef.id) : wish;

    await docRef.set(wishToSave.toMap(), SetOptions(merge: true));
  }

  /// Updates an existing wish with offline merge durability.
  Future<void> updateWish(String coupleId, WishModel wish) async {
    final docRef = _wishlistCollection(coupleId).doc(wish.id);
    await docRef.set(wish.toMap(), SetOptions(merge: true));
  }

  /// Toggles whether a wish item is marked as purchased.
  Future<void> toggleWishPurchased(
    String coupleId,
    String wishId,
    bool isPurchased, {
    String? purchasedBy,
  }) async {
    final docRef = _wishlistCollection(coupleId).doc(wishId);
    await docRef.set(
      {
        'isPurchased': isPurchased,
        'purchasedBy': isPurchased ? purchasedBy : null,
      },
      SetOptions(merge: true),
    );
  }

  /// Deletes an item from the shared wishlist.
  Future<void> deleteWish(String coupleId, String wishId) async {
    await _wishlistCollection(coupleId).doc(wishId).delete();
  }
}

// ==========================================
// Riverpod Providers
// ==========================================

final memoriesRepositoryProvider = Provider<MemoriesRepository>((ref) {
  return MemoriesRepository();
});

final memoriesStreamProvider =
    StreamProvider.family<List<MemoryModel>, String>((ref, coupleId) {
  final repo = ref.watch(memoriesRepositoryProvider);
  return repo.watchMemories(coupleId);
});

final wishlistStreamProvider =
    StreamProvider.family<List<WishModel>, String>((ref, coupleId) {
  final repo = ref.watch(memoriesRepositoryProvider);
  return repo.watchWishlist(coupleId);
});
