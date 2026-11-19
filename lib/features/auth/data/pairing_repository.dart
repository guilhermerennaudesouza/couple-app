import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/notifications/local_notification_service.dart';
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

  String? get currentUserUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static String generateInviteCode() {
    final random = Random.secure();
    final code = 100000 + random.nextInt(900000);
    return code.toString();
  }

  /// Extracts a 6-digit invite code from either a QR URI (`coupleapp://join?code=123456`)
  /// or a raw 6-digit string. Returns `null` if invalid.
  static String? parseInviteCodeFromQr(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return trimmed;
    }
    final uri = Uri.tryParse(trimmed);
    final codeParam = uri?.queryParameters['code']?.trim();
    if (codeParam != null && RegExp(r'^\d{6}$').hasMatch(codeParam)) {
      return codeParam;
    }
    return null;
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

    final docRef = querySnapshot.docs.first.reference;
    String? migratedOldUid;

    final updatedCouple = await _firestore.runTransaction<CoupleModel>((tx) async {
      final freshSnap = await tx.get(docRef);
      if (!freshSnap.exists || freshSnap.data() == null) {
        throw const PairingException(
          'No couple space found with this invite code. Please verify and try again.',
        );
      }
      final couple = CoupleModel.fromMap(freshSnap.id, freshSnap.data()!);

      // Already a member
      if (couple.members.contains(uid)) {
        return couple;
      }

      // Space already has 2 members: allow seamless re-join if partner name matches
      if (couple.isFull) {
        final normalizedName = name.trim().toLowerCase();
        String? matchingOldUid;
        for (final memberUid in couple.members) {
          final existingProfile = couple.partnerProfiles[memberUid];
          if (existingProfile != null &&
              existingProfile.name.trim().toLowerCase() == normalizedName) {
            matchingOldUid = memberUid;
            break;
          }
        }

        if (matchingOldUid == null) {
          throw const PairingException(
            'This couple space is already full with 2 partners.',
          );
        }

        migratedOldUid = matchingOldUid;
        final oldProfile = couple.partnerProfiles[matchingOldUid];
        final rejoiningProfile = PartnerProfile(
          uid: uid,
          name: oldProfile?.name ?? name.trim(),
          avatarUrl: avatarUrl ?? oldProfile?.avatarUrl,
          fcmToken: fcmToken ?? oldProfile?.fcmToken,
          joinedAt: oldProfile?.joinedAt ?? DateTime.now(),
        );

        final updatedMembers = couple.members
            .map((m) => m == matchingOldUid ? uid : m)
            .toList();
        final updatedProfiles =
            Map<String, PartnerProfile>.from(couple.partnerProfiles)
              ..remove(matchingOldUid)
              ..[uid] = rejoiningProfile;
        final updatedAliases = Map<String, String>.from(couple.uidAliases)
          ..[matchingOldUid] = uid;

        final nextCouple = couple.copyWith(
          members: updatedMembers,
          partnerProfiles: updatedProfiles,
          uidAliases: updatedAliases,
        );

        tx.set(docRef, nextCouple.toMap());
        return nextCouple;
      }

      final newProfile = PartnerProfile(
        uid: uid,
        name: name,
        avatarUrl: avatarUrl,
        fcmToken: fcmToken,
        joinedAt: DateTime.now(),
      );

      final updatedMembers = [...couple.members, uid];
      final updatedProfiles =
          Map<String, PartnerProfile>.from(couple.partnerProfiles)
            ..[uid] = newProfile;

      final nextCouple = couple.copyWith(
        members: updatedMembers,
        partnerProfiles: updatedProfiles,
      );

      tx.set(docRef, nextCouple.toMap(), SetOptions(merge: true));
      return nextCouple;
    });

    await _storage.write(key: currentCoupleIdKey, value: updatedCouple.id);

    if (migratedOldUid != null && migratedOldUid != uid) {
      await migratePartnerUid(
        updatedCouple.id,
        oldUid: migratedOldUid!,
        newUid: uid,
      );
    }

    return updatedCouple;
  }

  /// Idempotently migrates historical subcollection references from [oldUid] to
  /// [newUid] after a partner reinstalls and rejoins the couple space.
  Future<void> migratePartnerUid(
    String coupleId, {
    required String oldUid,
    required String newUid,
  }) async {
    if (oldUid.isEmpty || newUid.isEmpty || oldUid == newUid) return;
    final coupleRef = _firestore.collection(couplesCollection).doc(coupleId);

    try {
      // 1. Daily Questions (move answers[oldUid] -> answers[newUid])
      final dqSnap = await coupleRef.collection('daily_questions').get();
      var batch = _firestore.batch();
      int opCount = 0;

      Future<void> flushIfFull() async {
        if (opCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          opCount = 0;
        }
      }

      for (final doc in dqSnap.docs) {
        final data = doc.data();
        final answers = data['answers'];
        if (answers is Map && answers.containsKey(oldUid)) {
          final updatedAnswers = Map<String, dynamic>.from(answers);
          final rawAns = updatedAnswers.remove(oldUid);
          if (rawAns is Map) {
            final ansMap = Map<String, dynamic>.from(rawAns)..['uid'] = newUid;
            updatedAnswers[newUid] = ansMap;
          } else {
            updatedAnswers[newUid] = rawAns;
          }
          batch.update(doc.reference, {'answers': updatedAnswers});
          opCount++;
          await flushIfFull();
        }
      }

      // 2. Tasks (assignedTo)
      final tasksSnap = await coupleRef
          .collection('tasks')
          .where('assignedTo', isEqualTo: oldUid)
          .get();
      for (final doc in tasksSnap.docs) {
        batch.update(doc.reference, {'assignedTo': newUid});
        opCount++;
        await flushIfFull();
      }

      // 3. Finance entries (paidByUid & customShares)
      final finSnap = await coupleRef.collection('finance_entries').get();
      for (final doc in finSnap.docs) {
        final data = doc.data();
        final updates = <String, dynamic>{};
        if (data['paidByUid'] == oldUid) {
          updates['paidByUid'] = newUid;
        }
        final customShares = data['customShares'];
        if (customShares is Map && customShares.containsKey(oldUid)) {
          final nextShares = Map<String, dynamic>.from(customShares);
          nextShares[newUid] = nextShares.remove(oldUid);
          updates['customShares'] = nextShares;
        }
        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
          opCount++;
          await flushIfFull();
        }
      }

      // 4. Notes (authorUid)
      final notesSnap = await coupleRef
          .collection('notes')
          .where('authorUid', isEqualTo: oldUid)
          .get();
      for (final doc in notesSnap.docs) {
        batch.update(doc.reference, {'authorUid': newUid});
        opCount++;
        await flushIfFull();
      }

      // 5. Decide sessions (votes map)
      final decideSnap = await coupleRef.collection('decide_sessions').get();
      for (final doc in decideSnap.docs) {
        final votes = doc.data()['votes'];
        if (votes is Map && votes.containsKey(oldUid)) {
          final nextVotes = Map<String, dynamic>.from(votes);
          nextVotes[newUid] = nextVotes.remove(oldUid);
          batch.update(doc.reference, {'votes': nextVotes});
          opCount++;
          await flushIfFull();
        }
      }

      // 6. Wishlist (createdBy & purchasedBy)
      final wishSnap = await coupleRef.collection('wishlist').get();
      for (final doc in wishSnap.docs) {
        final data = doc.data();
        final updates = <String, dynamic>{};
        if (data['createdBy'] == oldUid) updates['createdBy'] = newUid;
        if (data['purchasedBy'] == oldUid) updates['purchasedBy'] = newUid;
        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
          opCount++;
          await flushIfFull();
        }
      }

      // 7. Partner cheatsheet doc ID migration
      final oldCheatRef =
          coupleRef.collection('partner_cheatsheet').doc(oldUid);
      final oldCheatSnap = await oldCheatRef.get();
      if (oldCheatSnap.exists && oldCheatSnap.data() != null) {
        final nextData = Map<String, dynamic>.from(oldCheatSnap.data()!)
          ..['uid'] = newUid;
        batch.set(
          coupleRef.collection('partner_cheatsheet').doc(newUid),
          nextData,
          SetOptions(merge: true),
        );
        batch.delete(oldCheatRef);
        opCount += 2;
      }

      if (opCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('PairingRepository.migratePartnerUid warning: $e');
    }
  }

  /// Unpairs the current device cleanly: removes [uid] from Firestore members
  /// (best-effort when online), cancels couple notifications, and clears local storage.
  Future<void> unpairCurrentUser(String coupleId, String? uid) async {
    if (coupleId.isNotEmpty && uid != null && uid.isNotEmpty) {
      try {
        await _firestore.collection(couplesCollection).doc(coupleId).update({
          'members': FieldValue.arrayRemove([uid]),
        });
      } catch (e) {
        debugPrint('PairingRepository.unpairCurrentUser remote warning: $e');
      }
    }
    await LocalNotificationService.cancelAll();
    await clearCurrentCoupleId();
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

/// Canonical authenticated Firebase user UID stream, resilient to uninitialized
/// Firebase instances in headless unit test environments.
final currentUserUidProvider = StreamProvider<String?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
  } catch (_) {
    return Stream<String?>.value(null);
  }
});

final currentCoupleIdProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(pairingRepositoryProvider);
  return repo.getCurrentCoupleId();
});

final coupleStreamProvider = StreamProvider.family<CoupleModel?, String>((ref, coupleId) {
  final repo = ref.watch(pairingRepositoryProvider);
  return repo.watchCouple(coupleId);
});
