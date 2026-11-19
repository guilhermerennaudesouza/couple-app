import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Normalized point (`0.0..1.0` on X and Y) so drawings scale cleanly across
/// different Android phone aspect ratios and Jetpack Glance widgets.
@immutable
class CanvasPoint {
  final double x;
  final double y;

  const CanvasPoint(this.x, this.y);

  Map<String, dynamic> toMap() => {
        'x': double.parse(x.toStringAsFixed(4)),
        'y': double.parse(y.toStringAsFixed(4)),
      };

  factory CanvasPoint.fromMap(Map<String, dynamic> map) {
    return CanvasPoint(
      (map['x'] as num?)?.toDouble() ?? 0.0,
      (map['y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasPoint &&
          runtimeType == other.runtimeType &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6;

  @override
  int get hashCode => x.toStringAsFixed(4).hashCode ^ y.toStringAsFixed(4).hashCode;
}

/// A single freehand stroke drawn by one partner on the shared canvas.
@immutable
class CanvasStroke {
  final String id;
  final String authorUid;
  final String colorHex;
  final double strokeWidth;
  final bool isEraser;
  final List<CanvasPoint> points;

  const CanvasStroke({
    required this.id,
    required this.authorUid,
    required this.colorHex,
    required this.strokeWidth,
    this.isEraser = false,
    required this.points,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorUid': authorUid,
        'colorHex': colorHex,
        'strokeWidth': strokeWidth,
        'isEraser': isEraser,
        'points': points.map((p) => p.toMap()).toList(),
      };

  factory CanvasStroke.fromMap(Map<String, dynamic> map) {
    final rawPts = map['points'];
    final pts = <CanvasPoint>[];
    if (rawPts is List) {
      for (final item in rawPts) {
        if (item is Map) {
          pts.add(CanvasPoint.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return CanvasStroke(
      id: map['id'] as String? ?? '',
      authorUid: map['authorUid'] as String? ?? '',
      colorHex: map['colorHex'] as String? ?? '#E91E63',
      strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 4.0,
      isEraser: map['isEraser'] as bool? ?? false,
      points: pts,
    );
  }
}

/// Live shared canvas state stored at `/couples/{coupleId}/shared_canvas/current`.
@immutable
class SharedCanvasModel {
  /// Hard safety ceiling (~200 KB) so the strokes document stays far below Firestore's 1 MB limit.
  static const int maxStrokesPayloadBytes = 200 * 1024;

  static const String defaultBackgroundHex = '#FFF9FB';

  static const List<String> brushPaletteHex = [
    '#2E221F', // Charcoal
    '#E91E63', // Krivo Rose
    '#FF5252', // Coral Red
    '#FF9800', // Sunset Orange
    '#FDD835', // Warm Gold
    '#2E7D32', // Forest Green
    '#00ACC1', // Ocean Teal
    '#1E88E5', // Sky Blue
    '#7E57C2', // Soft Plum
    '#FFFFFF', // Pure White
  ];

  static const List<String> backgroundPaletteHex = [
    '#FFF9FB', // Soft Blush Paper
    '#FFFDF5', // Warm Cream
    '#F3F0FF', // Soft Lavender
    '#EEF7FF', // Pastel Sky
    '#1E1B24', // Midnight Canvas
  ];

  final List<CanvasStroke> strokes;
  final String backgroundColorHex;
  final String updatedByUid;
  final String updatedByName;
  final DateTime? updatedAt;

  const SharedCanvasModel({
    this.strokes = const [],
    this.backgroundColorHex = defaultBackgroundHex,
    this.updatedByUid = '',
    this.updatedByName = '',
    this.updatedAt,
  });

  /// Drops redundant micro-jitter points closer than [minDistance] (normalized 0..1)
  /// while always preserving the start and end points.
  static List<CanvasPoint> simplifyPoints(
    List<CanvasPoint> raw, {
    double minDistance = 0.008,
  }) {
    if (raw.length <= 2) return List<CanvasPoint>.from(raw);
    final result = <CanvasPoint>[raw.first];
    CanvasPoint lastKept = raw.first;
    final minDistSq = minDistance * minDistance;

    for (var i = 1; i < raw.length - 1; i++) {
      final p = raw[i];
      final dx = p.x - lastKept.x;
      final dy = p.y - lastKept.y;
      if ((dx * dx + dy * dy) >= minDistSq) {
        result.add(p);
        lastKept = p;
      }
    }
    if (result.last != raw.last) {
      result.add(raw.last);
    }
    return result;
  }

  /// Trims oldest strokes (and decimates even a single giant continuous stroke)
  /// so the serialized JSON payload stays strictly <= [maxBytes].
  static List<CanvasStroke> trimStrokesToBudget(
    List<CanvasStroke> strokes, {
    int maxBytes = maxStrokesPayloadBytes,
  }) {
    if (strokes.isEmpty) return const [];
    final working = List<CanvasStroke>.from(strokes);
    while (working.length > 1) {
      final bytes = utf8
          .encode(jsonEncode(working.map((s) => s.toMap()).toList()))
          .length;
      if (bytes <= maxBytes) break;
      final dropCount = max(1, working.length ~/ 10);
      working.removeRange(0, min(dropCount, working.length - 1));
    }

    // Also guard a single huge continuous finger scribble from blowing the 200 KB cap
    if (working.length == 1) {
      var single = working.first;
      while (single.points.length > 2) {
        final bytes = utf8.encode(jsonEncode([single.toMap()])).length;
        if (bytes <= maxBytes) break;
        final decimated = <CanvasPoint>[single.points.first];
        for (var i = 2; i < single.points.length - 1; i += 2) {
          decimated.add(single.points[i]);
        }
        decimated.add(single.points.last);
        single = CanvasStroke(
          id: single.id,
          authorUid: single.authorUid,
          colorHex: single.colorHex,
          strokeWidth: single.strokeWidth,
          isEraser: single.isEraser,
          points: decimated,
        );
      }
      working[0] = single;
    }

    return working;
  }

  Map<String, dynamic> toMap() => {
        'strokes': strokes.map((s) => s.toMap()).toList(),
        'backgroundColorHex': backgroundColorHex,
        'updatedByUid': updatedByUid,
        'updatedByName': updatedByName,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory SharedCanvasModel.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return const SharedCanvasModel();
    final rawStrokes = map['strokes'];
    final parsed = <CanvasStroke>[];
    if (rawStrokes is List) {
      for (final item in rawStrokes) {
        if (item is Map) {
          parsed.add(CanvasStroke.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    DateTime? parsedUpdatedAt;
    final rawTs = map['updatedAt'];
    if (rawTs is String) {
      parsedUpdatedAt = DateTime.tryParse(rawTs);
    } else if (rawTs != null) {
      try {
        parsedUpdatedAt = (rawTs as dynamic).toDate() as DateTime;
      } catch (_) {}
    }

    return SharedCanvasModel(
      strokes: parsed,
      backgroundColorHex:
          (map['backgroundColorHex'] as String?)?.trim().isNotEmpty == true
              ? (map['backgroundColorHex'] as String).trim()
              : defaultBackgroundHex,
      updatedByUid: map['updatedByUid'] as String? ?? '',
      updatedByName: map['updatedByName'] as String? ?? '',
      updatedAt: parsedUpdatedAt,
    );
  }
}

/// Compressed PNG snapshot stored at `/couples/{coupleId}/shared_canvas/widget_snapshot`
/// so both phones (and conditional WorkManager background sync) render the drawing natively
/// inside `NoteGlanceWidget`.
@immutable
class DrawingWidgetSnapshotModel {
  static const int maxSnapshotBase64Bytes = 140 * 1024;

  final String pngBase64;
  final int revision;
  final String updatedByUid;
  final String updatedByName;
  final DateTime? updatedAt;

  const DrawingWidgetSnapshotModel({
    required this.pngBase64,
    required this.revision,
    required this.updatedByUid,
    required this.updatedByName,
    this.updatedAt,
  });

  Uint8List? decodeBytes() {
    if (pngBase64.trim().isEmpty) return null;
    try {
      return base64Decode(pngBase64.trim());
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() => {
        'pngBase64': pngBase64,
        'revision': revision,
        'updatedByUid': updatedByUid,
        'updatedByName': updatedByName,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  factory DrawingWidgetSnapshotModel.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const DrawingWidgetSnapshotModel(
        pngBase64: '',
        revision: 0,
        updatedByUid: '',
        updatedByName: '',
      );
    }
    return DrawingWidgetSnapshotModel(
      pngBase64: map['pngBase64'] as String? ?? '',
      revision: (map['revision'] as num?)?.toInt() ?? 0,
      updatedByUid: map['updatedByUid'] as String? ?? '',
      updatedByName: map['updatedByName'] as String? ?? '',
      updatedAt: map['updatedAt'] is String
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
    );
  }
}
