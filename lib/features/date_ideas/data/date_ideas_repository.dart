import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/date_idea_model.dart';

/// Repository managing shared bucket list ideas, date nights, and weekly picks.
///
/// Persisted under Cloud Firestore collection:
/// `/couples/{coupleId}/date_ideas/{ideaId}`
class DateIdeasRepository {
  final FirebaseFirestore _firestore;

  DateIdeasRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ideasCollection(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('date_ideas');
  }

  /// Curated default date ideas inspired by Krivo couple cards.
  static List<DateIdeaModel> defaultCuratedIdeas({required String createdBy}) {
    final now = DateTime.now();
    return [
      DateIdeaModel(
        id: 'curated_1',
        title: 'Candlelight Home Dinner & No Phones',
        description: 'Turn off all screens, cook a favorite meal together, and dine by candlelight.',
        category: DateIdeaModel.categoryCozy,
        isWeeklyPick: true,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 6)),
      ),
      DateIdeaModel(
        id: 'curated_2',
        title: 'Sunset Beach Walk & Ice Cream',
        description: 'Catch the golden hour by the water followed by your favorite scoops.',
        category: DateIdeaModel.categoryOutdoor,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      DateIdeaModel(
        id: 'curated_3',
        title: 'Try a New Cuisine Neither Has Eaten',
        description: 'Pick an exotic cultural cuisine neither of you has tried before and order adventurous dishes.',
        category: DateIdeaModel.categoryFoodie,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 4)),
      ),
      DateIdeaModel(
        id: 'curated_4',
        title: 'Late Night Stargazing with Hot Chocolate',
        description: 'Pack a warm blanket, a thermos of rich cocoa, and find an open dark spot under the stars.',
        category: DateIdeaModel.categoryRomance,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 3)),
      ),
      DateIdeaModel(
        id: 'curated_5',
        title: 'Cook Pizza from Scratch Together',
        description: 'Roll the dough, experiment with funny topping combinations, and bake fresh.',
        category: DateIdeaModel.categoryFoodie,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
      DateIdeaModel(
        id: 'curated_6',
        title: 'Bookstore Date: Pick a Book for Each Other',
        description: 'Browse local bookstore aisles for 30 minutes and swap secret choices over coffee.',
        category: DateIdeaModel.categoryCozy,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 1)),
      ),
    ];
  }

  /// Watches all date ideas for a couple in real time.
  ///
  /// Sorted by weekly pick first, followed by incomplete ideas first,
  /// then chronologically.
  Stream<List<DateIdeaModel>> watchIdeas(String coupleId) {
    return _ideasCollection(coupleId).snapshots().map((snapshot) {
      final ideas = snapshot.docs
          .map((doc) => DateIdeaModel.fromMap(doc.id, doc.data()))
          .toList();

      ideas.sort((a, b) {
        // 1. Weekly pick at the very top
        if (a.isWeeklyPick != b.isWeeklyPick) {
          return a.isWeeklyPick ? -1 : 1;
        }

        // 2. Incomplete ideas before completed ideas
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }

        // 3. Newest created first
        return b.createdAt.compareTo(a.createdAt);
      });

      return ideas;
    });
  }

  /// Seeds default curated ideas if the couple's date ideas collection is currently empty.
  Future<void> seedDefaultIdeasIfEmpty(
    String coupleId, {
    String createdBy = 'system',
  }) async {
    try {
      final col = _ideasCollection(coupleId);
      final snapshot = await col.limit(1).get();

      if (snapshot.docs.isEmpty) {
        final defaults = defaultCuratedIdeas(createdBy: createdBy);
        final batch = _firestore.batch();
        for (final idea in defaults) {
          final docRef = col.doc(idea.id);
          batch.set(docRef, idea.toMap(), SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('DateIdeasRepository.seedDefaultIdeasIfEmpty error: $e');
    }
  }

  /// Adds or updates a date idea.
  Future<void> addIdea(String coupleId, DateIdeaModel idea) async {
    final col = _ideasCollection(coupleId);
    final docRef = idea.id.isEmpty ? col.doc() : col.doc(idea.id);
    final toSave = idea.id.isEmpty ? idea.copyWith(id: docRef.id) : idea;

    try {
      if (toSave.isWeeklyPick) {
        try {
          await _clearOtherWeeklyPicks(coupleId, exceptId: toSave.id);
        } catch (e) {
          debugPrint('DateIdeasRepository.addIdea clear others fallback: $e');
        }
      }
      await docRef.set(toSave.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('DateIdeasRepository.addIdea error: $e');
      rethrow;
    }
  }

  /// Toggles completion status of a date idea.
  Future<void> toggleIdeaCompleted(
    String coupleId,
    String ideaId,
    bool isCompleted,
  ) async {
    final docRef = _ideasCollection(coupleId).doc(ideaId);
    try {
      await docRef.set(
        {
          'isCompleted': isCompleted,
          'completedAt': isCompleted ? DateTime.now().toIso8601String() : null,
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('DateIdeasRepository.toggleIdeaCompleted error: $e');
      rethrow;
    }
  }

  /// Designates an idea as the featured weekly pick, clearing previous weekly picks.
  Future<void> setWeeklyPick(String coupleId, String ideaId) async {
    try {
      try {
        await _clearOtherWeeklyPicks(coupleId, exceptId: ideaId);
      } catch (e) {
        debugPrint('DateIdeasRepository.setWeeklyPick clearing others fallback: $e');
      }
      final docRef = _ideasCollection(coupleId).doc(ideaId);
      await docRef.set({'isWeeklyPick': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DateIdeasRepository.setWeeklyPick error: $e');
      rethrow;
    }
  }

  /// Unsets an idea as the weekly pick.
  Future<void> unsetWeeklyPick(String coupleId, String ideaId) async {
    final docRef = _ideasCollection(coupleId).doc(ideaId);
    try {
      await docRef.set({'isWeeklyPick': false}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('DateIdeasRepository.unsetWeeklyPick error: $e');
      rethrow;
    }
  }

  /// Deletes a date idea.
  Future<void> deleteIdea(String coupleId, String ideaId) async {
    final docRef = _ideasCollection(coupleId).doc(ideaId);
    try {
      await docRef.delete();
    } catch (e) {
      debugPrint('DateIdeasRepository.deleteIdea error: $e');
      rethrow;
    }
  }

  Future<void> _clearOtherWeeklyPicks(String coupleId, {String? exceptId}) async {
    final col = _ideasCollection(coupleId);
    final snapshot = await col.where('isWeeklyPick', isEqualTo: true).get();
    final batch = _firestore.batch();
    bool needsCommit = false;

    for (final doc in snapshot.docs) {
      if (doc.id != exceptId) {
        batch.set(doc.reference, {'isWeeklyPick': false}, SetOptions(merge: true));
        needsCommit = true;
      }
    }

    if (needsCommit) {
      await batch.commit();
    }
  }
}

/// Riverpod provider for [DateIdeasRepository].
final dateIdeasRepositoryProvider = Provider<DateIdeasRepository>((ref) {
  return DateIdeasRepository();
});

/// Stream provider for all shared date ideas belonging to a couple.
final dateIdeasStreamProvider =
    StreamProvider.family<List<DateIdeaModel>, String>((ref, coupleId) {
  final repository = ref.watch(dateIdeasRepositoryProvider);
  return repository.watchIdeas(coupleId);
});
