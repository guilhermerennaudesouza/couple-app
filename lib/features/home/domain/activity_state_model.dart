import 'package:flutter/foundation.dart';
import 'package:couple_app/core/utils/couple_date_utils.dart';

/// Preset mood option displayed in the "Como estamos hoje" presence card.
@immutable
class MoodPreset {
  final String emoji;
  final String labelPt;
  final String labelEn;

  const MoodPreset({
    required this.emoji,
    required this.labelPt,
    required this.labelEn,
  });

  String label({required bool isPortuguese}) => isPortuguese ? labelPt : labelEn;
}

/// Daily mood check-in for one partner inside `/couples/{coupleId}/activity_state/latest`.
@immutable
class PartnerMood {
  static const int maxNoteLength = 40;

  static const List<MoodPreset> presets = [
    MoodPreset(emoji: '💕', labelPt: 'Apaixonado', labelEn: 'In love'),
    MoodPreset(emoji: '😴', labelPt: 'Cansado', labelEn: 'Tired'),
    MoodPreset(emoji: '🤗', labelPt: 'Carente', labelEn: 'Need hugs'),
    MoodPreset(emoji: '⚡', labelPt: 'Animado', labelEn: 'Energized'),
    MoodPreset(emoji: '🍫', labelPt: 'Com fome', labelEn: 'Hungry'),
    MoodPreset(emoji: '🧘', labelPt: 'Em paz', labelEn: 'Peaceful'),
  ];

  final String emoji;
  final String label;
  final String? note;
  final String dateKey;
  final DateTime updatedAt;

  const PartnerMood({
    required this.emoji,
    required this.label,
    this.note,
    required this.dateKey,
    required this.updatedAt,
  });

