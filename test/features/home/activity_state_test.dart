import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';

void main() {
  group('PartnerMood', () {
    test('truncates notes longer than 40 characters cleanly', () {
      const longNote =
          'Estou morrendo de saudade de você hoje e contando as horas para te abraçar';
      final sanitized = PartnerMood.sanitizeNote(longNote);
      expect(sanitized.length, lessThanOrEqualTo(40));
      expect(sanitized.isNotEmpty, isTrue);
    });

    test('activeMoodFor returns mood for today and null for yesterday', () {
      final today = DateTime(2026, 11, 19, 14, 0);
      final state = ActivityStateModel(
        moods: {
          'u1': PartnerMood(
            emoji: '💕',
            label: 'Apaixonado',
            note: 'Pensando em você',
            dateKey: '2026-11-19',
            updatedAt: today,
          ),
          'u2': PartnerMood(
            emoji: '😴',
            label: 'Cansado',
            dateKey: '2026-11-18',
            updatedAt: DateTime(2026, 11, 18, 22, 0),
          ),
        },
      );

      expect(state.activeMoodFor('u1', now: today)?.emoji, '💕');
      expect(state.activeMoodFor('u2', now: today), isNull);
      expect(state.activeMoodFor('u3', now: today), isNull);
    });
  });

  group('ActivityStateModel', () {
    test('appendPulse caps recentPulses at 10 newest items and increments totalPulsesCount', () {
      var state = const ActivityStateModel();
      for (var i = 1; i <= 12; i++) {
        state = state.appendPulse(
          ThinkingOfYouPulse(
            id: 'p_$i',
            senderUid: 'u1',
            senderName: 'Gui',
            message: 'Saudade $i',
            sentAt: DateTime(2026, 11, 19, 10, i),
          ),
        );
      }

      expect(state.totalPulsesCount, 12);
      expect(state.recentPulses.length, 10);
      expect(state.recentPulses.first.id, 'p_12');
      expect(state.recentPulses.last.id, 'p_3');
    });

    test('canNudgePartner enforces 1-hour cooldown per user', () {
      final sentAt = DateTime(2026, 11, 19, 10, 0);
      final state = ActivityStateModel(
        nudgeSentAtByUid: {'u1': sentAt},
      );

      expect(
        state.canNudgePartner('u1', now: DateTime(2026, 11, 19, 10, 59)),
        isFalse,
      );
      expect(
        state.canNudgePartner('u1', now: DateTime(2026, 11, 19, 11, 1)),
        isTrue,
      );
      expect(
        state.canNudgePartner('u2', now: DateTime(2026, 11, 19, 10, 5)),
        isTrue,
      );
    });

    test('isUrgentEventType separates urgent partner events from routine events', () {
      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typeSos), isTrue);
      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typePulse), isTrue);
      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typeSpicyNudge), isTrue);

      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typeDailyAnswer), isFalse);
      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typeTask), isFalse);
      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typeNote), isFalse);
      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typeDecide), isFalse);
      expect(ActivityStateModel.isUrgentEventType(ActivityStateModel.typeCoupon), isFalse);
    });

    test('fromMap handles null or legacy sparse maps safely', () {
      final empty = ActivityStateModel.fromMap(null);
      expect(empty.lastEventId, isEmpty);
      expect(empty.totalPulsesCount, 0);
      expect(empty.drawingWidgetRevision, 0);
      expect(empty.recentPulses, isEmpty);
      expect(empty.moods, isEmpty);
    });

    test('sanitizeNoteBodyForActivity masks unscratched scratch cards', () {
      final masked = ActivityStateModel.sanitizeNoteBodyForActivity(
        content: 'Segredo super romântico',
        isScratchCard: true,
        isScratched: false,
        isPortuguese: true,
      );
      expect(masked, isNot(contains('Segredo')));
      expect(masked, contains('raspar'));

      final revealed = ActivityStateModel.sanitizeNoteBodyForActivity(
        content: 'Te amo muito!',
        isScratchCard: false,
        isScratched: false,
        isPortuguese: true,
      );
      expect(revealed, 'Te amo muito!');
    });
  });
}
