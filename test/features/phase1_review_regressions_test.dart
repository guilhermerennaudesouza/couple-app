import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/features/adult_games/data/adult_games_repository.dart';
import 'package:couple_app/features/adult_games/domain/adult_game_model.dart';
import 'package:couple_app/features/adult_games/presentation/adult_games_screen.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/calendar/domain/calendar_event_model.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';

class _RecordingNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  int showCalls = 0;
  int zonedScheduleCalls = 0;

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    showCalls++;
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    dynamic scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    required UILocalNotificationDateInterpretation
        uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    zonedScheduleCalls++;
  }
}

void main() {
  group('Phase 1 Code Review Regression Tests', () {
    test(
      'Critical #1: scheduleEventReminder with showIfDueNow=false does not spam show() for events inside reminder window',
      () async {
        final fakePlugin = _RecordingNotificationsPlugin();
        LocalNotificationService.setMockPlugin(fakePlugin);

        final tomorrowEvent = CalendarEventModel(
          id: 'ev_spam_test',
          title: 'Nosso Aniversário',
          date: DateTime.now().add(const Duration(days: 1)),
          isAnnual: false,
          category: CalendarEventModel.categoryAnniversary,
          reminderDaysBefore: 3, // reminderDay is 2 days ago, event is not past!
          createdBy: 'u1',
        );

        await LocalNotificationService.scheduleEventReminder(
          tomorrowEvent,
          showIfDueNow: false,
        );

        expect(fakePlugin.showCalls, equals(0));
      },
    );

    testWidgets(
      'Critical #2: AdultGamesScreen allows switching intensity level tabs even when session.selectedLevel is already set in Firestore',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({
          'adult_games_18_confirmed': 'true',
        });

        final cards = [
          AdultGameCardModel(
            id: 'c_gentle',
            title: 'Carta Suave Teste',
            prompt: 'Prompt suave',
            level: AdultGameCardModel.levelGentle,
            cardType: AdultGameCardModel.typeQuestion,
          ),
          AdultGameCardModel(
            id: 'c_bold',
            title: 'Carta Ousada Teste',
            prompt: 'Prompt ousado',
            level: AdultGameCardModel.levelBold,
            cardType: AdultGameCardModel.typeDare,
          ),
        ];

        final session = const AdultGameSessionState(
          activeCardId: 'c_gentle',
          selectedLevel: AdultGameCardModel.levelGentle,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adultGamesDeckStreamProvider('c1')
                  .overrideWith((ref) => Stream.value(cards)),
              adultGameSessionStreamProvider('c1')
                  .overrideWith((ref) => Stream.value(session)),
              coupleStreamProvider('c1')
                  .overrideWith((ref) => Stream.value(null)),
              currentUserUidProvider
                  .overrideWith((ref) => Stream.value('u1')),
            ],
            child: const MaterialApp(
              home: AdultGamesScreen(coupleId: 'c1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Carta Suave Teste'), findsWidgets);

        await tester.tap(find.text('Ousado 🔥'));
        await tester.pumpAndSettle();

        expect(find.text('Carta Ousada Teste'), findsWidgets);
      },
    );

    test(
      'Important #3: NoteModel.resolveScratchedOnSave resets scratched state when converting normal note to scratch card, but preserves already-scratched scratch cards',
      () {
        final normalNote = NoteModel(
          id: 'n1',
          title: 'Normal',
          content: 'Oi amor',
          authorUid: 'u1',
          authorName: 'Gui',
          isScratchCard: false,
          isScratched: true,
        );
        expect(
          NoteModel.resolveScratchedOnSave(
            isScratchCard: true,
            existingNote: normalNote,
          ),
          isFalse,
        );

        final revealedScratch = normalNote.copyWith(
          isScratchCard: true,
          isScratched: true,
        );
        expect(
          NoteModel.resolveScratchedOnSave(
            isScratchCard: true,
            existingNote: revealedScratch,
          ),
          isTrue,
        );
      },
    );
  });
}
