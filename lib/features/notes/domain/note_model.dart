import 'package:flutter/foundation.dart';

/// Represents a digital love note / sticky note shared between partners.
///
/// Features rich pastel coloring, widget pinning metadata, and resilient serialization.
@immutable
class NoteModel {
  final String id;
  final String title;
  final String content;
  final String colorHex;
  final bool isPinnedToWidget;
  final String authorUid;
  final String authorName;
  final DateTime updatedAt;
  final bool isScratchCard;
  final bool isScratched;
  final String? drawingDataJson;

  /// Curated romantic pastel color palette for sticky notes.
  static const List<String> presetColors = [
    '#FFE082', // Warm Vanilla
    '#FFCDD2', // Blush Pink
    '#C8E6C9', // Mint Green
    '#E1BEE7', // Lavender Mist
    '#BBDEFB', // Sky Blue
    '#FFE0B2', // Peach Glow
  ];

  /// Human-friendly names for preset pastel colors.
  static const Map<String, String> colorNames = {
    '#FFE082': 'Warm Vanilla',
    '#FFCDD2': 'Blush Pink',
    '#C8E6C9': 'Mint Green',
    '#E1BEE7': 'Lavender Mist',
    '#BBDEFB': 'Sky Blue',
    '#FFE0B2': 'Peach Glow',
  };

  /// Portuguese names for preset pastel colors.
  static const Map<String, String> colorNamesPt = {
    '#FFE082': 'Baunilha Suave',
    '#FFCDD2': 'Rosa Blush',
    '#C8E6C9': 'Verde Menta',
    '#E1BEE7': 'Lavanda Romântica',
    '#BBDEFB': 'Azul Céu',
    '#FFE0B2': 'Pêssego Quente',
  };

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.colorHex = '#FFE082',
    this.isPinnedToWidget = false,
    required this.authorUid,
    required this.authorName,
    DateTime? updatedAt,
    this.isScratchCard = false,
    this.isScratched = false,
    this.drawingDataJson,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Whether this love note contains a freehand doodle drawing.
  bool get hasDrawing => drawingDataJson != null && drawingDataJson!.trim().isNotEmpty;

  /// Converts the note into a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'colorHex': colorHex,
      'isPinnedToWidget': isPinnedToWidget,
      'authorUid': authorUid,
      'authorName': authorName,
      'updatedAt': updatedAt.toIso8601String(),
      'isScratchCard': isScratchCard,
      'isScratched': isScratched,
      if (drawingDataJson != null) 'drawingDataJson': drawingDataJson,
    };
  }

  /// Creates a [NoteModel] from Firestore or local data with resilient date parsing.
  factory NoteModel.fromMap(String id, Map<String, dynamic> map) {
    return NoteModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#FFE082',
      isPinnedToWidget: map['isPinnedToWidget'] as bool? ?? false,
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      updatedAt: _parseDateTime(map['updatedAt']),
      isScratchCard: map['isScratchCard'] as bool? ?? false,
      isScratched: map['isScratched'] as bool? ?? false,
      drawingDataJson: map['drawingDataJson'] as String?,
    );
  }

  /// Creates a copy of this note with modified fields.
  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? colorHex,
    bool? isPinnedToWidget,
    String? authorUid,
    String? authorName,
    DateTime? updatedAt,
    bool? isScratchCard,
    bool? isScratched,
    String? drawingDataJson,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      colorHex: colorHex ?? this.colorHex,
      isPinnedToWidget: isPinnedToWidget ?? this.isPinnedToWidget,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      updatedAt: updatedAt ?? this.updatedAt,
      isScratchCard: isScratchCard ?? this.isScratchCard,
      isScratched: isScratched ?? this.isScratched,
      drawingDataJson: drawingDataJson ?? this.drawingDataJson,
    );
  }

  /// Parses date from dynamic values (DateTime, String, epoch int, Timestamp).
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
      other is NoteModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          content == other.content &&
          colorHex == other.colorHex &&
          isPinnedToWidget == other.isPinnedToWidget &&
          authorUid == other.authorUid &&
          authorName == other.authorName &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      content.hashCode ^
      colorHex.hashCode ^
      isPinnedToWidget.hashCode ^
      authorUid.hashCode ^
      authorName.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'NoteModel(id: $id, title: $title, isPinnedToWidget: $isPinnedToWidget, colorHex: $colorHex, authorName: $authorName)';
  }
}
