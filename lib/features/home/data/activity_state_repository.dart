import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:couple_app/core/utils/couple_date_utils.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';

final activityStateRepositoryProvider = Provider<ActivityStateRepository>((ref) {
  return ActivityStateRepository();
});

final activityStateStreamProvider =
    StreamProvider.family<ActivityStateModel, String>((ref, coupleId) {
  if (coupleId.trim().isEmpty) {
    return Stream.value(const ActivityStateModel());
  }
  return ref.watch(activityStateRepositoryProvider).watchActivityState(coupleId);
});

/// Repository managing the single lightweight `< 2 KB` Firestore state document
/// `/couples/{coupleId}/activity_state/latest`.
class ActivityStateRepository {
  static const String collectionName = 'activity_state';
  static const String latestDocId = 'latest';

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  ActivityStateRepository({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  DocumentReference<Map<String, dynamic>> _latestRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection(collectionName)
        .doc(latestDocId);
  }

  Stream<ActivityStateModel> watchActivityState(String coupleId) {
    return _latestRef(coupleId).snapshots().map(
          (snap) => ActivityStateModel.fromMap(snap.data()),
        );
  }

  Future<ActivityStateModel> getActivityState(String coupleId) async {
    final snap = await _latestRef(coupleId).get();
    return ActivityStateModel.fromMap(snap.data());
  }

  /// Best-effort write recording a partner event into `activity_state/latest`
  /// so both foreground banners and 15-minute `WorkManager` sync react to it.
  Future<void> recordActivity(
    String coupleId, {
    required String eventType,
    required String actorUid,
    required String actorName,
    required String title,
    required String body,
    required String route,
  }) async {
    if (coupleId.trim().isEmpty || actorUid.trim().isEmpty) return;
    final now = DateTime.now();
    final eventId = '${now.millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
    try {
      await _latestRef(coupleId).set(
        {
          'lastEventId': eventId,
          'lastEventType': eventType,
          'lastActorUid': actorUid,
          'lastActorName': actorName.trim(),
          'title': title.trim(),
          'body': body.trim(),
          'route': route.trim(),
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('ActivityStateRepository.recordActivity warning: $e');
    }
  }

  /// Updates the current partner's daily mood (with optional 40-char note).
  Future<void> setMood(
    String coupleId, {
    required String uid,
    required String actorName,
    required String emoji,
    required String label,
    String? note,
  }) async {
    if (coupleId.trim().isEmpty || uid.trim().isEmpty) return;
    final now = DateTime.now();
    final cleanNote = PartnerMood.sanitizeNote(note);
    final mood = PartnerMood(
      emoji: emoji,
      label: label,
      note: cleanNote.isEmpty ? null : cleanNote,
      dateKey: CoupleDateUtils.formatDateKey(now),
      updatedAt: now,
    );
    final eventId = '${now.millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
    final displayActor = actorName.trim().isNotEmpty ? actorName.trim() : 'Seu amor';
    final body = cleanNote.isNotEmpty
        ? '$displayActor está $emoji $label: "$cleanNote"'
        : '$displayActor está $emoji $label hoje';

    await _latestRef(coupleId).set(
      {
        'moods': {uid: mood.toMap()},
        'lastEventId': eventId,
        'lastEventType': ActivityStateModel.typeMood,
        'lastActorUid': uid,
        'lastActorName': displayActor,
        'title': 'Humor do dia $emoji',
        'body': body,
        'route': 'home',
        'updatedAt': now.toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Sends a "Tô com Saudade / Enviar Carinho" pulse atomically, maintaining a
  /// rolling window of the latest 10 pulses plus a lifetime [totalPulsesCount].
  Future<void> sendThinkingOfYouPulse(
    String coupleId, {
    required String senderUid,
    required String senderName,
    String message = 'Tô pensando em você 💓',
  }) async {
    if (coupleId.trim().isEmpty || senderUid.trim().isEmpty) return;
    final now = DateTime.now();
    final eventId = '${now.millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
    final displayActor = senderName.trim().isNotEmpty ? senderName.trim() : 'Seu amor';
    final pulse = ThinkingOfYouPulse(
      id: eventId,
      senderUid: senderUid,
      senderName: displayActor,
      message: message.trim().isEmpty ? 'Tô pensando em você 💓' : message.trim(),
      sentAt: now,
    );

    final ref = _latestRef(coupleId);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = ActivityStateModel.fromMap(snap.data());
        final next = current.appendPulse(pulse);
        tx.set(
          ref,
          {
            'recentPulses': next.recentPulses.map((p) => p.toMap()).toList(),
            'totalPulsesCount': next.totalPulsesCount,
            'lastEventId': eventId,
            'lastEventType': ActivityStateModel.typePulse,
            'lastActorUid': senderUid,
            'lastActorName': displayActor,
            'title': '$displayActor mandou um carinho 💓',
            'body': pulse.message,
            'route': 'home',
            'updatedAt': now.toIso8601String(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('ActivityStateRepository.sendThinkingOfYouPulse fallback: $e');
      await ref.set(
        {
          'recentPulses': [pulse.toMap()],
          'totalPulsesCount': FieldValue.increment(1),
          'lastEventId': eventId,
          'lastEventType': ActivityStateModel.typePulse,
          'lastActorUid': senderUid,
          'lastActorName': displayActor,
          'title': '$displayActor mandou um carinho 💓',
          'body': pulse.message,
          'route': 'home',
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    }
  }

  /// Nudges partner to answer today's Daily Question (caller checks 1h cooldown).
  Future<void> sendDailyQuestionNudge(
    String coupleId, {
    required String senderUid,
    required String senderName,
  }) async {
    if (coupleId.trim().isEmpty || senderUid.trim().isEmpty) return;
    final now = DateTime.now();
    final eventId = '${now.millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
    final displayActor = senderName.trim().isNotEmpty ? senderName.trim() : 'Seu amor';

    await _latestRef(coupleId).set(
      {
        'nudgeSentAtByUid': {senderUid: now.toIso8601String()},
        'lastEventId': eventId,
        'lastEventType': ActivityStateModel.typeDailyNudge,
        'lastActorUid': senderUid,
        'lastActorName': displayActor,
        'title': 'Pergunta do Dia ✨',
        'body': '$displayActor já respondeu e está esperando sua resposta 💕',
        'route': 'daily_question',
        'updatedAt': now.toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Saves a compact `< 1 KB` widget summary inside `activity_state/latest`
  /// so the 15-minute `WorkManager` job can refresh all 4 Glance widgets in 1 read.
  Future<void> syncWidgetSnapshot(
    String coupleId, {
    required Map<String, dynamic> snapshot,
  }) async {
    if (coupleId.trim().isEmpty) return;
    try {
      await _latestRef(coupleId).set(
        {'widgetSnapshot': snapshot},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('ActivityStateRepository.syncWidgetSnapshot warning: $e');
    }
  }
}
