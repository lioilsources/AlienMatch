import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../l10n/app_localizations.dart';

/// Fixed 8-colour palette; the server stores only the index.
const inkPalette = [
  Color(0xFFF5F2FF),
  Color(0xFF7CF5C8),
  Color(0xFFFFC857),
  Color(0xFFFF6B9A),
  Color(0xFF8FD3FF),
  Color(0xFFB69CFF),
  Color(0xFFFF8A4C),
  Color(0xFF2B2440),
];

/// Emoji for image presets (placeholders until the illustrated set exists).
const presetEmoji = {
  'heart': '❤️',
  'ufo': '🛸',
  'coffee': '☕',
  'tea': '🍵',
  'wine': '🍷',
  'beer': '🍺',
  'star': '⭐',
  'wave': '👋',
  'rocket': '🚀',
  'hug': '🤗',
  'flower': '🌸',
  'fire': '🔥',
};
const gentlePresets = ['ufo', 'coffee', 'tea', 'star', 'wave', 'hug', 'flower'];

class InkPainter extends CustomPainter {
  InkPainter(this.ink);
  final InkDrawing ink;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in ink.strokes) {
      final paint = Paint()
        ..color = inkPalette[s.color.clamp(0, inkPalette.length - 1)]
        ..strokeWidth = s.width * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i + 1 < s.points.length; i += 2) {
        final o = Offset(
          s.points[i] * size.width,
          s.points[i + 1] * size.height,
        );
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      if (s.points.length == 2) {
        path.lineTo(s.points[0] * size.width + 0.1, s.points[1] * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant InkPainter old) => old.ink != ink;
}

/// Full-screen finger/stylus pad. There is no keyboard anywhere on a wall.
class InkPad extends StatefulWidget {
  const InkPad({super.key});

  @override
  State<InkPad> createState() => _InkPadState();
}

class _InkPadState extends State<InkPad> {
  final strokes = <({int color, List<Offset> pts})>[];
  int color = 1;
  Size box = Size.zero;

  InkDrawing? _normalized() {
    if (strokes.isEmpty || box.isEmpty) return null;
    final all = [for (final s in strokes) ...s.pts];
    var l = all.first.dx, t = all.first.dy, r = l, b = t;
    for (final p in all) {
      l = p.dx < l ? p.dx : l;
      t = p.dy < t ? p.dy : t;
      r = p.dx > r ? p.dx : r;
      b = p.dy > b ? p.dy : b;
    }
    const pad = 12.0;
    l -= pad;
    t -= pad;
    r += pad;
    b += pad;
    final w = r - l, h = b - t;
    double nx(double v) => ((v - l) / w).clamp(0.0, 1.0);
    double ny(double v) => ((v - t) / h).clamp(0.0, 1.0);
    // Thin points so even long scribbles stay under the server limit.
    final step = all.length > 5000 ? (all.length / 5000).ceil() : 1;
    return InkDrawing(
      aspect: (w / h).clamp(0.1, 10.0),
      strokes: [
        for (final s in strokes)
          InkStroke(
            color: s.color,
            width: (6 / w).clamp(0.002, 0.2),
            points: [
              for (var i = 0; i < s.pts.length; i += step) ...[
                nx(s.pts[i].dx),
                ny(s.pts[i].dy),
              ],
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final preview = InkDrawing(
      aspect: 1,
      strokes: [
        for (final s in strokes)
          if (box.isEmpty)
            InkStroke(color: s.color, width: 0.01, points: const [])
          else
            InkStroke(
              color: s.color,
              width: 6 / box.width,
              points: [
                for (final p in s.pts) ...[p.dx / box.width, p.dy / box.height],
              ],
            ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.draw),
        actions: [
          IconButton(
            tooltip: l.undo,
            onPressed: strokes.isEmpty
                ? null
                : () => setState(strokes.removeLast),
            icon: const Icon(Icons.undo),
          ),
          FilledButton(
            key: const Key('stickIt'),
            onPressed: strokes.isEmpty
                ? null
                : () => Navigator.pop(context, _normalized()),
            child: Text(l.stick),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          box = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            key: const Key('inkCanvas'),
            onPanStart: (d) => setState(
              () => strokes.add((color: color, pts: [d.localPosition])),
            ),
            onPanUpdate: (d) =>
                setState(() => strokes.last.pts.add(d.localPosition)),
            child: CustomPaint(
              painter: InkPainter(preview),
              size: Size.infinite,
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < inkPalette.length; i++)
                GestureDetector(
                  onTap: () => setState(() => color = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: inkPalette[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == color ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
