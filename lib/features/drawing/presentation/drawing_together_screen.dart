import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:couple_app/core/l10n/app_strings.dart';
import 'package:couple_app/core/services/background_sync_service.dart';
import 'package:couple_app/core/theme/app_theme.dart';
import 'package:couple_app/features/auth/data/pairing_repository.dart';
import 'package:couple_app/features/drawing/data/shared_canvas_repository.dart';
import 'package:couple_app/features/drawing/domain/shared_canvas_model.dart';
import 'package:couple_app/features/widgets/widget_sync_service.dart';

/// Fullscreen realtime collaborative drawing screen ("Desenhar Juntos").
///
/// Features:
/// - Live Firestore sync on stroke end (`shared_canvas/current`, <= 200 KB)
/// - 10-color brush palette, 3 brush widths, eraser mode, Undo, Clear, 5 canvas backgrounds
/// - Pin directly to both partners' Android Home Screen `NoteGlanceWidget`
/// - Save as PNG wallpaper/image into Android Gallery via MediaStore
class DrawingTogetherScreen extends ConsumerStatefulWidget {
  final String coupleId;
  final String? currentUid;

  const DrawingTogetherScreen({
    super.key,
    required this.coupleId,
    this.currentUid,
  });

  @override
  ConsumerState<DrawingTogetherScreen> createState() =>
      _DrawingTogetherScreenState();
}

class _DrawingTogetherScreenState extends ConsumerState<DrawingTogetherScreen> {
  static const MethodChannel _deviceSettingsChannel =
      MethodChannel('com.personal.couple_app/device_settings');
  static const List<double> _brushWidths = [3.5, 7.0, 14.0];

  final Uuid _uuid = const Uuid();
  String _selectedColorHex = SharedCanvasModel.brushPaletteHex[1];
  double _selectedWidth = 7.0;
  bool _isEraser = false;
  bool _isPublishingWidget = false;
  bool _isSavingGallery = false;

  List<CanvasPoint> _activePoints = [];

  String _effectiveUid() {
    if (widget.currentUid != null && widget.currentUid!.isNotEmpty) {
      return widget.currentUid!;
    }
    return ref.watch(currentUserUidProvider).valueOrNull ??
        ref.read(pairingRepositoryProvider).currentUserUid ??
        '';
  }