  /// Trims and bounds a short mood note to [maxNoteLength] characters.
  static String sanitizeNote(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.length <= maxNoteLength) return trimmed;
    return trimmed.substring(0, maxNoteLength).trimRight();
  }

  /// Whether this mood was logged on the same calendar day as [now].
  bool isActiveForDate(DateTime now) {
    return dateKey == CoupleDateUtils.formatDateKey(now);
  }

  Map<String, dynamic> toMap() {
    final cleanNote = sanitizeNote(note);
    return {
      'emoji': emoji,
      'label': label,
      if (cleanNote.isNotEmpty) 'note': cleanNote,
      'dateKey': dateKey,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PartnerMood.fromMap(Map<String, dynamic> map) {
    final updatedAt = _parseDateTime(map['updatedAt']);
    final rawDateKey = (map['dateKey'] as String?)?.trim();
    final dateKey = (rawDateKey != null && rawDateKey.isNotEmpty)
        ? rawDateKey
        : CoupleDateUtils.formatDateKey(updatedAt);
    final cleanNote = sanitizeNote(map['note'] as String?);
    return PartnerMood(
      emoji: map['emoji'] as String? ?? '💕',
      label: map['label'] as String? ?? '',
      note: cleanNote.isEmpty ? null : cleanNote,
      dateKey: dateKey,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerMood &&
          runtimeType == other.runtimeType &&
          emoji == other.emoji &&
          label == other.label &&
          note == other.note &&
          dateKey == other.dateKey &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      emoji.hashCode ^
      label.hashCode ^
      note.hashCode ^
      dateKey.hashCode ^
      updatedAt.hashCode;
}

/// Lightweight "Tô com Saudade / Enviar Carinho" pulse entry stored in the
/// rolling 10-item history inside `activity_state/latest`.
@immutable
class ThinkingOfYouPulse {
  final String id;
  final String senderUid;
  final String senderName;
  final String message;
  final DateTime sentAt;

  const ThinkingOfYouPulse({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUid': senderUid,
      'senderName': senderName,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  factory ThinkingOfYouPulse.fromMap(Map<String, dynamic> map) {
    return ThinkingOfYouPulse(
      id: map['id'] as String? ?? '',
      senderUid: map['senderUid'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      message: map['message'] as String? ?? 'Tô com saudade 💓',
      sentAt: _parseDateTime(map['sentAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThinkingOfYouPulse &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderUid == other.senderUid &&
          senderName == other.senderName &&
          message == other.message &&
          sentAt == other.sentAt;

  @override
  int get hashCode =>
      id.hashCode ^
      senderUid.hashCode ^
      senderName.hashCode ^
      message.hashCode ^
      sentAt.hashCode;
}

/// Single lightweight `< 2 KB` Firestore document `/couples/{coupleId}/activity_state/latest`
/// powering foreground live partner banners, moods, rolling "Tô com Saudade" pulses,
/// 1h nudge cooldowns, and single-read Android `WorkManager` background sync.
@immutable
class ActivityStateModel {
  static const int maxRecentPulses = 10;
  static const Duration defaultNudgeCooldown = Duration(hours: 1);

  static const String typePulse = 'pulse';
  static const String typeSos = 'sos';
  static const String typeSpicyNudge = 'spicy_nudge';
  static const String typeDailyAnswer = 'daily_answer';
  static const String typeDailyNudge = 'daily_nudge';
  static const String typeNote = 'note';
  static const String typeDecide = 'decide';
  static const String typeCoupon = 'coupon';
  static const String typeTask = 'task';
  static const String typeMood = 'mood';

  final String lastEventId;
  final String lastEventType;
  final String lastActorUid;
  final String lastActorName;
  final String title;
  final String body;
  final String route;
  final DateTime? updatedAt;
  final Map<String, PartnerMood> moods;
  final List<ThinkingOfYouPulse> recentPulses;
  final int totalPulsesCount;
  final int drawingWidgetRevision;
  final Map<String, DateTime> nudgeSentAtByUid;
  final Map<String, dynamic> widgetSnapshot;

  const ActivityStateModel({
    this.lastEventId = '',
    this.lastEventType = '',
    this.lastActorUid = '',
    this.lastActorName = '',
    this.title = '',
    this.body = '',
    this.route = 'home',
    this.updatedAt,
    this.moods = const {},
    this.recentPulses = const [],
    this.totalPulsesCount = 0,
    this.drawingWidgetRevision = 0,
    this.nudgeSentAtByUid = const {},
    this.widgetSnapshot = const {},
  });

  /// Returns `true` for high-priority partner events routed to the Android
  /// "Urgentes do Par" notification channel.
  static bool isUrgentEventType(String eventType) {
    return eventType == typeSos ||
        eventType == typePulse ||
        eventType == typeSpicyNudge;
  }

  /// Returns `true` when creating a task should notify the partner (i.e., the
  /// task is shared/unassigned or assigned to the partner, not solely to self).
  static bool shouldNotifyTaskCreation({
    required String? assignedTo,
    required String myUid,
  }) {
    final trimmed = assignedTo?.trim() ?? '';
    if (trimmed.isEmpty) return true;
    return trimmed != myUid;
  }

  /// Ensures unscratched scratch-card content never leaks into activity notifications
  /// or background widget snapshots.
  static String sanitizeNoteBodyForActivity({
    required String content,
    required bool isScratchCard,
    required bool isScratched,
    bool isPortuguese = true,
  }) {
    if (isScratchCard && !isScratched) {
      return isPortuguese
          ? '🎁 Recado surpresa! Toque para raspar ✨'
          : '🎁 Surprise note! Tap to scratch ✨';
    }
    final trimmed = content.trim();
    if (trimmed.length <= 120) return trimmed;
    return '${trimmed.substring(0, 117).trimRight()}...';
  }

  /// Returns the partner's mood ONLY if it was set today, hiding stale moods
  /// automatically after midnight without requiring a Firestore write.
  PartnerMood? activeMoodFor(String uid, {DateTime? now}) {
    if (uid.isEmpty) return null;
    final mood = moods[uid];
    if (mood == null) return null;
    return mood.isActiveForDate(now ?? DateTime.now()) ? mood : null;
  }

  /// Whether [myUid] is allowed to nudge their partner on the Daily Question
  /// without violating the 1-hour anti-spam cooldown.
  bool canNudgePartner(
    String myUid, {
    DateTime? now,
    Duration cooldown = defaultNudgeCooldown,
  }) {
    final lastNudge = nudgeSentAtByUid[myUid];
    if (lastNudge == null) return true;
    final current = now ?? DateTime.now();
    return current.difference(lastNudge) >= cooldown;
  }

  /// Remaining cooldown duration before [myUid] can nudge again, or `Duration.zero`.
  Duration remainingNudgeCooldown(
    String myUid, {
    DateTime? now,
    Duration cooldown = defaultNudgeCooldown,
  }) {
    final lastNudge = nudgeSentAtByUid[myUid];
    if (lastNudge == null) return Duration.zero;
    final elapsed = (now ?? DateTime.now()).difference(lastNudge);
    if (elapsed >= cooldown) return Duration.zero;
    return cooldown - elapsed;
  }

  /// Pure helper returning a new [ActivityStateModel] with [pulse] prepended to
  /// [recentPulses] (capped at [maxRecentPulses]) and [totalPulsesCount] incremented.
  ActivityStateModel appendPulse(ThinkingOfYouPulse pulse) {
    final updated = [pulse, ...recentPulses].take(maxRecentPulses).toList();
    return copyWith(
      recentPulses: updated,
      totalPulsesCount: totalPulsesCount + 1,
    );
  }

  ActivityStateModel copyWith({
    String? lastEventId,
    String? lastEventType,
    String? lastActorUid,
    String? lastActorName,
    String? title,
    String? body,
    String? route,
    DateTime? updatedAt,
    Map<String, PartnerMood>? moods,
    List<ThinkingOfYouPulse>? recentPulses,
    int? totalPulsesCount,
    int? drawingWidgetRevision,
    Map<String, DateTime>? nudgeSentAtByUid,
    Map<String, dynamic>? widgetSnapshot,
  }) {
    return ActivityStateModel(
      lastEventId: lastEventId ?? this.lastEventId,
      lastEventType: lastEventType ?? this.lastEventType,
      lastActorUid: lastActorUid ?? this.lastActorUid,
      lastActorName: lastActorName ?? this.lastActorName,
      title: title ?? this.title,
      body: body ?? this.body,
      route: route ?? this.route,
      updatedAt: updatedAt ?? this.updatedAt,
      moods: moods ?? this.moods,
      recentPulses: recentPulses ?? this.recentPulses,
      totalPulsesCount: totalPulsesCount ?? this.totalPulsesCount,
      drawingWidgetRevision:
          drawingWidgetRevision ?? this.drawingWidgetRevision,
      nudgeSentAtByUid: nudgeSentAtByUid ?? this.nudgeSentAtByUid,
      widgetSnapshot: widgetSnapshot ?? this.widgetSnapshot,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lastEventId': lastEventId,
      'lastEventType': lastEventType,
      'lastActorUid': lastActorUid,
      'lastActorName': lastActorName,
      'title': title,
      'body': body,
      'route': route,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'moods': moods.map((k, v) => MapEntry(k, v.toMap())),
      'recentPulses': recentPulses.map((p) => p.toMap()).toList(),
      'totalPulsesCount': totalPulsesCount,
      'drawingWidgetRevision': drawingWidgetRevision,
      'nudgeSentAtByUid':
          nudgeSentAtByUid.map((k, v) => MapEntry(k, v.toIso8601String())),
      if (widgetSnapshot.isNotEmpty) 'widgetSnapshot': widgetSnapshot,
    };
  }

  factory ActivityStateModel.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const ActivityStateModel();
    }

    final parsedMoods = <String, PartnerMood>{};
    final rawMoods = map['moods'];
    if (rawMoods is Map) {
      rawMoods.forEach((key, value) {
        if (value is Map) {
          parsedMoods[key.toString()] =
              PartnerMood.fromMap(Map<String, dynamic>.from(value));
        }
      });
    }

    final parsedPulses = <ThinkingOfYouPulse>[];
    final rawPulses = map['recentPulses'];
    if (rawPulses is List) {
      for (final item in rawPulses) {
        if (item is Map) {
          parsedPulses.add(
            ThinkingOfYouPulse.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final parsedNudges = <String, DateTime>{};
    final rawNudges = map['nudgeSentAtByUid'];
    if (rawNudges is Map) {
      rawNudges.forEach((key, value) {
        if (value != null) {
          parsedNudges[key.toString()] = _parseDateTime(value);
        }
      });
    }

    final rawSnapshot = map['widgetSnapshot'];
    final parsedSnapshot = rawSnapshot is Map
        ? Map<String, dynamic>.from(rawSnapshot)
        : const <String, dynamic>{};

    return ActivityStateModel(
      lastEventId: map['lastEventId'] as String? ?? '',
      lastEventType: map['lastEventType'] as String? ?? '',
      lastActorUid: map['lastActorUid'] as String? ?? '',
      lastActorName: map['lastActorName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      route: map['route'] as String? ?? 'home',
      updatedAt:
          map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
      moods: parsedMoods,
      recentPulses: parsedPulses.take(maxRecentPulses).toList(),
      totalPulsesCount: (map['totalPulsesCount'] as num?)?.toInt() ?? 0,
      drawingWidgetRevision:
          (map['drawingWidgetRevision'] as num?)?.toInt() ?? 0,
      nudgeSentAtByUid: parsedNudges,
      widgetSnapshot: parsedSnapshot,
    );
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {}
  return DateTime.now();
}
