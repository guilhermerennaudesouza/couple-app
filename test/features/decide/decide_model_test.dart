import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/decide/domain/decide_model.dart';
import 'package:couple_app/features/date_ideas/domain/date_idea_model.dart';
import 'package:couple_app/features/date_ideas/data/date_ideas_repository.dart';

void main() {
  group('DecideSessionModel tests', () {
    test('DecideSession resolves match when both partners pick same option', () {
      final session = DecideSessionModel(
        id: 's1',
        title: 'Dinner tonight?',
        options: ['Sushi', 'Pizza'],
        votes: {'uid_1': 'Sushi', 'uid_2': 'Sushi'},
        createdBy: 'uid_1',
        createdAt: DateTime.now(),
      );
      expect(session.isResolved, isTrue);
      expect(session.isMatch, isTrue);
      expect(session.winningOption, equals('Sushi'));
    });

    test('DecideSession detects split vote when partners pick different options', () {
      final session = DecideSessionModel(
        id: 's2',
        title: 'Movie genre?',
        options: ['Horror', 'Comedy'],
        votes: {'uid_1': 'Horror', 'uid_2': 'Comedy'},
        createdBy: 'uid_1',
        createdAt: DateTime.now(),
      );
      expect(session.isResolved, isTrue);
      expect(session.isMatch, isFalse);
      expect(session.winningOption, isNull);
    });

    test('DecideSession remains open and unrevealed when only one partner voted', () {
      final session = DecideSessionModel(
        id: 's3',
        title: 'Vacation Spot',
        options: ['Beach Resort', 'Mountain Cabin'],
        votes: {'uid_1': 'Beach Resort'},
        createdBy: 'uid_1',
        createdAt: DateTime.now(),
      );
      expect(session.isResolved, isFalse);
      expect(session.isMatch, isFalse);
      expect(session.winningOption, isNull);
      expect(session.hasUserVoted('uid_1'), isTrue);
      expect(session.hasUserVoted('uid_2'), isFalse);
      expect(session.canUserSeePartnerVote('uid_1'), isFalse);
      expect(session.canUserSeePartnerVote('uid_2'), isFalse);
    });

    test('DecideSession serialization round-trip maintains all fields', () {
      final createdTime = DateTime(2026, 11, 4, 18, 0);
      final resolvedTime = DateTime(2026, 11, 4, 18, 15);
      final session = DecideSessionModel(
        id: 's4',
        title: 'Board Game Night',
        options: ['Catan', 'Codenames', 'Ticket to Ride'],
        votes: {'uid_1': 'Catan', 'uid_2': 'Catan'},
        status: DecideSessionModel.statusResolved,
        createdBy: 'uid_1',
        createdAt: createdTime,
        resolvedAt: resolvedTime,
        winningOption: 'Catan',
      );

      final map = session.toMap();
      final restored = DecideSessionModel.fromMap('s4', map);

      expect(restored.id, equals('s4'));
      expect(restored.title, equals('Board Game Night'));
      expect(restored.options, equals(['Catan', 'Codenames', 'Ticket to Ride']));
      expect(restored.votes, equals({'uid_1': 'Catan', 'uid_2': 'Catan'}));
      expect(restored.status, equals(DecideSessionModel.statusResolved));
      expect(restored.createdBy, equals('uid_1'));
      expect(restored.createdAt.isAtSameMomentAs(createdTime), isTrue);
      expect(restored.resolvedAt?.isAtSameMomentAs(resolvedTime), isTrue);
      expect(restored.winningOption, equals('Catan'));
      expect(restored.isResolved, isTrue);
      expect(restored.isMatch, isTrue);
    });

    test('DecideSession copyWith and equality work accurately', () {
      final session1 = DecideSessionModel(
        id: 's5',
        title: 'Lunch',
        options: ['Tacos', 'Burgers'],
        votes: {'uid_1': 'Tacos'},
        createdBy: 'uid_1',
      );

      final session2 = session1.copyWith(
        votes: {'uid_1': 'Tacos', 'uid_2': 'Tacos'},
        status: DecideSessionModel.statusResolved,
      );

      expect(session2.isResolved, isTrue);
      expect(session2.isMatch, isTrue);
      expect(session2.winningOption, equals('Tacos'));
      expect(session1 == session2, isFalse);

      final sessionCopy = session1.copyWith();
      expect(session1, equals(sessionCopy));
    });

    test('DecideSession resolves tie-breaker with explicit winner on split vote', () {
      final session = DecideSessionModel(
        id: 's6',
        title: 'Friday Movie',
        options: ['Sci-Fi', 'Rom-Com'],
        votes: {'uid_1': 'Sci-Fi', 'uid_2': 'Rom-Com'},
        status: DecideSessionModel.statusResolved,
        winningOption: 'Sci-Fi',
        createdBy: 'uid_1',
      );

      expect(session.isResolved, isTrue);
      expect(session.isMatch, isFalse);
      expect(session.isSplit, isTrue);
      expect(session.winningOption, equals('Sci-Fi'));
    });

    test('DecideSession partner secrecy hides choice until both vote, then reveals', () {
      final oneVoteSession = DecideSessionModel(
        id: 's7',
        title: 'Dinner Choice',
        options: ['Italian', 'Mexican'],
        votes: {'uid_1': 'Italian'},
        createdBy: 'uid_1',
      );

      expect(oneVoteSession.canUserSeePartnerVote('uid_1'), isFalse);
      expect(oneVoteSession.getVisiblePartnerVote('uid_1'), isNull);
      expect(oneVoteSession.canUserSeePartnerVote('uid_2'), isFalse);
      expect(oneVoteSession.getVisiblePartnerVote('uid_2'), isNull);

      final twoVoteSession = oneVoteSession.copyWith(
        votes: {'uid_1': 'Italian', 'uid_2': 'Mexican'},
      );

      expect(twoVoteSession.canUserSeePartnerVote('uid_1'), isTrue);
      expect(twoVoteSession.getVisiblePartnerVote('uid_1'), equals('Mexican'));
      expect(twoVoteSession.getVisiblePartnerVote('uid_2'), equals('Italian'));
    });

    test('DecideSession re-vote reset clears votes and winning option', () {
      final resolvedSession = DecideSessionModel(
        id: 's8',
        title: 'Dessert',
        options: ['Ice Cream', 'Cake'],
        votes: {'uid_1': 'Ice Cream', 'uid_2': 'Cake'},
        status: DecideSessionModel.statusResolved,
        winningOption: 'Ice Cream',
        createdBy: 'uid_1',
      );

      expect(resolvedSession.isResolved, isTrue);

      final revoteSession = resolvedSession.copyWith(
        status: DecideSessionModel.statusOpen,
        votes: {},
        clearWinningOption: true,
      );

      expect(revoteSession.isResolved, isFalse);
      expect(revoteSession.isMatch, isFalse);
      expect(revoteSession.isSplit, isFalse);
      expect(revoteSession.winningOption, isNull);
      expect(revoteSession.votes.isEmpty, isTrue);
    });

    test('DecideSession parses legacy dot-notation keys in fromMap', () {
      final rawMap = {
        'title': 'Weekend Trip',
        'options': ['Mountains', 'Coast'],
        'votes.uid_1': 'Coast',
        'votes.uid_2': 'Coast',
        'status': 'resolved',
        'createdBy': 'uid_1',
      };

      final session = DecideSessionModel.fromMap('s9', rawMap);
      expect(session.votes['uid_1'], equals('Coast'));
      expect(session.votes['uid_2'], equals('Coast'));
      expect(session.isMatch, isTrue);
      expect(session.winningOption, equals('Coast'));
    });
  });

  group('DateIdeaModel tests', () {
    test('DateIdeaModel handles completion toggle and weekly pick state', () {
      final idea = DateIdeaModel(
        id: 'd1',
        title: 'Stargazing at the park',
        description: 'Bring a warm blanket and hot chocolate',
        category: 'Cozy',
        isCompleted: false,
        isWeeklyPick: true,
        createdBy: 'uid_1',
      );
      expect(idea.isWeeklyPick, isTrue);
      final completed = idea.toggleCompleted();
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      // Toggle back to incomplete
      final incomplete = completed.toggleCompleted();
      expect(incomplete.isCompleted, isFalse);
      expect(incomplete.completedAt, isNull);
    });

    test('DateIdeaModel serialization round-trip maintains all fields', () {
      final completedTime = DateTime(2026, 11, 4, 19, 0);
      final idea = DateIdeaModel(
        id: 'd2',
        title: 'Cook Pizza from Scratch',
        description: 'Make dough together and pick funny toppings',
        category: 'Foodie',
        isCompleted: true,
        completedAt: completedTime,
        isWeeklyPick: false,
        createdBy: 'uid_2',
      );

      final map = idea.toMap();
      final restored = DateIdeaModel.fromMap('d2', map);

      expect(restored.id, equals('d2'));
      expect(restored.title, equals('Cook Pizza from Scratch'));
      expect(restored.description, equals('Make dough together and pick funny toppings'));
      expect(restored.category, equals('Foodie'));
      expect(restored.isCompleted, isTrue);
      expect(restored.completedAt?.isAtSameMomentAs(completedTime), isTrue);
      expect(restored.isWeeklyPick, isFalse);
      expect(restored.createdBy, equals('uid_2'));
    });

    test('DateIdeaModel copyWith and equality work accurately', () {
      final idea1 = DateIdeaModel(
        id: 'd3',
        title: 'Museum Date',
        description: 'Art gallery in downtown',
        category: 'Adventurous',
        createdBy: 'uid_1',
      );

      final idea2 = idea1.copyWith(isWeeklyPick: true);
      expect(idea2.isWeeklyPick, isTrue);
      expect(idea1 == idea2, isFalse);

      final ideaCopy = idea1.copyWith();
      expect(idea1, equals(ideaCopy));
    });

    test('DateIdeasRepository defaultCuratedIdeas generates 6 curated date cards', () {
      final ideas = DateIdeasRepository.defaultCuratedIdeas(createdBy: 'uid_creator');
      expect(ideas.length, equals(6));
      expect(ideas.any((i) => i.category == DateIdeaModel.categoryCozy), isTrue);
      expect(ideas.any((i) => i.category == DateIdeaModel.categoryRomance), isTrue);
      expect(ideas.any((i) => i.category == DateIdeaModel.categoryFoodie), isTrue);
      expect(ideas.any((i) => i.isWeeklyPick), isTrue);
      for (final i in ideas) {
        expect(i.createdBy, equals('uid_creator'));
        expect(i.isCompleted, isFalse);
      }
    });
  });
}
