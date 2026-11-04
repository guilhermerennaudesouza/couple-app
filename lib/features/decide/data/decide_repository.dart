import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/decide_model.dart';

/// Repository managing collaborative decision maker sessions ("This or That", dinner/movie ballots).
///
/// Persisted under Cloud Firestore collection:
/// `/couples/{coupleId}/decide_sessions/{sessionId}`
class DecideRepository {
  final FirebaseFirestore _firestore;

  DecideRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessionsCollection(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('decide_sessions');
  }

  /// Watches all decision sessions for a couple in real time.
  ///
  /// Open/active ballots appear first (ordered by newest creation),
  /// followed by resolved sessions (ordered by most recent resolution).
  Stream<List<DecideSessionModel>> watchActiveSessions(String coupleId) {
    return _sessionsCollection(coupleId).snapshots().map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => DecideSessionModel.fromMap(doc.id, doc.data()))
          .toList();

      sessions.sort((a, b) {
        // 1. Open ballots before resolved ballots
        if (a.isResolved != b.isResolved) {
          return a.isResolved ? 1 : -1;
        }

        // 2. If both are open, newest createdAt first
        if (!a.isResolved) {
          return b.createdAt.compareTo(a.createdAt);
        }

        // 3. If both are resolved, newest resolvedAt / createdAt first
        final aTime = a.resolvedAt ?? a.createdAt;
        final bTime = b.resolvedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      return sessions;
    });
  }

  /// Creates a new decision ballot.
  Future<void> createSession(
    String coupleId,
    DecideSessionModel session,
  ) async {
    final col = _sessionsCollection(coupleId);
    final docRef = session.id.isEmpty ? col.doc() : col.doc(session.id);
    final toSave = session.id.isEmpty ? session.copyWith(id: docRef.id) : session;

    try {
      await docRef.set(toSave.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('DecideRepository.createSession error: $e');
      rethrow;
    }
  }

  /// Casts a vote for a specific partner on an active ballot session.
  ///
  /// Merges `votes.$uid = choice`. If both partners have now voted,
  /// marks `status = 'resolved'` and records `resolvedAt`.
  Future<void> castVote(
    String coupleId,
    String sessionId,
    String uid,
    String choice,
  ) async {
    final docRef = _sessionsCollection(coupleId).doc(sessionId);

    try {
      final Map<String, dynamic> existingVotes = {};
      try {
        final doc = await docRef.get();
        if (doc.exists && doc.data() != null) {
          final rawVotes = doc.data()!['votes'];
          if (rawVotes is Map) {
            existingVotes.addAll(Map<String, dynamic>.from(rawVotes));
          }
          // Parse legacy root keys if any
          doc.data()!.forEach((k, v) {
            if (k.startsWith('votes.') && v != null) {
              final voteUid = k.substring('votes.'.length);
              if (voteUid.isNotEmpty && !existingVotes.containsKey(voteUid)) {
                existingVotes[voteUid] = v;
              }
            }
          });
        }
      } catch (e) {
        debugPrint('DecideRepository.castVote get fallback: $e');
      }
      existingVotes[uid] = choice;

      // Use nested map syntax so SetOptions(merge: true) merges the map key
      // without creating a literal 'votes.<uid>' string field.
      final updates = <String, dynamic>{
        'votes': {
          uid: choice,
        },
      };

      // When 2 or more partners have voted, mark resolved
      if (existingVotes.length >= 2) {
        updates['status'] = DecideSessionModel.statusResolved;
        final now = DateTime.now();
        updates['resolvedAt'] = now.toIso8601String();

        // Check if all votes agree
        final voteValues = existingVotes.values.toSet();
        if (voteValues.length == 1 && voteValues.first.toString().isNotEmpty) {
          updates['winningOption'] = voteValues.first.toString();
        }
      }

      await docRef.set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DecideRepository.castVote error: $e');
      rethrow;
    }
  }

  /// Resolves a ballot session with an explicit winning option (e.g. from coin toss).
  Future<void> resolveSession(
    String coupleId,
    String sessionId, {
    required String winningOption,
  }) async {
    final docRef = _sessionsCollection(coupleId).doc(sessionId);
    try {
      await docRef.set(
        {
          'status': DecideSessionModel.statusResolved,
          'resolvedAt': DateTime.now().toIso8601String(),
          'winningOption': winningOption,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('DecideRepository.resolveSession error: $e');
      rethrow;
    }
  }

  /// Resets a ballot session to allow a fresh re-vote in case of a split decision.
  Future<void> resetSessionForRevote(
    String coupleId,
    String sessionId,
  ) async {
    final docRef = _sessionsCollection(coupleId).doc(sessionId);
    try {
      await docRef.set(
        {
          'votes': <String, String>{},
          'status': DecideSessionModel.statusOpen,
          'resolvedAt': null,
          'winningOption': null,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('DecideRepository.resetSessionForRevote error: $e');
      rethrow;
    }
  }

  /// Deletes a decision session ballot.
  Future<void> deleteSession(String coupleId, String sessionId) async {
    final docRef = _sessionsCollection(coupleId).doc(sessionId);
    try {
      await docRef.delete();
    } catch (e) {
      debugPrint('DecideRepository.deleteSession error: $e');
      rethrow;
    }
  }
}

/// Riverpod provider for [DecideRepository].
final decideRepositoryProvider = Provider<DecideRepository>((ref) {
  return DecideRepository();
});

/// Stream provider for all active decision sessions belonging to a couple.
final decideSessionsStreamProvider =
    StreamProvider.family<List<DecideSessionModel>, String>((ref, coupleId) {
  final repository = ref.watch(decideRepositoryProvider);
  return repository.watchActiveSessions(coupleId);
});
