import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:couple_app/core/theme/app_theme.dart';

/// Represents a single vector stroke drawn on a sticky note canvas.
class DoodleStroke {
  final int colorValue;
  final double strokeWidth;
  final List<Offset> points; // Normalized 0..1 coordinates

  const DoodleStroke({
    required this.colorValue,
    required this.strokeWidth,
    required this.points,
  });

  Map<String, dynamic> toJson() => {
        'c': colorValue,
        'w': strokeWidth,
        'p': points
            .map((pt) => [
                  (pt.dx * 1000).round() / 1000,
                  (pt.dy * 1000).round() / 1000,
                ])
            .toList(),
      };

  factory DoodleStroke.fromJson(Map<String, dynamic> json) {
    final rawPts = (json['p'] as List<dynamic>?) ?? const [];
    return DoodleStroke(
      colorValue: (json['c'] as num?)?.toInt() ?? 0xFFD84B6B,
      strokeWidth: (json['w'] as num?)?.toDouble() ?? 4.0,
      points: rawPts.map((pair) {
        final list = pair as List<dynamic>;
        return Offset(
          (list[0] as num).toDouble(),
          (list[1] as num).toDouble(),
        );
      }).toList(),
    );
  }

  static String encodeStrokes(List<DoodleStroke> strokes) {
    return jsonEncode(strokes.map((s) => s.toJson()).toList());
  }

  static List<DoodleStroke> decodeStrokes(String? rawJson) {
    if (rawJson == null || rawJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawJson) as List<dynamic>;
      return decoded
          .map((item) => DoodleStroke.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Renders saved [DoodleStroke] items inside a sticky note card.
class DoodleDisplayBox extends StatelessWidget {
  final String drawingDataJson;
  final double height;

  const DoodleDisplayBox({
    super.key,
    required this.drawingDataJson,
    this.height = 95,
  });

  @override
  Widget build(BuildContext context) {
    final strokes = DoodleStroke.decodeStrokes(drawingDataJson);
    if (strokes.isEmpty) return const SizedBox.shrink();

    return Container(
      height: height,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4A342E).withValues(alpha: 0.14),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _DoodlePainter(strokes: strokes),
        ),
      ),
    );
  }
}

/// Interactive drawing canvas used inside the Note Editor modal ("Desenho na Tela 🎨").
class InteractiveDoodlePad extends StatefulWidget {
  final String? initialJson;
  final ValueChanged<String?> onChanged;

  const InteractiveDoodlePad({
    super.key,
    this.initialJson,
    required this.onChanged,
  });

  @override
  State<InteractiveDoodlePad> createState() => _InteractiveDoodlePadState();
}

class _InteractiveDoodlePadState extends State<InteractiveDoodlePad> {
  late List<DoodleStroke> _strokes;
  List<Offset> _activePoints = [];
  int _selectedColor = 0xFFD84B6B;
  double _strokeWidth = 4.0;

  static const List<int> _palette = [
    0xFFD84B6B, // Rose
    0xFF1E293B, // Ink Dark
    0xFF7E22CE, // Purple
    0xFFE11D48, // Crimson Heart
    0xFF059669, // Emerald
    0xFFD97706, // Amber
  ];

  @override
  void initState() {
    super.initState();
    _strokes = List<DoodleStroke>.from(
      DoodleStroke.decodeStrokes(widget.initialJson),
    );
  }

