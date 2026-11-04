import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/couple_model.dart';
import '../domain/partner_profile.dart';

class PairingException implements Exception {
  final String message;
  const PairingException(this.message);

  @override
  String toString() => message;
}

class PairingRepository {
  static const String currentCoupleIdKey = 'current_couple_id';
  static const String couplesCollection = 'couples';

  final FirebaseFirestore _firestore;
  final FlutterSecureStorage _storage;

  PairingRepository({
    FirebaseFirestore? firestore,
    FlutterSecureStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? const FlutterSecureStorage();

  static String generateInviteCode() {
    final random = Random();
    final code = 100000 + random.nextInt(900000);
    return code.toString();
  }

  Future<CoupleModel> createCouple(
    String uid,
    String name,
    DateTime anniversary, {
    String? avatarUrl,
    String? fcmToken,
  }) async {
    final docRef = _firestore.collection(couplesCollection).doc();
    final inviteCode = generateInviteCode();

    final profile = PartnerProfile(
      uid: uid,
      name: name,
      avatarUrl: avatarUrl,
      fcmToken: fcmToken,
      joinedAt: DateTime.now(),
    );

    final couple = CoupleModel(
      id: docRef.id,
      members: [uid],
      anniversaryDate: anniversary,
      inviteCode: inviteCode,
      partnerProfiles: {uid: profile},
      createdAt: DateTime.now(),
    );

    await docRef.set(couple.toMap());
    await _storage.write(key: currentCoupleIdKey, value: couple.id);

    return couple;
  }

  Future<CoupleModel> joinCouple(
    String inviteCode,
    String uid,
    String name, {
    String? avatarUrl,
    String? fcmToken,
  }) async {
    final cleanCode = inviteCode.trim();
    if (cleanCode.length != 6) {
      throw const PairingException('Invite code must be 6 digits.');
    }

    final querySnapshot = await _firestore
        .collection(couplesCollection)
        .where('inviteCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw const PairingException(
        'No couple space found with this invite code. Please verify and try again.',
      );
    }

    final doc = querySnapshot.docs.first;
    final couple = CoupleModel.fromMap(doc.id, doc.data());

    // Already a member
    if (couple.members.contains(uid)) {
      await _storage.write(key: currentCoupleIdKey, value: couple.id);
      return couple;
    }

    // Space already has 2 members
    if (couple.isFull) {
      throw const PairingException(
        'This couple space is already full with 2 partners.',
      );
    }

    final newProfile = PartnerProfile(
      uid: uid,
      name: name,
      avatarUrl: avatarUrl,
      fcmToken: fcmToken,
      joinedAt: DateTime.now(),
    );

    final updatedMembers = [...couple.members, uid];
    final updatedProfiles = Map<String, PartnerProfile>.from(couple.partnerProfiles)
      ..[uid] = newProfile;

    final updatedCouple = couple.copyWith(
      members: updatedMembers,
      partnerProfiles: updatedProfiles,
    );

    await doc.reference.set(
      updatedCouple.toMap(),
      SetOptions(merge: true),
    );

    await _storage.write(key: currentCoupleIdKey, value: couple.id);

    return updatedCouple;
  }

  Stream<CoupleModel?> watchCouple(String coupleId) {
    return _firestore
        .collection(couplesCollection)
        .doc(coupleId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return CoupleModel.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  Future<CoupleModel?> getCouple(String coupleId) async {
    final doc = await _firestore.collection(couplesCollection).doc(coupleId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return CoupleModel.fromMap(doc.id, doc.data()!);
  }

  Future<String?> getCurrentCoupleId() async {
    return await _storage.read(key: currentCoupleIdKey);
  }

  Future<void> saveCurrentCoupleId(String coupleId) async {
    await _storage.write(key: currentCoupleIdKey, value: coupleId);
  }

  Future<void> clearCurrentCoupleId() async {
    await _storage.delete(key: currentCoupleIdKey);
  }
}

final pairingRepositoryProvider = Provider<PairingRepository>((ref) {
  return PairingRepository();
});

final currentCoupleIdProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(pairingRepositoryProvider);
  return repo.getCurrentCoupleId();
});

final coupleStreamProvider = StreamProvider.family<CoupleModel?, String>((ref, coupleId) {
  final repo = ref.watch(pairingRepositoryProvider);
  return repo.watchCouple(coupleId);
});
