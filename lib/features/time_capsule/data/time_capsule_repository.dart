import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/time_capsule_model.dart';

/// Repository managing digital time capsules with offline-first Firestore synchronization.
///
/// Persisted under:
/// `/couples/{coupleId}/time_capsules/{capsuleId}`
class TimeCapsuleRepository {
  final FirebaseFirestore _firestore;

  TimeCapsuleRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _capsulesCollection(String coupleId) {
    return _firestore.collection('couples').doc(coupleId).collection('time_capsules');
  }

  /// Watches all time capsules for a couple in real time.
  ///
  /// Ordered by [unlockDate] ascending (soonest unlocking capsules first).
  Stream<List<TimeCapsuleModel>> watchCapsules(String coupleId) {
    return _capsulesCollection(coupleId).snapshots().map((snapshot) {
      final capsules = snapshot.docs
          .map((doc) => TimeCapsuleModel.fromMap(doc.id, doc.data()))
          .toList();

      capsules.sort((a, b) {
        // Soonest unlock date first
        return a.unlockDate.compareTo(b.unlockDate);
      });

      return capsules;
    });
  }

  /// Seals a new or updated time capsule with offline merge durability.
  Future<void> sealCapsule(String coupleId, TimeCapsuleModel capsule) async {
    final col = _capsulesCollection(coupleId);
    final docRef = capsule.id.isEmpty ? col.doc() : col.doc(capsule.id);
    final capsuleToSave =
        capsule.id.isEmpty ? capsule.copyWith(id: docRef.id) : capsule;

    await docRef.set(capsuleToSave.toMap(), SetOptions(merge: true));
  }

  /// Marks a time capsule as opened, recording the time it was unsealed.
  Future<void> openCapsule(
    String coupleId,
    String capsuleId, {
    DateTime? openedAt,
  }) async {
    final docRef = _capsulesCollection(coupleId).doc(capsuleId);
    final timestamp = openedAt ?? DateTime.now();

    await docRef.set(
      {
        'isOpened': true,
        'openedAt': timestamp.toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Deletes a time capsule document.
  Future<void> deleteCapsule(String coupleId, String capsuleId) async {
    await _capsulesCollection(coupleId).doc(capsuleId).delete();
  }
}

// ==========================================
// Riverpod Providers
// ==========================================

final timeCapsuleRepositoryProvider = Provider<TimeCapsuleRepository>((ref) {
  return TimeCapsuleRepository();
});

final timeCapsulesStreamProvider =
    StreamProvider.family<List<TimeCapsuleModel>, String>((ref, coupleId) {
  final repo = ref.watch(timeCapsuleRepositoryProvider);
  return repo.watchCapsules(coupleId);
});
