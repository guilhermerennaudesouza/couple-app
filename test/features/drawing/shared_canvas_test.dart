import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/core/services/background_sync_service.dart';
import 'package:couple_app/features/drawing/domain/shared_canvas_model.dart';
import 'package:couple_app/features/home/domain/activity_state_model.dart';

void main() {
  group('SharedCanvasModel point simplification & 200 KB budget', () {
    test('simplifyPoints drops micro-jitter points closer than minDistance while keeping endpoints', () {
      const raw = [
        CanvasPoint(0.100, 0.100),
        CanvasPoint(0.101, 0.101),
        CanvasPoint(0.102, 0.101),
        CanvasPoint(0.150, 0.150),
        CanvasPoint(0.151, 0.151),
        CanvasPoint(0.250, 0.250),
      ];

      final simplified = SharedCanvasModel.simplifyPoints(raw, minDistance: 0.01);
      expect(simplified.length, 3);
      expect(simplified.first, const CanvasPoint(0.100, 0.100));
      expect(simplified.last, const CanvasPoint(0.250, 0.250));
    });

    test('trimStrokesToBudget removes oldest strokes so JSON stays under 200 KB cap', () {
      final densePoints = List.generate(
        80,
        (i) => CanvasPoint(i / 80.0, (i % 10) / 10.0),
      );
      final manyStrokes = List.generate(
        180,
        (i) => CanvasStroke(
          id: 's_$i',
          authorUid: 'u1',
          colorHex: '#E91E63',
          strokeWidth: 4.0,
          points: densePoints,
        ),
      );

      final trimmed = SharedCanvasModel.trimStrokesToBudget(
        manyStrokes,
        maxBytes: SharedCanvasModel.maxStrokesPayloadBytes,
      );

      final encodedBytes = utf8
          .encode(jsonEncode(trimmed.map((s) => s.toMap()).toList()))
          .length;
      expect(encodedBytes, lessThanOrEqualTo(SharedCanvasModel.maxStrokesPayloadBytes));
      expect(trimmed.length, lessThan(manyStrokes.length));
      // Newest stroke is preserved
      expect(trimmed.last.id, 's_179');
    });

    test('SharedCanvasModel serializes and deserializes round-trip cleanly', () {
      final model = SharedCanvasModel(
        backgroundColorHex: '#FFF8F0',
        updatedByUid: 'u1',
        updatedByName: 'Gui',
        updatedAt: DateTime(2026, 11, 19, 12, 0),
        strokes: const [
          CanvasStroke(
            id: 's1',
            authorUid: 'u1',
            colorHex: '#000000',
            strokeWidth: 5.0,
            isEraser: false,
            points: [CanvasPoint(0.2, 0.3), CanvasPoint(0.8, 0.7)],
          ),
        ],
      );

      final restored = SharedCanvasModel.fromMap(model.toMap());
      expect(restored.backgroundColorHex, '#FFF8F0');
      expect(restored.strokes.length, 1);
      expect(restored.strokes.first.points.length, 2);
      expect(restored.updatedByName, 'Gui');
    });
  });

  group('Conditional WorkManager drawing snapshot fetch', () {
    test('shouldFetchDrawingSnapshot is true only when mode is drawing and revision incremented', () {
      const drawingRev2 = ActivityStateModel(
        drawingWidgetRevision: 2,
        noteWidgetMode: ActivityStateModel.widgetModeDrawing,
      );
      expect(
        BackgroundSyncService.shouldFetchDrawingSnapshot(
          state: drawingRev2,
          lastAppliedRevision: 1,
        ),
        isTrue,
      );
      expect(
        BackgroundSyncService.shouldFetchDrawingSnapshot(
          state: drawingRev2,
          lastAppliedRevision: 2,
        ),
        isFalse,
      );

      const noteMode = ActivityStateModel(
        drawingWidgetRevision: 3,
        noteWidgetMode: ActivityStateModel.widgetModeNote,
      );
      expect(
        BackgroundSyncService.shouldFetchDrawingSnapshot(
          state: noteMode,
          lastAppliedRevision: 1,
        ),
        isFalse,
      );
    });
  });
}
