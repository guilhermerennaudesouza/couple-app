import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/notifications/local_notification_service.dart';
import 'package:couple_app/core/services/background_sync_service.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';

void main() {
  group('LocalNotificationService dual channels', () {
    test('routes urgent events to urgentChannelId and routine events to routineChannelId', () {
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeSos),
        LocalNotificationService.urgentChannelId,
      );
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typePulse),
        LocalNotificationService.urgentChannelId,
      );
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeSpicyNudge),
        LocalNotificationService.urgentChannelId,
      );

      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeDailyAnswer),
        LocalNotificationService.routineChannelId,
      );
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeTask),
        LocalNotificationService.routineChannelId,
      );
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeNote),
        LocalNotificationService.routineChannelId,
      );
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeDecide),
        LocalNotificationService.routineChannelId,
      );
      expect(
        LocalNotificationService.channelIdForEventType(ActivityStateModel.typeCoupon),
        LocalNotificationService.routineChannelId,
      );
    });
  });

  group('BackgroundSyncService.processActivityPayload', () {
    test('fires partner alert, records eventId, and updates widgets for new partner event', () async {
      final alerts = <Map<String, String>>[];
      final savedIds = <String>[];
      Map<String, dynamic>? appliedSnapshot;

      final state = ActivityStateModel(
        lastEventId: 'evt_101',
        lastEventType: ActivityStateModel.typePulse,
        lastActorUid: 'u2',
        lastActorName: 'Ana',
        title: 'Ana mandou carinho 💓',
        body: 'Tô pensando em você',
        route: 'home',
        widgetSnapshot: const {'dailyStreak': 4},
      );

      final result = await BackgroundSyncService.processActivityPayload(
        state: state,
        myUid: 'u1',
        lastNotifiedEventId: 'evt_100',
        onNotify: ({
          required String eventId,
          required String eventType,
          required String title,
          required String body,
          required String route,
        }) async {
          alerts.add({
            'eventId': eventId,
            'eventType': eventType,
            'title': title,
            'body': body,
            'route': route,
          });
        },
        onSaveLastNotifiedId: (id) async => savedIds.add(id),
        onSyncWidgets: (snapshot) async => appliedSnapshot = snapshot,
      );

      expect(result.didNotify, isTrue);
      expect(alerts.length, 1);
      expect(alerts.first['eventType'], ActivityStateModel.typePulse);
      expect(savedIds, ['evt_101']);
      expect(appliedSnapshot?['dailyStreak'], 4);
    });

    test('skips notification for own events and already-notified duplicates while still syncing widgets', () async {
      int notifyCount = 0;
      int widgetSyncCount = 0;

      // Own event
      final ownResult = await BackgroundSyncService.processActivityPayload(
        state: const ActivityStateModel(
          lastEventId: 'evt_200',
          lastEventType: ActivityStateModel.typeSos,
          lastActorUid: 'u1',
          lastActorName: 'Gui',
          title: 'SOS',
          body: 'Chocolate',
          route: 'cycle',
          widgetSnapshot: {'dailyStreak': 2},
        ),
        myUid: 'u1',
        lastNotifiedEventId: 'evt_199',
        onNotify: ({
          required eventId,
          required eventType,
          required title,
          required body,
          required route,
        }) async {
          notifyCount++;
        },
        onSaveLastNotifiedId: (_) async {},
        onSyncWidgets: (_) async => widgetSyncCount++,
      );

      expect(ownResult.didNotify, isFalse);
      expect(notifyCount, 0);
      expect(widgetSyncCount, 1);

      // Already-notified duplicate from partner
      final dupResult = await BackgroundSyncService.processActivityPayload(
        state: const ActivityStateModel(
          lastEventId: 'evt_201',
          lastEventType: ActivityStateModel.typePulse,
          lastActorUid: 'u2',
          lastActorName: 'Ana',
          title: 'Carinho',
          body: 'Saudade',
          route: 'home',
          widgetSnapshot: {'dailyStreak': 3},
        ),
        myUid: 'u1',
        lastNotifiedEventId: 'evt_201',
        onNotify: ({
          required eventId,
          required eventType,
          required title,
          required body,
          required route,
        }) async {
          notifyCount++;
        },
        onSaveLastNotifiedId: (_) async {},
        onSyncWidgets: (_) async => widgetSyncCount++,
      );

      expect(dupResult.didNotify, isFalse);
      expect(notifyCount, 0);
      expect(widgetSyncCount, 2);
    });

    test('handles empty activity state gracefully without throwing', () async {
      int notifyCount = 0;
      final res = await BackgroundSyncService.processActivityPayload(
        state: const ActivityStateModel(),
        myUid: 'u1',
        lastNotifiedEventId: null,
        onNotify: ({
          required eventId,
          required eventType,
          required title,
          required body,
          required route,
        }) async {
          notifyCount++;
        },
        onSaveLastNotifiedId: (_) async {},
        onSyncWidgets: (_) async {},
      );
      expect(res.didNotify, isFalse);
      expect(notifyCount, 0);
    });
  });
}
