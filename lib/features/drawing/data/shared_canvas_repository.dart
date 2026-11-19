import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:couple_app/features/drawing/domain/shared_canvas_model.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';

final sharedCanvasRepositoryProvider = Provider<SharedCanvasRepository>((ref) {
  return SharedCanvasRepository();
});

final sharedCanvasStreamProvider =
    StreamProvider.family<SharedCanvasModel, String>((ref, coupleId) {
  if (coupleId.trim().isEmpty) return Stream.value(const SharedCanvasModel());
  return ref.watch(sharedCanvasRepositoryProvider).watchCanvas(coupleId);
});

/// Repository managing realtime shared couple drawings under:
/// - `/couples/{coupleId}/shared_canvas/current` (live strokes, <= 200 KB)
/// - `/couples/{coupleId}/shared_canvas/widget_snapshot` (PNG Base64 for Glance widget)
class SharedCanvasRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  SharedCanvasRepository({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  DocumentReference<Map<String, dynamic>> _canvasRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_canvas')
        .doc('current');
  }

  DocumentReference<Map<String, dynamic>> _snapshotRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('shared_canvas')
        .doc('widget_snapshot');
  }

  DocumentReference<Map<String, dynamic>> _activityRef(String coupleId) {
    return _firestore
        .collection('couples')
        .doc(coupleId)
        .collection('activity_state')
        .doc('latest');
  }

  Stream<SharedCanvasModel> watchCanvas(String coupleId) {
    return _canvasRef(coupleId).snapshots().map(
          (snap) => SharedCanvasModel.fromMap(snap.data()),
        );
  }

  Future<void> appendStroke(
    String coupleId, {
    required CanvasStroke stroke,
    required String actorName,
  }) async {
    if (coupleId.trim().isEmpty || stroke.points.isEmpty) return;
    final simplified = stroke.points.length > 2
        ? SharedCanvasModel.simplifyPoints(stroke.points)
        : stroke.points;
    final cleanStroke = CanvasStroke(
      id: stroke.id.isNotEmpty ? stroke.id : _uuid.v4().substring(0, 10),
      authorUid: stroke.authorUid,
      colorHex: stroke.colorHex,
      strokeWidth: stroke.strokeWidth,
      isEraser: stroke.isEraser,
      points: simplified,
    );

    final ref = _canvasRef(coupleId);
    final nowIso = DateTime.now().toIso8601String();

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = SharedCanvasModel.fromMap(snap.data());
        final nextStrokes = SharedCanvasModel.trimStrokesToBudget([
          ...current.strokes,
          cleanStroke,
        ]);
        tx.set(
          ref,
          {
            'strokes': nextStrokes.map((s) => s.toMap()).toList(),
            'backgroundColorHex': current.backgroundColorHex,
            'updatedByUid': cleanStroke.authorUid,
            'updatedByName': actorName,
            'updatedAt': nowIso,
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('SharedCanvasRepository.appendStroke offline fallback: $e');
      SharedCanvasModel cached = const SharedCanvasModel();
      try {
        final cachedSnap = await ref.get(const GetOptions(source: Source.cache));
        if (cachedSnap.exists) {
          cached = SharedCanvasModel.fromMap(cachedSnap.data());
        }
      } catch (_) {}
      final nextStrokes = SharedCanvasModel.trimStrokesToBudget([
        ...cached.strokes,
        cleanStroke,
      ]);
      await ref.set(
        {
          'strokes': nextStrokes.map((s) => s.toMap()).toList(),
          'backgroundColorHex': cached.backgroundColorHex,
          'updatedByUid': cleanStroke.authorUid,
          'updatedByName': actorName,
          'updatedAt': nowIso,
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> undoLastStroke(
    String coupleId, {
    required String actorUid,
    required String actorName,
  }) async {
    if (coupleId.trim().isEmpty) return;
    final ref = _canvasRef(coupleId);
    final nowIso = DateTime.now().toIso8601String();
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = SharedCanvasModel.fromMap(snap.data());
        if (current.strokes.isEmpty) return;
        final next = List<CanvasStroke>.from(current.strokes)..removeLast();
        tx.set(
          ref,
          {
            'strokes': next.map((s) => s.toMap()).toList(),
            'updatedByUid': actorUid,
            'updatedByName': actorName,
            'updatedAt': nowIso,
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('SharedCanvasRepository.undoLastStroke warning: $e');
    }
  }

  Future<void> clearCanvas(
    String coupleId, {
    required String actorUid,
    required String actorName,
  }) async {
    if (coupleId.trim().isEmpty) return;
    await _canvasRef(coupleId).set(
      {
        'strokes': const <Map<String, dynamic>>[],
        'updatedByUid': actorUid,
        'updatedByName': actorName,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setBackgroundColor(
    String coupleId, {
    required String colorHex,
    required String actorUid,
    required String actorName,
  }) async {
    if (coupleId.trim().isEmpty) return;
    await _canvasRef(coupleId).set(
      {
        'backgroundColorHex': colorHex,
        'updatedByUid': actorUid,
        'updatedByName': actorName,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      SetOptions(merge: true),
    );
  }

  /// Publishes a compressed PNG snapshot to `/shared_canvas/widget_snapshot`,
  /// increments `drawingWidgetRevision`, and sets `noteWidgetMode = 'drawing'`
  /// in `activity_state/latest` so both partners' `NoteGlanceWidget` switches to
  /// the drawing (last-pinned wins).
  Future<int> publishWidgetSnapshot(
    String coupleId, {
    required Uint8List pngBytes,
    required String actorUid,
    required String actorName,
  }) async {
    final encoded = base64Encode(pngBytes);
    if (utf8.encode(encoded).length >
        DrawingWidgetSnapshotModel.maxSnapshotBase64Bytes) {
      throw Exception('Drawing snapshot exceeds safe Firestore Spark size.');
    }

    final now = DateTime.now();
    final eventId = '${now.millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
    final displayActor = actorName.trim().isNotEmpty ? actorName.trim() : 'Seu amor';

    int nextRevision = 1;
    try {
      final actSnap = await _activityRef(coupleId).get();
      final currentAct = ActivityStateModel.fromMap(actSnap.data());
      nextRevision = currentAct.drawingWidgetRevision + 1;
    } catch (_) {
      nextRevision = now.millisecondsSinceEpoch % 1000000;
    }

    final snapshotModel = DrawingWidgetSnapshotModel(
      pngBase64: encoded,
      revision: nextRevision,
      updatedByUid: actorUid,
      updatedByName: displayActor,
      updatedAt: now,
    );

    await _snapshotRef(coupleId).set(snapshotModel.toMap());
    await _activityRef(coupleId).set(
      {
        'drawingWidgetRevision': nextRevision,
        'noteWidgetMode': ActivityStateModel.widgetModeDrawing,
        'lastEventId': eventId,
        'lastEventType': ActivityStateModel.typeDrawing,
        'lastActorUid': actorUid,
        'lastActorName': displayActor,
        'title': 'Novo Desenho no Widget 🎨',
        'body': '$displayActor enviou um desenho para a tela inicial de vocês! 💕',
        'route': 'drawing',
        'updatedAt': now.toIso8601String(),
      },
      SetOptions(merge: true),
    );

    return nextRevision;
  }

  /// Switches the couple-wide `NoteGlanceWidget` mode back to sticky note
  /// whenever a partner pins a love note (last-pinned wins).
  Future<void> setNoteWidgetModeToNote(String coupleId) async {
    if (coupleId.trim().isEmpty) return;
    try {
      await _activityRef(coupleId).set(
        {'noteWidgetMode': ActivityStateModel.widgetModeNote},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('SharedCanvasRepository.setNoteWidgetModeToNote warning: $e');
    }
  }

  Future<DrawingWidgetSnapshotModel?> getWidgetSnapshot(String coupleId) async {
    if (coupleId.trim().isEmpty) return null;
    try {
      final snap = await _snapshotRef(coupleId).get();
      if (!snap.exists || snap.data() == null) return null;
      return DrawingWidgetSnapshotModel.fromMap(snap.data());
    } catch (e) {
      debugPrint('SharedCanvasRepository.getWidgetSnapshot warning: $e');
      return null;
    }
  }
}
