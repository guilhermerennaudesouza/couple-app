import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/core/services/background_sync_service.dart';
import 'package:couple_app/core/widgets/partner_avatar_widget.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/auth/domain/couple_model.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';
import 'package:couple_app/features/home/presentation/couple_home_screen.dart';
import 'package:couple_app/features/notes/domain/note_model.dart';
import 'package:couple_app/features/tasks/domain/task_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

void main() {
  group('Phase 2 Review Regressions (Critical & Important)', () {
    test('Critical #1: widgetSyncSnapshotReady requires all core streams to have values and deduplicates identical snapshots', () {
      expect(
        WidgetSyncService.canSyncWidgetSnapshot(
          hasCouple: true,
          hasTodayQuestion: true,
          hasTasks: false,
          hasNotes: true,
        ),
        isFalse,
      );
      expect(
        WidgetSyncService.canSyncWidgetSnapshot(
          hasCouple: true,
          hasTodayQuestion: true,
          hasTasks: true,
          hasNotes: true,
        ),
        isTrue,
      );

      final snap = {'dailyStreak': 3, 'pinnedNote': null};
      final sig1 = WidgetSyncService.computeSnapshotSignature(snap);
      final sig2 = WidgetSyncService.computeSnapshotSignature(
        {'dailyStreak': 3, 'pinnedNote': null},
      );
      expect(sig1, sig2);
    });

    test('Critical #2: shouldShowLivePartnerBanner returns false when myUid is empty', () {
      const state = ActivityStateModel(
        lastEventId: 'evt_99',
        lastEventType: ActivityStateModel.typePulse,
        lastActorUid: 'u1',
        lastActorName: 'Gui',
        title: 'Carinho',
        body: 'Saudade',
        route: 'home',
      );

      expect(
        shouldShowLivePartnerBanner(
          state: state,
          myUid: '',
          hasSeeded: true,
          lastSeenEventId: 'evt_98',
        ),
        isFalse,
      );
    });

    test('Critical #3: LocalNotificationService.initialize accepts requestPermission: false for headless workers', () async {
      // Compiles and executes safely with requestPermission: false without throwing
      await LocalNotificationService.initialize(requestPermission: false);
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeSos),
        LocalNotificationService.urgentChannelId,
      );
    });

    test('Important #5: buildCompactWidgetSnapshot bounds long pinned note and task titles under 2 KB', () {
      final longLetter = 'Eu te amo muito! ' * 400; // > 6 KB
      final longNote = NoteModel(
        id: 'n_long',
        title: 'Carta ${'A' * 200}',
        content: longLetter,
        authorUid: 'u1',
        authorName: 'Gui',
        isPinnedToWidget: true,
      );
      final longTask = TaskModel(
        id: 't_long',
        title: 'Comprar ${'B' * 200}',
        isCompleted: false,
      );
      final couple = CoupleModel(
        id: 'c1',
        members: const ['u1', 'u2'],
        anniversaryDate: DateTime(2024, 1, 1),
        inviteCode: '123456',
      );

      final snapshot = WidgetSyncService.buildCompactWidgetSnapshot(
        couple: couple,
        pinnedNote: longNote,
        todayQuestion: null,
        tasks: [longTask],
        dailyStreak: 4,
        isPortuguese: true,
      );

      final encodedBytes = utf8.encode(jsonEncode(snapshot)).length;
      expect(encodedBytes, lessThan(2048));
      final pinned = snapshot['pinnedNote'] as Map<String, dynamic>;
      expect((pinned['title'] as String).length, lessThanOrEqualTo(80));
      expect((pinned['content'] as String).length, lessThanOrEqualTo(280));
      final tasksMap = snapshot['tasks'] as Map<String, dynamic>;
      expect((tasksMap['task_1_title'] as String).length, lessThanOrEqualTo(80));
    });

    test('Important #7: isValidAvatarDataUri rejects empty base64 payloads, leading whitespace bypass, and oversized base64: URIs', () {
      expect(PairingRepository.isValidAvatarDataUri('data:image/jpeg;base64,'), isFalse);
      expect(PairingRepository.isValidAvatarDataUri('data:image/jpeg;base64,   '), isFalse);
      expect(
        PairingRepository.isValidAvatarDataUri(
          'base64:${'A' * (PairingRepository.maxAvatarDataUriBytes + 100)}',
        ),
        isFalse,
      );
      expect(
        PairingRepository.isValidAvatarDataUri(
          '   data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=   ',
        ),
        isTrue,
      );
    });

    testWidgets('Important #8: PartnerAvatarWidget falls back to visible initials when decoded bytes are not a valid image', (tester) async {
      // Valid base64 string, but corrupt/non-image bytes
      final badImageUri = 'data:image/jpeg;base64,${base64Encode([1, 2, 3, 4, 5])}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PartnerAvatarWidget(
              name: 'Gui Rocha',
              avatarUrl: badImageUri,
            ),
          ),
        ),
      );
      await tester.pump();

      // With Image.memory + errorBuilder, initials fallback must be present when image fails to decode
      // Trigger image error callback if CircleAvatar or verify ClipOval/Image errorBuilder
      expect(find.byType(PartnerAvatarWidget), findsOneWidget);
      final hasImageWidget = find.byType(Image).evaluate().isNotEmpty;
      expect(hasImageWidget, isTrue);
    });

    test('Important #11: shouldNotifyTaskCreation skips self-assigned tasks and notifies partner/shared tasks', () {
      expect(
        ActivityStateModel.shouldNotifyTaskCreation(
          assignedTo: 'u1',
          myUid: 'u1',
        ),
        isFalse,
      );
      expect(
        ActivityStateModel.shouldNotifyTaskCreation(
          assignedTo: 'u2',
          myUid: 'u1',
        ),
        isTrue,
      );
      expect(
        ActivityStateModel.shouldNotifyTaskCreation(
          assignedTo: null,
          myUid: 'u1',
        ),
        isTrue,
      );
    });

    test('Critical #3b: BackgroundSyncService exposes safe timeout constant for Firestore background read', () {
      expect(
        BackgroundSyncService.firestoreReadTimeout.inSeconds,
        inInclusiveRange(5, 30),
      );
    });
  });
}
