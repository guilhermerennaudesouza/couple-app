import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an intimacy card ("Carta de Intimidade / Desafio 18+") in Krivo.
/// Supports 3 intensity levels:
/// - [levelGentle]: Suave 💕 (Romântico, carícias, conexão emocional e elogios)
/// - [levelBold]: Ousado 🔥 (Provocações, beijos demorados, massagens sensuais, desejos)
/// - [levelSpicy]: Picante 🌶️ (Desafios intensos 18+, fantasias e momentos quentes a dois)
class AdultGameCardModel {
  static const String levelGentle = 'gentle';
  static const String levelBold = 'bold';
  static const String levelSpicy = 'spicy';

  static const String typeDare = 'desafio';
  static const String typeQuestion = 'pergunta';

  static const List<String> allLevels = [
    levelGentle,
    levelBold,
    levelSpicy,
  ];

  final String id;
  final String title;
  final String prompt;
  final String level; // 'gentle', 'bold', 'spicy'
  final String cardType; // 'desafio' or 'pergunta'
  final bool isCompleted;
  final String createdBy;
  final DateTime? completedAt;

  const AdultGameCardModel({
    required this.id,
    required this.title,
    required this.prompt,
    this.level = levelGentle,
    this.cardType = typeDare,
    this.isCompleted = false,
    this.createdBy = 'system',
    this.completedAt,
  });

  String get levelLabelPt {
    switch (level) {
      case levelBold:
        return 'Ousado 🔥';
      case levelSpicy:
        return 'Picante 🌶️';
      case levelGentle:
      default:
        return 'Suave 💕';
    }
  }

  String get cardTypeLabelPt =>
      cardType == typeQuestion ? 'Confissão Íntima 💬' : 'Desafio a Dois 🔥';

  AdultGameCardModel toggleCompleted({DateTime? at}) {
    final nextState = !isCompleted;
    return copyWith(
      isCompleted: nextState,
      completedAt: nextState ? (at ?? DateTime.now()) : null,
      clearCompletedAt: !nextState,
    );
  }

  AdultGameCardModel copyWith({
    String? id,
    String? title,
    String? prompt,
    String? level,
    String? cardType,
    bool? isCompleted,
    String? createdBy,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return AdultGameCardModel(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      level: level ?? this.level,
      cardType: cardType ?? this.cardType,
      isCompleted: isCompleted ?? this.isCompleted,
      createdBy: createdBy ?? this.createdBy,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'prompt': prompt,
      'level': level,
      'cardType': cardType,
      'isCompleted': isCompleted,
      'createdBy': createdBy,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory AdultGameCardModel.fromMap(String id, Map<String, dynamic> map) {
    return AdultGameCardModel(
      id: id,
      title: (map['title'] as String?) ?? 'Desafio Íntimo',
      prompt: (map['prompt'] as String?) ?? '',
      level: (map['level'] as String?) ?? levelGentle,
      cardType: (map['cardType'] as String?) ?? typeDare,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      createdBy: (map['createdBy'] as String?) ?? 'system',
      completedAt: _parseDate(map['completedAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}

/// Real-time shared game session state ("Convite Picante" & currently drawn card).
class AdultGameSessionState {
  final String? activeCardId;
  final String selectedLevel;
  final String? nudgeSenderUid;
  final String? nudgeSenderName;
  final String? nudgeMessage;
  final DateTime? nudgeSentAt;

  const AdultGameSessionState({
    this.activeCardId,
    this.selectedLevel = AdultGameCardModel.levelGentle,
    this.nudgeSenderUid,
    this.nudgeSenderName,
    this.nudgeMessage,
    this.nudgeSentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'activeCardId': activeCardId,
      'selectedLevel': selectedLevel,
      'nudgeSenderUid': nudgeSenderUid,
      'nudgeSenderName': nudgeSenderName,
      'nudgeMessage': nudgeMessage,
      'nudgeSentAt':
          nudgeSentAt != null ? Timestamp.fromDate(nudgeSentAt!) : null,
    };
  }

  factory AdultGameSessionState.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AdultGameSessionState();
    return AdultGameSessionState(
      activeCardId: map['activeCardId'] as String?,
      selectedLevel:
          (map['selectedLevel'] as String?) ?? AdultGameCardModel.levelGentle,
      nudgeSenderUid: map['nudgeSenderUid'] as String?,
      nudgeSenderName: map['nudgeSenderName'] as String?,
      nudgeMessage: map['nudgeMessage'] as String?,
      nudgeSentAt: AdultGameCardModel._parseDate(map['nudgeSentAt']),
    );
  }
}
