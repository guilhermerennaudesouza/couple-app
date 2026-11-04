import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/cheatsheet_model.dart';

/// Repository managing partner preferences and sizing cheatsheets with Cloud Firestore.
///
/// Persisted under:
/// `/couples/{coupleId}/partner_cheatsheet/{uid}`
class CheatsheetRepository {
  final FirebaseFirestore _firestore;

  CheatsheetRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _cheatsheetDoc(
    String coupleId,
    String uid,
  ) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('partner_cheatsheet')
        .doc(uid);
  }

  /// Watches a partner's cheatsheet in real time.
  Stream<PartnerCheatsheetModel?> watchCheatsheet(
    String coupleId,
    String uid,
  ) {
    return _cheatsheetDoc(coupleId, uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return PartnerCheatsheetModel.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  /// Fetches a partner's cheatsheet once with offline fallback.
  Future<PartnerCheatsheetModel?> getCheatsheet(
    String coupleId,
    String uid,
  ) async {
    try {
      final doc = await _cheatsheetDoc(coupleId, uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return PartnerCheatsheetModel.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('CheatsheetRepository.getCheatsheet error: $e');
      try {
        final cacheDoc = await _cheatsheetDoc(coupleId, uid)
            .get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists && cacheDoc.data() != null) {
          return PartnerCheatsheetModel.fromMap(cacheDoc.id, cacheDoc.data()!);
        }
      } catch (_) {}
      return null;
    }
  }

  /// Saves or updates a partner cheatsheet using merge durability.
  Future<void> saveCheatsheet(
    String coupleId,
    PartnerCheatsheetModel cheatsheet,
  ) async {
    final docRef = _cheatsheetDoc(coupleId, cheatsheet.uid);
    try {
      await docRef.set(cheatsheet.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('CheatsheetRepository.saveCheatsheet error: $e');
      rethrow;
    }
  }
}

/// Riverpod provider for [CheatsheetRepository].
final cheatsheetRepositoryProvider = Provider<CheatsheetRepository>((ref) {
  return CheatsheetRepository();
});

/// Target identifier record for querying a cheatsheet by coupleId and uid.
typedef CheatsheetTarget = ({
  String coupleId,
  String uid,
});

/// Stream provider for a partner's cheatsheet.
final partnerCheatsheetStreamProvider = StreamProvider.family<
    PartnerCheatsheetModel?,
    CheatsheetTarget>((ref, target) {
  final repo = ref.watch(cheatsheetRepositoryProvider);
  return repo.watchCheatsheet(target.coupleId, target.uid);
});
