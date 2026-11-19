import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'curated_date_ideas_catalog.dart';
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

  /// Bilingual dictionary of curated date ideas for seamless localization.
  static const Map<String, Map<String, String>> _curatedTranslations = {
    'Candlelight Home Dinner & No Phones': {
      'titlePt': 'Jantar à Luz de Velas em Casa & Sem Celulares',
      'descPt': 'Desliguem todas as telas, cozinhem um prato especial juntos e jantem à luz de velas.',
    },
    'Sunset Beach Walk & Ice Cream': {
      'titlePt': 'Caminhada ao Pôr do Sol & Sorvete',
      'descPt': 'Aproveitem a hora de ouro na beira da água seguidos por um sorvete delicioso.',
    },
    'Try a New Cuisine Neither Has Eaten': {
      'titlePt': 'Provar uma Culinária Nova Juntos',
      'descPt': 'Escolham um restaurante de culinária que nenhum dos dois provou antes e façam pedidos aventureiros.',
    },
    'Late Night Stargazing with Hot Chocolate': {
      'titlePt': 'Observar as Estrelas com Chocolate Quente',
      'descPt': 'Levem uma manta macia, uma garrafa térmica com chocolate quente cremoso e contemplem as estrelas.',
    },
    'Cook Pizza from Scratch Together': {
      'titlePt': 'Fazer Pizza Caseira Juntos do Zero',
      'descPt': 'Abram a massa juntos, testem combinações divertidas de sabores e assem quentinha no forno.',
    },
    'Bookstore Date: Pick a Book for Each Other': {
      'titlePt': 'Encontro na Livraria: Escolher um Livro para o Outro',
      'descPt': 'Passeiem pelos corredores da livraria por 30 minutos e troquem escolhas secretas com um café.',
    },
  };

  /// Translates a curated idea title between languages.
  static String translateIdeaTitle(String title, {String languageCode = 'pt'}) {
    if (languageCode == 'pt') {
      return _curatedTranslations[title]?['titlePt'] ?? title;
    }
    for (final entry in _curatedTranslations.entries) {
      if (entry.value['titlePt'] == title) {
        return entry.key;
      }
    }
    return title;
  }

  /// Translates a curated idea description to Portuguese if matched.
  static String translateIdeaDescription(
    String title,
    String description, {
    String languageCode = 'pt',
  }) {
    if (languageCode == 'pt') {
      return _curatedTranslations[title]?['descPt'] ?? description;
    }
    return description;
  }

  /// Curated default date ideas inspired by Krivo couple cards.
  static List<DateIdeaModel> defaultCuratedIdeas({
    required String createdBy,
    String languageCode = 'pt',
  }) {
    final now = DateTime.now();
    final isPt = languageCode == 'pt';

    return [
      DateIdeaModel(
        id: 'curated_1',
        title: isPt
            ? 'Jantar à Luz de Velas em Casa & Sem Celulares'
            : 'Candlelight Home Dinner & No Phones',
        description: isPt
            ? 'Desliguem todas as telas, cozinhem um prato especial juntos e jantem à luz de velas.'
            : 'Turn off all screens, cook a favorite meal together, and dine by candlelight.',
        category: DateIdeaModel.categoryCozy,
        isWeeklyPick: true,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 6)),
      ),
      DateIdeaModel(
        id: 'curated_2',
        title: isPt
            ? 'Caminhada ao Pôr do Sol & Sorvete'
            : 'Sunset Beach Walk & Ice Cream',
        description: isPt
            ? 'Aproveitem a hora de ouro na beira da água seguidos por um sorvete delicioso.'
            : 'Catch the golden hour by the water followed by your favorite scoops.',
        category: DateIdeaModel.categoryOutdoor,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      DateIdeaModel(
        id: 'curated_3',
        title: isPt
            ? 'Provar uma Culinária Nova Juntos'
            : 'Try a New Cuisine Neither Has Eaten',
        description: isPt
            ? 'Escolham um restaurante de culinária que nenhum dos dois provou antes e façam pedidos aventureiros.'
            : 'Pick an exotic cultural cuisine neither of you has tried before and order adventurous dishes.',
        category: DateIdeaModel.categoryFoodie,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 4)),
      ),
      DateIdeaModel(
        id: 'curated_4',
        title: isPt
            ? 'Observar as Estrelas com Chocolate Quente'
            : 'Late Night Stargazing with Hot Chocolate',
        description: isPt
            ? 'Levem uma manta macia, uma garrafa térmica com chocolate quente cremoso e contemplem as estrelas.'
            : 'Pack a warm blanket, a thermos of rich cocoa, and find an open dark spot under the stars.',
        category: DateIdeaModel.categoryRomance,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 3)),
      ),
      DateIdeaModel(
        id: 'curated_5',
        title: isPt
            ? 'Fazer Pizza Caseira Juntos do Zero'
            : 'Cook Pizza from Scratch Together',
        description: isPt
            ? 'Abram a massa juntos, testem combinações divertidas de sabores e assem quentinha no forno.'
            : 'Roll the dough, experiment with funny topping combinations, and bake fresh.',
        category: DateIdeaModel.categoryFoodie,
        createdBy: createdBy,
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
      DateIdeaModel(
        id: 'curated_6',
        title: isPt
            ? 'Encontro na Livraria: Escolher um Livro para o Outro'
            : 'Bookstore Date: Pick a Book for Each Other',
        description: isPt
            ? 'Passeiem pelos corredores da livraria por 30 minutos e troquem escolhas secretas com um café.'
            : 'Browse local bookstore aisles for 30 minutes and swap secret choices over coffee.',
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

  /// Builds the Swipe discovery deck by merging couple-stored ideas with the
  /// 40-item built-in PT-BR catalog (without writing untouched catalog items to
  /// Firestore). Cards already voted on by [myUid] or completed are excluded;
  /// cards the partner already liked bubble to the top to surface matches fast.
  static List<DateIdeaModel> buildSwipeDeck({
    required List<DateIdeaModel> coupleIdeas,
    required String myUid,
    String? categoryFilter,
  }) {
    final byId = <String, DateIdeaModel>{};
    for (final idea in coupleIdeas) {
      byId[idea.id] = idea;
    }
    for (final catIdea in kCuratedDateIdeasPtBr) {
      byId.putIfAbsent(catIdea.id, () => catIdea);
    }

    final candidates = byId.values.where((idea) {
      if (idea.isCompleted) return false;
      if (myUid.isNotEmpty && idea.userVote(myUid) != null) return false;
      if (categoryFilter != null &&
          categoryFilter.isNotEmpty &&
          categoryFilter != 'All' &&
          idea.category != categoryFilter) {
        return false;
      }
      return true;
    }).toList();

    // Prioritize cards where the other partner already voted 'like'
    candidates.sort((a, b) {
      final aPartnerLiked = a.votes.entries
          .any((e) => e.key != myUid && e.value == DateIdeaModel.voteLike);
      final bPartnerLiked = b.votes.entries
          .any((e) => e.key != myUid && e.value == DateIdeaModel.voteLike);
      if (aPartnerLiked != bPartnerLiked) {
        return aPartnerLiked ? -1 : 1;
      }
      final aCustom = a.createdBy != 'catalog';
      final bCustom = b.createdBy != 'catalog';
      if (aCustom != bCustom) {
        return aCustom ? -1 : 1;
      }
      return a.id.compareTo(b.id);
    });

    return candidates;
  }

  /// Records a swipe vote (`'like'` or `'pass'`) atomically inside a Firestore
  /// transaction (with offline cache fallback), persisting catalog cards on demand
  /// and returning `true` if this vote just created a new Match.
  Future<bool> recordSwipeVote(
    String coupleId,
    DateIdeaModel idea, {
    required String uid,
    required String vote,
  }) async {
    if (coupleId.trim().isEmpty || uid.trim().isEmpty) return false;
    final docRef = _ideasCollection(coupleId).doc(idea.id);
    final nowIso = DateTime.now().toIso8601String();

    try {
      return await _firestore.runTransaction<bool>((tx) async {
        final snap = await tx.get(docRef);
        final existing = snap.exists && snap.data() != null
            ? DateIdeaModel.fromMap(snap.id, snap.data()!)
            : idea;
        final wasMatched = existing.isMatched;

        final updatedVotes = Map<String, String>.from(existing.votes)
          ..[uid] = vote;
        final likeCount =
            updatedVotes.values.where((v) => v == DateIdeaModel.voteLike).length;
        final isNowMatched = likeCount >= 2;

        final payload = <String, dynamic>{
          'title': existing.title,
          'description': existing.description,
          'category': existing.category,
          'isCompleted': existing.isCompleted,
          'isWeeklyPick': existing.isWeeklyPick,
          'createdBy': existing.createdBy,
          'createdAt': existing.createdAt.toIso8601String(),
          'votes': updatedVotes,
          if (isNowMatched) 'matchedAt': existing.matchedAt?.toIso8601String() ?? nowIso,
        };
        tx.set(docRef, payload, SetOptions(merge: true));
        return !wasMatched && isNowMatched;
      });
    } catch (e) {
      debugPrint('DateIdeasRepository.recordSwipeVote offline fallback: $e');
      DateIdeaModel base = idea;
      try {
        final cachedSnap =
            await docRef.get(const GetOptions(source: Source.cache));
        if (cachedSnap.exists && cachedSnap.data() != null) {
          base = DateIdeaModel.fromMap(cachedSnap.id, cachedSnap.data()!);
        }
      } catch (_) {}
      final updatedVotes = Map<String, String>.from(base.votes)..[uid] = vote;
      final isNowMatched =
          updatedVotes.values.where((v) => v == DateIdeaModel.voteLike).length >= 2;
      await docRef.set(
        {
          ...base.toMap(),
          'votes': updatedVotes,
          if (isNowMatched)
            'matchedAt': base.matchedAt?.toIso8601String() ?? nowIso,
        },
        SetOptions(merge: true),
      );
      return !base.isMatched && isNowMatched;
    }
  }

  /// Excludes rejected catalog-origin ideas (swiped left with zero likes) from
  /// the couple's personal List view so swiping left never pollutes their list.
  static List<DateIdeaModel> filterIdeasForPersonalList(
    List<DateIdeaModel> ideas,
  ) {
    return ideas.where((idea) {
      if (idea.createdBy != 'catalog') return true;
      return idea.isMatched || idea.likeCount > 0;
    }).toList();
  }

  /// Clears all `'pass'` votes cast by [uid] so skipped ideas return to the Swipe deck.
  Future<int> resetPassedVotes(String coupleId, String uid) async {
    if (coupleId.trim().isEmpty || uid.trim().isEmpty) return 0;
    final snap = await _ideasCollection(coupleId).get();
    final batch = _firestore.batch();
    int count = 0;
    for (final doc in snap.docs) {
      final idea = DateIdeaModel.fromMap(doc.id, doc.data());
      if (idea.votes[uid] == DateIdeaModel.votePass) {
        batch.update(doc.reference, {'votes.$uid': FieldValue.delete()});
        count++;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
    return count;
  }

  /// Picks a random incomplete date idea, excluding rejected catalog cards and
  /// prioritizing matched ideas when [preferMatched] is true.
  static DateIdeaModel? pickRandomIdea(
    List<DateIdeaModel> ideas, {
    bool preferMatched = true,
    Random? random,
  }) {
    final eligible = filterIdeasForPersonalList(ideas)
        .where((i) => !i.isCompleted)
        .toList();
    if (eligible.isEmpty) return null;
    final rng = random ?? Random();
    if (preferMatched) {
      final matched = eligible.where((i) => i.isMatched).toList();
      if (matched.isNotEmpty) {
        return matched[rng.nextInt(matched.length)];
      }
    }
    return eligible[rng.nextInt(eligible.length)];
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