  void _notifyParent() {
    if (_strokes.isEmpty) {
      widget.onChanged(null);
    } else {
      widget.onChanged(DoodleStroke.encodeStrokes(_strokes));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ..._palette.map((colorVal) {
              final isSel = _selectedColor == colorVal;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorVal),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Color(colorVal),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: Color(colorVal).withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
            const Spacer(),
            if (_strokes.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() => _strokes.clear());
                  _notifyParent();
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Limpar Desenho'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 160.0;
            return GestureDetector(
              onPanStart: (details) {
                final pt = Offset(
                  (details.localPosition.dx / width).clamp(0.0, 1.0),
                  (details.localPosition.dy / height).clamp(0.0, 1.0),
                );
                setState(() {
                  _activePoints = [pt];
                });
              },
              onPanUpdate: (details) {
                final pt = Offset(
                  (details.localPosition.dx / width).clamp(0.0, 1.0),
                  (details.localPosition.dy / height).clamp(0.0, 1.0),
                );
                setState(() {
                  _activePoints = [..._activePoints, pt];
                });
              },
              onPanEnd: (_) {
                if (_activePoints.isNotEmpty) {
                  setState(() {
                    _strokes.add(
                      DoodleStroke(
                        colorValue: _selectedColor,
                        strokeWidth: _strokeWidth,
                        points: _activePoints,
                      ),
                    );
                    _activePoints = [];
                  });
                  _notifyParent();
                }
              },
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryRose.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    if (_strokes.isEmpty && _activePoints.isEmpty)
                      Center(
                        child: Text(
                          'Desenhe um coração ou recado com o dedo aqui ✍️💕',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CustomPaint(
                        size: Size(width, height),
                        painter: _DoodlePainter(
                          strokes: [
                            ..._strokes,
                            if (_activePoints.isNotEmpty)
                              DoodleStroke(
                                colorValue: _selectedColor,
                                strokeWidth: _strokeWidth,
                                points: _activePoints,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final List<DoodleStroke> strokes;

  const _DoodlePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = Color(stroke.colorValue)
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        final pt = Offset(
          stroke.points.first.dx * size.width,
          stroke.points.first.dy * size.height,
        );
        canvas.drawCircle(pt, stroke.strokeWidth / 2, paint);
        continue;
      }

      final path = Path();
      path.moveTo(
        stroke.points.first.dx * size.width,
        stroke.points.first.dy * size.height,
      );
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(
          stroke.points[i].dx * size.width,
          stroke.points[i].dy * size.height,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => true;
}

/// Interactive Scratch Card ("Raspadinha do Amor ✨") dialog & overlay.
class ScratchCardRevealDialog extends StatefulWidget {
  final String title;
  final String secretContent;
  final String authorName;
  final String? drawingDataJson;
  final VoidCallback onRevealed;

  const ScratchCardRevealDialog({
    super.key,
    required this.title,
    required this.secretContent,
    required this.authorName,
    this.drawingDataJson,
    required this.onRevealed,
  });

  @override
  State<ScratchCardRevealDialog> createState() =>
      _ScratchCardRevealDialogState();
}

class _ScratchCardRevealDialogState extends State<ScratchCardRevealDialog> {
  final List<Offset> _scratchedPoints = [];
  bool _isFullyRevealed = false;

  void _addScratchPoint(Offset localPos) {
    if (_isFullyRevealed) return;
    setState(() {
      _scratchedPoints.add(localPos);
      if (_scratchedPoints.length >= 38) {
        _isFullyRevealed = true;
      }
    });
    if (_isFullyRevealed) {
      HapticFeedback.heavyImpact();
      widget.onRevealed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Raspadinha do Amor',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: context.textPrimary,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isFullyRevealed
                  ? 'Mensagem secreta de ${widget.authorName} revelada! 💕'
                  : 'Passe o dedo sobre a camada dourada abaixo para raspar e revelar o recado secreto!',
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 220,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Underlying secret content
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: const Color(0xFFFFF0F3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF8B263E),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.secretContent,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4A1525),
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if ((widget.drawingDataJson ?? '')
                                        .isNotEmpty)
                                      DoodleDisplayBox(
                                        drawingDataJson:
                                            widget.drawingDataJson!,
                                        height: 80,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Foil Scratch Layer
                    if (!_isFullyRevealed)
                      GestureDetector(
                        onPanStart: (d) => _addScratchPoint(d.localPosition),
                        onPanUpdate: (d) => _addScratchPoint(d.localPosition),
                        child: CustomPaint(
                          painter: _ScratchFoilPainter(
                            scratchedPoints: _scratchedPoints,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isFullyRevealed)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _isFullyRevealed = true);
                  widget.onRevealed();
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Raspar Tudo Agora ✨'),
              )
            else
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryRose,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.favorite_rounded),
                label: const Text('Amei! 💕'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScratchFoilPainter extends CustomPainter {
  final List<Offset> scratchedPoints;

  const _ScratchFoilPainter({required this.scratchedPoints});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    // Rose-gold metallic foil background
    final foilPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFE29587),
          Color(0xFFD66D75),
          Color(0xFFF3C6B8),
          Color(0xFFC96480),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, foilPaint);

    // Foil prompt label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '✨ RASPE AQUI COM O DEDO ✨\nRecado Secreto de Amor 💌',
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          height: 1.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 24);

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    // Erase scratched strokes using BlendMode.clear
    final erasePaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (scratchedPoints.isNotEmpty) {
      final path = Path()
        ..moveTo(scratchedPoints.first.dx, scratchedPoints.first.dy);
      for (final pt in scratchedPoints) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, erasePaint);
      for (final pt in scratchedPoints) {
        canvas.drawCircle(
          pt,
          19,
          Paint()..blendMode = BlendMode.clear,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScratchFoilPainter oldDelegate) => true;
}