  static Color _parseHex(String hex, {Color fallback = const Color(0xFFFFF9FB)}) {
    try {
      final clean = hex.trim().replaceFirst('#', '').replaceFirst('0x', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
      if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  /// Renders the normalized canvas strokes into a crisp square PNG (`512x512` for
  /// widgets or `1080x1080` for gallery wallpaper).
  Future<Uint8List?> _renderCanvasToPng(
    SharedCanvasModel canvasModel, {
    int sizePx = 512,
  }) async {
    final recorder = ui.PictureRecorder();
    final size = Size(sizePx.toDouble(), sizePx.toDouble());
    final canvas = Canvas(recorder, Offset.zero & size);

    final bgColor = _parseHex(canvasModel.backgroundColorHex);
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor);

    _paintStrokes(canvas, size, canvasModel.strokes, bgColor);

    final picture = recorder.endRecording();
    final image = await picture.toImage(sizePx, sizePx);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  static void _paintStrokes(
    Canvas canvas,
    Size size,
    List<CanvasStroke> strokes,
    Color bgColor,
  ) {
    final scaleFactor = size.width / 360.0;
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.isEraser ? bgColor : _parseHex(stroke.colorHex, fallback: Colors.black)
        ..strokeWidth = (stroke.strokeWidth * scaleFactor).clamp(1.5, 48.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        canvas.drawCircle(
          Offset(p.x * size.width, p.y * size.height),
          paint.strokeWidth / 2,
          Paint()..color = paint.color,
        );
        continue;
      }

      final path = Path();
      final first = stroke.points.first;
      path.moveTo(first.x * size.width, first.y * size.height);
      for (var i = 1; i < stroke.points.length; i++) {
        final pt = stroke.points[i];
        path.lineTo(pt.x * size.width, pt.y * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  Future<void> _sendToWidget(
    SharedCanvasModel canvasModel, {
    required String myUid,
    required String myName,
  }) async {
    if (_isPublishingWidget) return;
    final strings = AppStrings.of(context);
    setState(() => _isPublishingWidget = true);
    try {
      HapticFeedback.mediumImpact();
      Uint8List? pngBytes = await _renderCanvasToPng(canvasModel, sizePx: 512);
      if (pngBytes == null) throw Exception('Failed to render PNG');

      // Safety downscale if intricate drawing PNG exceeds ~100 KB raw (~133 KB Base64)
      if (pngBytes.length > 98 * 1024) {
        pngBytes = await _renderCanvasToPng(canvasModel, sizePx: 384);
      }
      if (pngBytes == null) throw Exception('Failed to render PNG');

      final rev = await ref
          .read(sharedCanvasRepositoryProvider)
          .publishWidgetSnapshot(
            widget.coupleId,
            pngBytes: pngBytes,
            actorUid: myUid,
            actorName: myName,
          );

      await WidgetSyncService.syncDrawingSnapshotToWidget(
        pngBytes: pngBytes,
        authorName: myName,
        isPortuguese: strings.isPortuguese,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(BackgroundSyncService.prefLastDrawingRevision, rev);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.drawingSentToWidgetToast),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${strings.isPortuguese ? 'Erro ao enviar para o widget:' : 'Failed to pin drawing:'} $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishingWidget = false);
    }
  }

  Future<void> _saveToGallery(SharedCanvasModel canvasModel) async {
    if (_isSavingGallery) return;
    final strings = AppStrings.of(context);
    setState(() => _isSavingGallery = true);
    try {
      HapticFeedback.lightImpact();
      final pngBytes = await _renderCanvasToPng(canvasModel, sizePx: 1080);
      if (pngBytes == null) throw Exception('Failed to export PNG');

      final ok = await _deviceSettingsChannel.invokeMethod<bool>(
        'saveImageToGallery',
        {
          'bytes': pngBytes,
          'fileName': 'couple_drawing_${DateTime.now().millisecondsSinceEpoch}.png',
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == true
                ? strings.drawingSavedGalleryToast
                : (strings.isPortuguese
                    ? 'Não foi possível salvar na galeria.'
                    : 'Could not save image to gallery.'),
          ),
          backgroundColor: ok == true ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingGallery = false);
    }
  }

  Future<void> _confirmClear(String myUid, String myName) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.drawingClearTitle),
        content: Text(strings.drawingClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.clearAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sharedCanvasRepositoryProvider).clearCanvas(
            widget.coupleId,
            actorUid: myUid,
            actorName: myName,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final myUid = _effectiveUid();
    final couple = ref.watch(coupleStreamProvider(widget.coupleId)).valueOrNull;
    final myName = couple?.getMyProfile(myUid)?.displayName ??
        (strings.isPortuguese ? 'Seu amor' : 'Partner');
    final canvasModel =
        ref.watch(sharedCanvasStreamProvider(widget.coupleId)).valueOrNull ??
            const SharedCanvasModel();
    final bgColor = _parseHex(canvasModel.backgroundColorHex);

    final activeStroke = _activePoints.isEmpty
        ? null
        : CanvasStroke(
            id: 'local_preview',
            authorUid: myUid,
            colorHex: _selectedColorHex,
            strokeWidth: _selectedWidth,
            isEraser: _isEraser,
            points: _activePoints,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.drawingTogetherTitle),
        actions: [
          IconButton(
            tooltip: strings.undoAction,
            icon: const Icon(Icons.undo_rounded),
            onPressed: canvasModel.strokes.isEmpty
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    ref.read(sharedCanvasRepositoryProvider).undoLastStroke(
                          widget.coupleId,
                          actorUid: myUid,
                          actorName: myName,
                        );
                  },
          ),
          IconButton(
            tooltip: strings.clearAction,
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: canvasModel.strokes.isEmpty
                ? null
                : () => _confirmClear(myUid, myName),
          ),
          IconButton(
            tooltip: strings.saveGalleryTooltip,
            icon: _isSavingGallery
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            onPressed: _isSavingGallery ? null : () => _saveToGallery(canvasModel),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Live attribution bar
            if (canvasModel.updatedByName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.brush_rounded,
                      size: 15,
                      color: AppTheme.primaryRose,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        strings.isPortuguese
                            ? 'Último traço por ${canvasModel.updatedByName} • Ao vivo'
                            : 'Last stroke by ${canvasModel.updatedByName} • Live',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Square/lockscreen-friendly fullscreen canvas area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final canvasSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppTheme.primaryRose.withValues(alpha: 0.35),
                                width: 2,
                              ),
                            ),
                            child: GestureDetector(
                              onPanStart: (details) {
                                final pos = details.localPosition;
                                final pt = CanvasPoint(
                                  (pos.dx / canvasSize.width).clamp(0.0, 1.0),
                                  (pos.dy / canvasSize.height).clamp(0.0, 1.0),
                                );
                                setState(() => _activePoints = [pt]);
                              },
                              onPanUpdate: (details) {
                                final pos = details.localPosition;
                                final pt = CanvasPoint(
                                  (pos.dx / canvasSize.width).clamp(0.0, 1.0),
                                  (pos.dy / canvasSize.height).clamp(0.0, 1.0),
                                );
                                setState(() => _activePoints = [..._activePoints, pt]);
                              },
                              onPanEnd: (_) async {
                                if (_activePoints.isEmpty) return;
                                final pts = List<CanvasPoint>.from(_activePoints);
                                setState(() => _activePoints = []);
                                final stroke = CanvasStroke(
                                  id: _uuid.v4().substring(0, 10),
                                  authorUid: myUid,
                                  colorHex: _selectedColorHex,
                                  strokeWidth: _selectedWidth,
                                  isEraser: _isEraser,
                                  points: pts,
                                );
                                await ref
                                    .read(sharedCanvasRepositoryProvider)
                                    .appendStroke(
                                      widget.coupleId,
                                      stroke: stroke,
                                      actorName: myName,
                                    );
                              },
                              child: CustomPaint(
                                size: canvasSize,
                                painter: _SharedCanvasPainter(
                                  strokes: [
                                    ...canvasModel.strokes,
                                    if (activeStroke != null) activeStroke,
                                  ],
                                  bgColor: bgColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Bottom tool dock
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: context.outlineColor)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 10-color palette row
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: SharedCanvasModel.brushPaletteHex.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (ctx, idx) {
                        final hex = SharedCanvasModel.brushPaletteHex[idx];
                        final selected = !_isEraser && _selectedColorHex == hex;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isEraser = false;
                              _selectedColorHex = hex;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _parseHex(hex),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppTheme.primaryRose
                                    : context.outlineColor,
                                width: selected ? 3 : 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Brush sizes + Eraser + Background swatches
                  Row(
                    children: [
                      // 3 Brush thickness buttons
                      ..._brushWidths.map((w) {
                        final active = !_isEraser && _selectedWidth == w;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              setState(() {
                                _isEraser = false;
                                _selectedWidth = w;
                              });
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppTheme.primaryRose.withValues(alpha: 0.16)
                                    : context.surfaceVariant,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: active
                                      ? AppTheme.primaryRose
                                      : Colors.transparent,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Container(
                                width: (w * 1.1).clamp(5.0, 16.0),
                                height: (w * 1.1).clamp(5.0, 16.0),
                                decoration: BoxDecoration(
                                  color: context.textPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Eraser toggle
                      FilterChip(
                        selected: _isEraser,
                        avatar: const Icon(Icons.auto_fix_normal_rounded, size: 16),
                        label: Text(
                          strings.eraserLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onSelected: (v) => setState(() => _isEraser = v),
                      ),
                      const Spacer(),
                      // Background color dots
                      ...SharedCanvasModel.backgroundPaletteHex.map((hex) {
                        final isBg = canvasModel.backgroundColorHex == hex;
                        return Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: GestureDetector(
                            onTap: () {
                              ref
                                  .read(sharedCanvasRepositoryProvider)
                                  .setBackgroundColor(
                                    widget.coupleId,
                                    colorHex: hex,
                                    actorUid: myUid,
                                    actorName: myName,
                                  );
                            },
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _parseHex(hex),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isBg
                                      ? AppTheme.primaryRose
                                      : context.outlineColor,
                                  width: isBg ? 2.5 : 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Primary CTA: Pin to Home Screen Widget on both phones
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryRose,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isPublishingWidget
                          ? null
                          : () => _sendToWidget(
                                canvasModel,
                                myUid: myUid,
                                myName: myName,
                              ),
                      icon: _isPublishingWidget
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.widgets_rounded),
                      label: Text(
                        strings.sendDrawingToWidgetBtn,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedCanvasPainter extends CustomPainter {
  final List<CanvasStroke> strokes;
  final Color bgColor;

  _SharedCanvasPainter({
    required this.strokes,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _DrawingTogetherScreenState._paintStrokes(canvas, size, strokes, bgColor);
  }

  @override
  bool shouldRepaint(covariant _SharedCanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes || oldDelegate.bgColor != bgColor;
  }
}
