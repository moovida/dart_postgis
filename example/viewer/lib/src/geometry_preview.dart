import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog that renders one or more WKT geometries on a shared canvas.
class GeometryPreviewDialog extends StatelessWidget {
  final List<String> wkts;
  const GeometryPreviewDialog({super.key, required this.wkts});

  String get _title {
    if (wkts.length == 1) return wkts.first.split('(').first.trim().toUpperCase();
    return '${wkts.length} geometries';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            _canvas(),
            _wktBox(),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1565C0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
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
    return Container(
      height: 360,
      color: const Color(0xFFF0F4FA),
      child: CustomPaint(
        painter: _GeomPainter(wkts),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _wktBox() {
    final text = wkts.join('\n');
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFEEF2FF),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: Color(0xFF424242),
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: wkts.join('\n'))),
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

// ── Painter ──────────────────────────────────────────────────────────────────

class _GeomPainter extends CustomPainter {
  final List<String> wkts;
  _GeomPainter(this.wkts);

  @override
  void paint(Canvas canvas, Size size) {
    // Collect all rings across all WKTs, tagged with their geometry type
    final allEntries = <({List<List<Offset>> rings, String type})>[];
    for (final wkt in wkts) {
      final rings = _extractRings(wkt);
      if (rings.isNotEmpty) allEntries.add((rings: rings, type: wkt.toUpperCase()));
    }
    if (allEntries.isEmpty) return;

    // Combined bounding box
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

    // Draw each geometry
    for (final e in allEntries) {
      _drawGeom(canvas, e.rings, e.type, proj);
    }
  }

  void _drawGeom(Canvas canvas, List<List<Offset>> rings, String type,
      Offset Function(Offset) proj) {
    final isPoint = RegExp(r'^\s*MULTI?POINT').hasMatch(type);
    final isPoly = type.contains('POLYGON');

    final fill = Paint()
      ..color = const Color(0x381565C0)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final dot = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.fill;

    if (isPoint) {
      for (final ring in rings) {
        for (final p in ring) {
          canvas.drawCircle(proj(p), 5, dot);
          canvas.drawCircle(proj(p), 5, stroke..strokeWidth = 1.2);
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
      canvas.drawPath(path, stroke..strokeWidth = 1.8);
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
      for (final ring in rings) {
        for (final p in ring) {
          canvas.drawCircle(proj(p), 2.5, dot);
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
  bool shouldRepaint(_GeomPainter old) => old.wkts != wkts;
}
