import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/date_ideas/data/curated_date_ideas_catalog.dart';
import 'package:couple_app/features/date_ideas/data/date_ideas_repository.dart';
import 'package:couple_app/features/date_ideas/domain/date_idea_model.dart';

void main() {
  group('Curated PT-BR Date Ideas Catalog', () {
    test('contains 40 unique curated PT-BR ideas across categories', () {
      expect(kCuratedDateIdeasPtBr.length, 40);
      final ids = kCuratedDateIdeasPtBr.map((e) => e.id).toSet();
      expect(ids.length, 40);
      for (final idea in kCuratedDateIdeasPtBr) {
        expect(idea.title.trim().isNotEmpty, isTrue);
        expect(idea.description.trim().isNotEmpty, isTrue);
        expect(DateIdeaModel.allCategories.contains(idea.category), isTrue);
      }
    });
  });

  group('DateIdeaModel votes & match backward compatibility', () {
    test('legacy map without votes/matchedAt defaults cleanly', () {
      final legacy = DateIdeaModel.fromMap('old_1', {
        'title': 'Cinema em casa',
        'description': 'Pipoca e cobertor',
        'category': DateIdeaModel.categoryCozy,
        'createdBy': 'u1',
      });
      expect(legacy.votes, isEmpty);
      expect(legacy.matchedAt, isNull);
      expect(legacy.isMatched, isFalse);
      expect(legacy.userVote('u1'), isNull);
    });

    test('isMatched becomes true when two distinct users vote like', () {
      final matched = DateIdeaModel(
        id: 'd1',
        title: 'Piquenique',
        createdBy: 'u1',
        votes: const {
          'u1': DateIdeaModel.voteLike,
          'u2': DateIdeaModel.voteLike,
        },
        matchedAt: DateTime(2026, 11, 19),
      );
      expect(matched.isMatched, isTrue);
      expect(matched.likeCount, 2);

      final halfLiked = matched.copyWith(
        votes: const {'u1': DateIdeaModel.voteLike, 'u2': DateIdeaModel.votePass},
        clearMatchedAt: true,
      );
      expect(halfLiked.isMatched, isFalse);
      expect(halfLiked.likeCount, 1);
    });
  });

  group('DateIdeasRepository swipe deck & random picker', () {
    test('buildSwipeDeck merges couple ideas with built-in catalog and hides cards already voted by myUid', () {
      final coupleIdeas = [
        DateIdeaModel(
          id: kCuratedDateIdeasPtBr.first.id,
          title: kCuratedDateIdeasPtBr.first.title,
          createdBy: 'u1',
          votes: const {'u1': DateIdeaModel.voteLike},
        ),
        DateIdeaModel(
          id: 'custom_1',
          title: 'Jantar no terraço',
          createdBy: 'u2',
          votes: const {'u2': DateIdeaModel.voteLike},
        ),
        DateIdeaModel(
          id: 'done_1',
          title: 'Já fizemos',
          createdBy: 'u1',
          isCompleted: true,
        ),
      ];

      final deck = DateIdeasRepository.buildSwipeDeck(
        coupleIdeas: coupleIdeas,
        myUid: 'u1',
      );

      // Should NOT include card already voted by u1 or completed card
      expect(deck.any((d) => d.id == kCuratedDateIdeasPtBr.first.id), isFalse);
      expect(deck.any((d) => d.id == 'done_1'), isFalse);
      // Partner-liked custom card should appear at the top to maximize match fun!
      expect(deck.first.id, 'custom_1');
      // Remaining 39 built-in curated ideas are present without polluting Firestore
      expect(deck.length, 40);
    });

    test('pickRandomIdea prioritizes incomplete matched ideas first, then incomplete ideas', () {
      final ideas = [
        DateIdeaModel(
          id: 'm1',
          title: 'Match 1',
          createdBy: 'u1',
          votes: const {'u1': 'like', 'u2': 'like'},
          matchedAt: DateTime(2026, 11, 19),
        ),
        DateIdeaModel(
          id: 'o1',
          title: 'Normal 1',
          createdBy: 'u1',
        ),
        DateIdeaModel(
          id: 'c1',
          title: 'Concluído',
          createdBy: 'u1',
          isCompleted: true,
          votes: const {'u1': 'like', 'u2': 'like'},
          matchedAt: DateTime(2026, 11, 18),
        ),
      ];

      final picked = DateIdeasRepository.pickRandomIdea(
        ideas,
        preferMatched: true,
        random: Random(42),
      );
      expect(picked?.id, 'm1');
    });
  });
}
