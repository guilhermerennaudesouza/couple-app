import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:couple_app/core/notifications/notification_route_provider.dart';
import 'package:couple_app/features/adult_games/data/adult_games_repository.dart';
import 'package:couple_app/features/adult_games/domain/adult_game_model.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/auth/domain/partner_profile.dart';
import 'package:couple_app/features/calendar/data/calendar_repository.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';
import 'package:couple_app/features/cycle/data/cycle_repository.dart';
import 'package:couple_app/features/cycle/domain/cycle_model.dart';
import 'package:couple_app/features/daily_question/data/daily_question_repository.dart';
import 'package:couple_app/features/daily_question/domain/daily_question_model.dart';
import 'package:couple_app/features/decide/data/decide_repository.dart';
import 'package:couple_app/features/decide/domain/decide_model.dart';
import 'package:couple_app/features/home/data/activity_state_repository.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';
import 'package:couple_app/features/home/presentation/couple_home_screen.dart';
import 'package:couple_app/features/loyalty/data/loyalty_repository.dart';
import 'package:couple_app/features/loyalty/domain/loyalty_coupon_model.dart';
import 'package:couple_app/features/notes/data/note_repository.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';
import 'package:couple_app/features/tasks/data/task_repository.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('Home route, badge & live banner helpers', () {
    test('parseRouteToTabIndex routes couple/home to 0 and daily_question to null (push screen)', () {
      expect(parseRouteToTabIndex('couple'), 0);
      expect(parseRouteToTabIndex('home'), 0);
      expect(parseRouteToTabIndex('daily_question'), isNull);
      expect(parseRouteToTabIndex('tasks'), 1);
      expect(parseRouteToTabIndex('calendar'), 2);
      expect(parseRouteToTabIndex('decide'), 3);
      expect(parseRouteToTabIndex('hub'), 4);
    });

    test('shouldShowLivePartnerBanner avoids launch storms, self-events, and duplicates', () {
      const state = ActivityStateModel(
        lastEventId: 'evt_1',
        lastEventType: ActivityStateModel.typePulse,
        lastActorUid: 'u2',
        lastActorName: 'Ana',
        title: 'Ana mandou carinho 💓',
        body: 'Tô com saudade',
        route: 'home',
      );

      // Not seeded yet (cold launch)
      expect(
        shouldShowLivePartnerBanner(
          state: state,
          myUid: 'u1',
          hasSeeded: false,
          lastSeenEventId: null,
        ),
        isFalse,
      );

      // Own action
      expect(
        shouldShowLivePartnerBanner(
          state: state,
          myUid: 'u2',
          hasSeeded: true,
          lastSeenEventId: 'evt_0',
        ),
        isFalse,
      );

      // Already seen
      expect(
        shouldShowLivePartnerBanner(
          state: state,
          myUid: 'u1',
          hasSeeded: true,
          lastSeenEventId: 'evt_1',
        ),
        isFalse,
      );

      // Brand-new partner event after seed
      expect(
        shouldShowLivePartnerBanner(
          state: state,
          myUid: 'u1',
          hasSeeded: true,
          lastSeenEventId: 'evt_0',
        ),
        isTrue,
      );
    });

    test('countPendingTasks and countOpenBallotsNeedingVote compute exact badge counts', () {
      final tasks = [
        TaskModel(id: '1', title: 'A', isCompleted: false),
        TaskModel(id: '2', title: 'B', isCompleted: true),
        TaskModel(id: '3', title: 'C', isCompleted: false),
      ];
      expect(countPendingTasks(tasks), 2);

      final ballots = [
        DecideSessionModel(
          id: 'b1',
          title: 'Jantar?',
          options: const ['Pizza', 'Sushi'],
          createdBy: 'u1',
          votes: const {},
          status: DecideSessionModel.statusOpen,
        ),
        DecideSessionModel(
          id: 'b2',
          title: 'Filme?',
          options: const ['A', 'B'],
          createdBy: 'u1',
          votes: const {'u1': 'A'},
          status: DecideSessionModel.statusOpen,
        ),
        DecideSessionModel(
          id: 'b3',
          title: 'Resolvida',
          options: const ['X', 'Y'],
          createdBy: 'u1',
          votes: const {'u1': 'X', 'u2': 'X'},
          status: DecideSessionModel.statusResolved,
        ),
      ];
      expect(countOpenBallotsNeedingVote(ballots, 'u1'), 1);
      expect(countOpenBallotsNeedingVote(ballots, 'u2'), 2);
    });
  });

  group('CoupleHomeScreen widget rendering', () {
    testWidgets('renders couple header, streak, SOS/nudge banners, and masks unscratched scratch card', (tester) async {
      const coupleId = 'c1';
      final couple = CoupleModel(
        id: coupleId,
        members: const ['u1', 'u2'],
        anniversaryDate: DateTime.now().subtract(const Duration(days: 120)),
        inviteCode: '123456',
        partnerProfiles: {
          'u1': PartnerProfile(uid: 'u1', name: 'Gui'),
          'u2': PartnerProfile(uid: 'u2', name: 'Ana'),
        },
      );

      final todayKey = DailyQuestionRepository.todayDateString;
      final todayQuestion = DailyQuestionModel(
        id: todayKey,
        date: todayKey,
        prompt: 'Qual a sua memória favorita dessa semana?',
        answers: const {},
        isRevealed: false,
      );

      final secretNote = NoteModel(
        id: 'n1',
        title: 'Surpresa',
        content: 'SEGREDO_QUE_NAO_PODE_VAZAR',
        authorUid: 'u2',
        authorName: 'Ana',
        isPinnedToWidget: true,
        isScratchCard: true,
        isScratched: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserUidProvider.overrideWith((ref) => Stream.value('u1')),
            coupleStreamProvider(coupleId).overrideWith((ref) => Stream.value(couple)),
            todayDailyQuestionProvider(coupleId).overrideWith((ref) => Stream.value(todayQuestion)),
            pastDailyQuestionsProvider(coupleId).overrideWith((ref) => Stream.value(const [])),
            dailyStreakProvider(coupleId).overrideWithValue(5),
            activityStateStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value(
                const ActivityStateModel(totalPulsesCount: 9),
              ),
            ),
            cycleDataStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value(
                CycleDataModel(
                  lastPeriodStart: DateTime.now().subtract(const Duration(days: 5)),
                  isConfigured: true,
                  activeCareRequest: '🍫 Quero um chocolate!',
                  careRequestedByName: 'Ana',
                ),
              ),
            ),
            adultGameSessionStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value(
                AdultGameSessionState(
                  nudgeSenderUid: 'u2',
                  nudgeSenderName: 'Ana',
                  nudgeMessage: 'Ana te chamou para jogar hoje 🔥',
                  nudgeSentAt: DateTime.now(),
                ),
              ),
            ),
            decideSessionsStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value(const <DecideSessionModel>[]),
            ),
            loyaltyCouponsStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value(const <LoyaltyCouponModel>[]),
            ),
            notesStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value([secretNote]),
            ),
            tasksStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value([
                TaskModel(id: 't1', title: 'Comprar flores', isCompleted: false),
              ]),
            ),
            calendarEventsStreamProvider(coupleId).overrideWith(
              (ref) => Stream.value([
                CalendarEventModel(
                  id: 'e1',
                  title: 'Jantar Especial',
                  date: DateTime.now().add(const Duration(days: 3)),
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('pt', 'BR'),
            home: CoupleHomeScreen(
              coupleId: coupleId,
              currentUid: 'u1',
              onSwitchTab: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('Gui & Ana'), findsOneWidget);
      expect(find.textContaining('5'), findsWidgets);
      expect(find.textContaining('Quero um chocolate'), findsOneWidget);
      expect(find.textContaining('Ana te chamou para jogar'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();

      expect(find.textContaining('SEGREDO_QUE_NAO_PODE_VAZAR'), findsNothing);
      expect(find.textContaining('raspar'), findsOneWidget);
      expect(find.textContaining('Comprar flores'), findsOneWidget);
      expect(find.textContaining('Jantar Especial'), findsOneWidget);
    });
  });
}
