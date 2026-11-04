import 'package:flutter/foundation.dart';

/// Represents a collaborative decision-making ballot ("This or That", dinner, movie picks)
/// between two partners.
@immutable
class DecideSessionModel {
  static const String statusOpen = 'open';
  static const String statusResolved = 'resolved';

  final String id;
  final String title;
  final List<String> options;
  final Map<String, String> votes; // uid -> chosenOption
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? _explicitWinningOption;

  DecideSessionModel({
    required this.id,
    required this.title,
    required this.options,
    this.votes = const {},
    this.status = statusOpen,
    required this.createdBy,
    DateTime? createdAt,
    this.resolvedAt,
    String? winningOption,
  })  : createdAt = createdAt ?? DateTime.now(),
        _explicitWinningOption = winningOption;

  /// Whether both partners have voted or the session was explicitly marked resolved.
  bool get isResolved => status == statusResolved || votes.length >= 2;

  /// Whether at least two votes were cast and all partners agreed on the exact same choice.
  bool get isMatch =>
      votes.length >= 2 &&
      votes.values.every((v) => v.isNotEmpty && v == votes.values.first);

  /// Whether the session is resolved but votes did not agree.
  bool get isSplit => isResolved && votes.length >= 2 && !isMatch;

  /// Returns the winning option: either explicitly designated (e.g. via coin toss)
  /// or naturally resolved via a match. Returns null if unresolved or split without decision.
  String? get winningOption {
    if (!isResolved) return null;
    if (_explicitWinningOption != null && _explicitWinningOption!.isNotEmpty) {
      return _explicitWinningOption;
    }
    return isMatch ? votes.values.first : null;
  }

  /// Checks if a specific partner has cast their vote.
  bool hasUserVoted(String uid) =>
      votes.containsKey(uid) && (votes[uid]?.isNotEmpty ?? false);

  /// Returns the specific option chosen by a user, if any.
  String? getUserVote(String uid) => votes[uid];

  /// Partner cannot see other partner's vote until the ballot resolves (both have voted)!
  bool canUserSeePartnerVote(String myUid) => isResolved;

  /// Returns the other partner's vote if visible, or null if hidden/unvoted.
  String? getVisiblePartnerVote(String myUid) {
    if (!canUserSeePartnerVote(myUid)) return null;
    for (final entry in votes.entries) {
      if (entry.key != myUid) {
        return entry.value;
      }
    }
    return null;
  }

  /// Returns the partner's UID from the vote map or null if not available.
  String? getPartnerUid(String myUid) {
    for (final key in votes.keys) {
      if (key != myUid) return key;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'options': options,
      'votes': votes,
      'status': isResolved ? statusResolved : status,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'winningOption': winningOption,
    };
  }

  factory DecideSessionModel.fromMap(String id, Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final List<String> options = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];

    final rawVotes = map['votes'];
    final Map<String, String> votes = {};
    if (rawVotes is Map) {
      rawVotes.forEach((key, value) {
        if (value != null) {
          votes[key.toString()] = value.toString();
        }
      });
    }
    // Also defensively parse any root keys formatted as "votes.<uid>"
    map.forEach((key, value) {
      if (key.startsWith('votes.') && value != null) {
        final voteUid = key.substring('votes.'.length);
        if (voteUid.isNotEmpty && !votes.containsKey(voteUid)) {
          votes[voteUid] = value.toString();
        }
      }
    });

    return DecideSessionModel(
      id: id,
      title: map['title'] as String? ?? '',
      options: options,
      votes: votes,
      status: map['status'] as String? ?? statusOpen,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      resolvedAt: map['resolvedAt'] != null ? _parseDateTime(map['resolvedAt']) : null,
      winningOption: map['winningOption'] as String?,
    );
  }

  DecideSessionModel copyWith({
    String? id,
    String? title,
    List<String>? options,
    Map<String, String>? votes,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? winningOption,
    bool clearWinningOption = false,
  }) {
    return DecideSessionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      options: options ?? this.options,
      votes: votes ?? this.votes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      winningOption: clearWinningOption
          ? null
          : (winningOption ?? _explicitWinningOption),
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
      other is DecideSessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          listEquals(options, other.options) &&
          mapEquals(votes, other.votes) &&
          status == other.status &&
          createdBy == other.createdBy &&
          isResolved == other.isResolved &&
          winningOption == other.winningOption;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      status.hashCode ^
      createdBy.hashCode ^
      winningOption.hashCode;

  @override
  String toString() =>
      'DecideSessionModel(id: $id, title: $title, options: $options, votes: $votes, status: $status, winningOption: $winningOption)';
}
