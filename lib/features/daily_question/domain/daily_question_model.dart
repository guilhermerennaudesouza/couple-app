import 'package:flutter/foundation.dart';

/// Represents a single partner's answer to a daily question prompt.
@immutable
class DailyQuestionAnswer {
  final String uid;
  final String text;
  final DateTime answeredAt;

  const DailyQuestionAnswer({
    required this.uid,
    required this.text,
    required this.answeredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'text': text,
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  factory DailyQuestionAnswer.fromMap(Map<String, dynamic> map) {
    return DailyQuestionAnswer(
      uid: map['uid'] as String? ?? '',
      text: map['text'] as String? ?? '',
      answeredAt: _parseDateTime(map['answeredAt']),
    );
  }

  DailyQuestionAnswer copyWith({
    String? uid,
    String? text,
    DateTime? answeredAt,
  }) {
    return DailyQuestionAnswer(
      uid: uid ?? this.uid,
      text: text ?? this.text,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      return (value as dynamic).toDate();
    } catch (_) {}
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyQuestionAnswer &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          text == other.text &&
          answeredAt == other.answeredAt;

  @override
  int get hashCode => uid.hashCode ^ text.hashCode ^ answeredAt.hashCode;

  @override
  String toString() =>
      'DailyQuestionAnswer(uid: $uid, text: $text, answeredAt: $answeredAt)';
}

/// A short follow-up comment posted on a revealed Daily Question.
@immutable
class DailyQuestionComment {
  final String id;
  final String uid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const DailyQuestionComment({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': uid,
        'authorName': authorName,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DailyQuestionComment.fromMap(Map<String, dynamic> map) {
    return DailyQuestionComment(
      id: map['id'] as String? ?? '',
      uid: map['uid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: DailyQuestionAnswer._parseDateTime(map['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyQuestionComment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          uid == other.uid &&
          authorName == other.authorName &&
          text == other.text &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      uid.hashCode ^
      authorName.hashCode ^
      text.hashCode ^
      createdAt.hashCode;
}

/// Root aggregate representing a couple's daily prompt and its dual concealed/revealed answers.
@immutable
class DailyQuestionModel {
  static const List<String> reactionOptions = ['❤️', '😂', '🥺', '🔥', '😍'];

  final String id;
  final String date; // YYYY-MM-DD
  final String prompt;
  final Map<String, DailyQuestionAnswer> answers;
  final bool isRevealed;
  final Map<String, String> reactions;
  final List<DailyQuestionComment> comments;
  final bool isCustom;
  final String? proposedByUid;

  DailyQuestionModel({
    required this.id,
    required this.date,
    required this.prompt,
    this.answers = const {},
    bool? isRevealed,
    this.reactions = const {},
    this.comments = const [],
    this.isCustom = false,
    this.proposedByUid,
  }) : isRevealed = (isRevealed ?? false) || (answers.length >= 2);

  /// Checks whether a specific partner has answered this prompt.
  bool hasUserAnswered(String uid) => answers.containsKey(uid);

  /// Retrieves the answer for a specific user ID.
  DailyQuestionAnswer? getAnswer(String uid) => answers[uid];

  /// Retrieves the partner's answer (any answer not submitted by `myUid`).
  DailyQuestionAnswer? getPartnerAnswer(String myUid) {
    for (final entry in answers.entries) {
      if (entry.key != myUid) {
        return entry.value;
      }
    }
    return null;
  }

  /// Whether both partners have submitted their answers.
  bool get isAnsweredByBoth => answers.length >= 2;

  /// Returns a copy of the model with an answer added or replaced for [uid].
  DailyQuestionModel copyWithAnswer(String uid, String text, DateTime timestamp) {
    final updatedAnswers = Map<String, DailyQuestionAnswer>.from(answers);
    updatedAnswers[uid] = DailyQuestionAnswer(
      uid: uid,
      text: text,
      answeredAt: timestamp,
    );
    final shouldReveal = updatedAnswers.length >= 2 || isRevealed;
    return copyWith(
      answers: updatedAnswers,
      isRevealed: shouldReveal,
    );
  }

  DailyQuestionModel copyWith({
    String? id,
    String? date,
    String? prompt,
    Map<String, DailyQuestionAnswer>? answers,
    bool? isRevealed,
    Map<String, String>? reactions,
    List<DailyQuestionComment>? comments,
    bool? isCustom,
    String? proposedByUid,
  }) {
    return DailyQuestionModel(
      id: id ?? this.id,
      date: date ?? this.date,
      prompt: prompt ?? this.prompt,
      answers: answers ?? this.answers,
      isRevealed: isRevealed ?? this.isRevealed,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
      isCustom: isCustom ?? this.isCustom,
      proposedByUid: proposedByUid ?? this.proposedByUid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'prompt': prompt,
      'answers': answers.map((k, v) => MapEntry(k, v.toMap())),
      'isRevealed': isRevealed,
      if (reactions.isNotEmpty) 'reactions': reactions,
      if (comments.isNotEmpty)
        'comments': comments.map((c) => c.toMap()).toList(),
      if (isCustom) 'isCustom': true,
      if (proposedByUid != null && proposedByUid!.isNotEmpty)
        'proposedByUid': proposedByUid,
    };
  }

  factory DailyQuestionModel.fromMap(String id, Map<String, dynamic> map) {
    final rawAnswers = map['answers'];
    final Map<String, DailyQuestionAnswer> parsedAnswers = {};

    if (rawAnswers is Map) {
      rawAnswers.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          parsedAnswers[key.toString()] = DailyQuestionAnswer.fromMap(value);
        } else if (value is Map) {
          parsedAnswers[key.toString()] = DailyQuestionAnswer.fromMap(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    final parsedReactions = <String, String>{};
    final rawReactions = map['reactions'];
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          parsedReactions[key.toString()] = value.toString();
        }
      });
    }

    final parsedComments = <DailyQuestionComment>[];
    final rawComments = map['comments'];
    if (rawComments is List) {
      for (final item in rawComments) {
        if (item is Map) {
          parsedComments.add(
            DailyQuestionComment.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final isRevealed =
        (map['isRevealed'] as bool? ?? false) || (parsedAnswers.length >= 2);

    return DailyQuestionModel(
      id: id,
      date: map['date'] as String? ?? id,
      prompt: map['prompt'] as String? ?? '',
      answers: parsedAnswers,
      isRevealed: isRevealed,
      reactions: parsedReactions,
      comments: parsedComments,
      isCustom: map['isCustom'] as bool? ?? false,
      proposedByUid: map['proposedByUid'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyQuestionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          prompt == other.prompt &&
          mapEquals(answers, other.answers) &&
          isRevealed == other.isRevealed &&
          mapEquals(reactions, other.reactions) &&
          listEquals(comments, other.comments) &&
          isCustom == other.isCustom &&
          proposedByUid == other.proposedByUid;

  @override
  int get hashCode =>
      id.hashCode ^
      date.hashCode ^
      prompt.hashCode ^
      answers.entries
          .fold(0, (prev, e) => prev ^ e.key.hashCode ^ e.value.hashCode) ^
      isRevealed.hashCode ^
      reactions.length.hashCode ^
      comments.length.hashCode ^
      isCustom.hashCode ^
      proposedByUid.hashCode;

  @override
  String toString() {
    return 'DailyQuestionModel(id: $id, date: $date, prompt: $prompt, answers: ${answers.length}, isRevealed: $isRevealed, isCustom: $isCustom)';
  }
}
