import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog that renders one or more WKT geometries on a shared canvas.
/// Supports pan (drag), zoom (scroll wheel / +/- buttons) and window resize.
class GeometryPreviewDialog extends StatefulWidget {
  final List<String> wkts;
  const GeometryPreviewDialog({super.key, required this.wkts});

  @override
  State<GeometryPreviewDialog> createState() => _GeometryPreviewDialogState();
}

class _GeometryPreviewDialogState extends State<GeometryPreviewDialog> {
  static const _minW = 320.0;
  static const _minH = 280.0;
  static const _handleSize = 8.0;

  double _w = 560.0;
  double _h = 560.0;
  double _strokePx = 1.8;

  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.wkts.length == 1) {
      return widget.wkts.first.split('(').first.trim().toUpperCase();
    }
    return '${widget.wkts.length} geometries';
  }

  void _zoom(double factor) {
    final cx = _w / 2;
    final cy = _h / 2;
    final zoom = Matrix4.translationValues(cx, cy, 0)
      ..multiply(Matrix4.diagonal3Values(factor, factor, 1))
      ..multiply(Matrix4.translationValues(-cx, -cy, 0));
    _controller.value = zoom * _controller.value;
  }

  void _resetView() => _controller.value = Matrix4.identity();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: _w,
        height: _h,
        child: Stack(
          children: [
            // ── Main content ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black38,
                      blurRadius: 16,
                      offset: Offset(0, 6))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    _header(context),
                    Expanded(child: _canvas()),
                    _wktBox(),
                    _footer(context),
                  ],
                ),
              ),
            ),

            // ── Resize: right edge ─────────────────────────────────────────
            Positioned(
              right: 0,
              top: 24,
              bottom: 24,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => setState(
                      () => _w = (_w + d.delta.dx).clamp(_minW, 1600.0)),
                  child: const SizedBox(width: _handleSize),
                ),
              ),
            ),

            // ── Resize: bottom edge ────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 24,
              right: 24,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (d) => setState(
                      () => _h = (_h + d.delta.dy).clamp(_minH, 1200.0)),
                  child: const SizedBox(height: _handleSize),
                ),
              ),
            ),

            // ── Resize: bottom-right corner ────────────────────────────────
            Positioned(
              right: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => setState(() {
                    _w = (_w + d.delta.dx).clamp(_minW, 1600.0);
                    _h = (_h + d.delta.dy).clamp(_minH, 1200.0);
                  }),
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.only(right: 3, bottom: 3),
                    child: const Icon(Icons.drag_indicator,
                        size: 14, color: Color(0xFFCCCCDD)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1565C0),
      child: Row(
        children: [
          const Icon(Icons.place, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
            color: Colors.white,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;
        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _controller,
              minScale: 0.05,
              maxScale: 200.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (_, _) {
                  final invScale =
                      1.0 / _controller.value.getMaxScaleOnAxis().clamp(0.001, 1e6);
                  return SizedBox(
                    width: cw,
                    height: ch,
                    child: CustomPaint(
                      painter: _GeomPainter(widget.wkts,
                          invScale: invScale, strokePx: _strokePx),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  _ZoomButton(Icons.add, () => _zoom(1.4)),
                  const SizedBox(height: 4),
                  _ZoomButton(Icons.remove, () => _zoom(1 / 1.4)),
                  const SizedBox(height: 4),
                  _ZoomButton(Icons.fit_screen, _resetView),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _wktBox() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFEEF2FF),
      child: SingleChildScrollView(
        child: SelectableText(
          widget.wkts.join('\n'),
          style: const TextStyle(
              fontSize: 11, fontFamily: 'monospace', color: Color(0xFF424242)),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.line_weight, size: 14, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 2),
          SizedBox(
            width: 90,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: _strokePx,
                min: 0.5,
                max: 6.0,
                onChanged: (v) => setState(() => _strokePx = v),
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: widget.wkts.join('\n'))),
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy WKT', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0)),
            child: const Text('Close', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── Zoom button ───────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _ZoomButton(this.icon, this.onPressed);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1565C0),
          elevation: 2,
          shape: const CircleBorder(),
        ),
        child: Icon(icon, size: 15),
      ),
    );
  }
}

// ── Geometry painter ──────────────────────────────────────────────────────────

class _GeomPainter extends CustomPainter {
  final List<String> wkts;
  final double invScale;
  final double strokePx;
  _GeomPainter(this.wkts, {this.invScale = 1.0, this.strokePx = 1.8});

  @override
  void paint(Canvas canvas, Size size) {
    final allEntries = <({List<List<Offset>> rings, String type})>[];
    for (final wkt in wkts) {
      final rings = _extractRings(wkt);
      if (rings.isNotEmpty) {
        allEntries.add((rings: rings, type: wkt.toUpperCase()));
      }
    }
    if (allEntries.isEmpty) return;

    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final e in allEntries) {
      for (final ring in e.rings) {
        for (final p in ring) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
      }
    }
    if (maxX - minX < 1e-9) { minX -= 1; maxX += 1; }
    if (maxY - minY < 1e-9) { minY -= 1; maxY += 1; }

    const pad = 28.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final sc = (w / (maxX - minX)).clamp(0.0, h / (maxY - minY));
    final drawW = (maxX - minX) * sc;
    final drawH = (maxY - minY) * sc;
    final ox = pad + (w - drawW) / 2;
    final oy = pad + (h - drawH) / 2;

    Offset proj(Offset p) => Offset(
          (p.dx - minX) * sc + ox,
          size.height - ((p.dy - minY) * sc + oy),
        );

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF0F4FA));
    final gridPaint = Paint()
      ..color = const Color(0xFFD8DFF0)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 6; i++) {
      canvas.drawLine(Offset(size.width * i / 6, 0),
          Offset(size.width * i / 6, size.height), gridPaint);
      canvas.drawLine(Offset(0, size.height * i / 6),
          Offset(size.width, size.height * i / 6), gridPaint);
    }

    for (final e in allEntries) {
      _drawGeom(canvas, e.rings, e.type, proj);
    }
  }

  void _drawGeom(Canvas canvas, List<List<Offset>> rings, String type,
      Offset Function(Offset) proj) {
    final isPoint = RegExp(r'^\s*MULTI?POINT').hasMatch(type);
    final isPoly = type.contains('POLYGON');

    final sw = strokePx * invScale;
    final fill = Paint()
      ..color = const Color(0x381565C0)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final dot = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.fill;

    if (isPoint) {
      final r = 5.0 * invScale;
      for (final ring in rings) {
        for (final p in ring) {
          canvas.drawCircle(proj(p), r, dot);
          canvas.drawCircle(proj(p), r, stroke..strokeWidth = sw * 0.67);
        }
      }
    } else if (isPoly) {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final ring in rings) {
        if (ring.isEmpty) continue;
        final first = proj(ring.first);
        path.moveTo(first.dx, first.dy);
        for (int i = 1; i < ring.length; i++) {
          final c = proj(ring[i]);
          path.lineTo(c.dx, c.dy);
        }
        path.close();
      }
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke..strokeWidth = sw);
    } else {
      for (final ring in rings) {
        if (ring.isEmpty) continue;
        final path = Path();
        final first = proj(ring.first);
        path.moveTo(first.dx, first.dy);
        for (int i = 1; i < ring.length; i++) {
          path.lineTo(proj(ring[i]).dx, proj(ring[i]).dy);
        }
        canvas.drawPath(path, stroke);
      }
      final dotR = 2.5 * invScale;
      for (final ring in rings) {
        for (final p in ring) {
          canvas.drawCircle(proj(p), dotR, dot);
        }
      }
    }
  }

  List<List<Offset>> _extractRings(String wkt) {
    final rings = <List<Offset>>[];
    final pat = RegExp(r'\(([^()]+)\)');
    for (final m in pat.allMatches(wkt)) {
      final coords = <Offset>[];
      for (final pair in m.group(1)!.split(',')) {
        final parts = pair.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final x = double.tryParse(parts[0]);
          final y = double.tryParse(parts[1]);
          if (x != null && y != null) coords.add(Offset(x, y));
        }
      }
      if (coords.isNotEmpty) rings.add(coords);
    }
    return rings;
  }

  @override
  bool shouldRepaint(_GeomPainter old) =>
      old.wkts != wkts || old.invScale != invScale || old.strokePx != strokePx;
}
