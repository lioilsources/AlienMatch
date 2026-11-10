import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'face_anchor.dart';
import 'filtered_mirror_canvas.dart';
import 'mirror_filter.dart';
import 'mirror_geometry.dart';
import 'mirror_side.dart';
import 'shader_cache.dart';

/// The MirrorBooth live view for a box of [size]: mirror composition with a
/// free mirror axis, whole-image rotation and a filter shader, plus the two
/// rings that steer them. Dragging around the inner ring turns the mirror
/// axis, dragging anywhere else rotates the image.
///
/// Stateless about the values: the caller owns [rotationDeg] and
/// [mirrorAxisDeg] and gets deltas back, so the still compositor
/// ([composeMirrorPhoto]) can reproduce exactly this framing with [size] as
/// its screen size.
class MirrorStage extends StatefulWidget {
  const MirrorStage({
    super.key,
    required this.controller,
    required this.size,
    required this.side,
    required this.filter,
    required this.shaderCache,
    required this.rotationDeg,
    required this.mirrorAxisDeg,
    required this.onRotate,
    required this.onMirrorAxis,
    this.faceAnchor = FaceAnchor.defaults,
  });

  final CameraController controller;
  final Size size;
  final MirrorSide side;
  final MirrorFilter filter;
  final ShaderCache shaderCache;
  final double rotationDeg;
  final double mirrorAxisDeg;
  final ValueChanged<double> onRotate;
  final ValueChanged<double> onMirrorAxis;
  final FaceAnchor faceAnchor;

  /// Ring diameters as fractions of the shorter side (same as MirrorBooth).
  static const double outerRingFrac = 0.88;
  static const double innerRingFrac = 0.44;

  @override
  State<MirrorStage> createState() => _MirrorStageState();
}

class _MirrorStageState extends State<MirrorStage> {
  static const double _deadZone = 24.0;
  double _lastAngle = 0;
  bool _inner = false;

  Offset get _center => widget.size.center(Offset.zero);

  void _start(DragStartDetails d) {
    final v = d.localPosition - _center;
    final innerRadius = widget.size.shortestSide * MirrorStage.innerRingFrac / 2;
    _inner = v.distance <= innerRadius + 16.0;
    _lastAngle = atan2(v.dy, v.dx);
  }

  void _update(DragUpdateDetails d) {
    final v = d.localPosition - _center;
    if (v.distance < _deadZone) return;
    final angle = atan2(v.dy, v.dx);
    var delta = angle - _lastAngle;
    if (delta > pi) delta -= 2 * pi;
    if (delta < -pi) delta += 2 * pi;
    _lastAngle = angle;
    final deg = delta * 180.0 / pi;
    (_inner ? widget.onMirrorAxis : widget.onRotate)(deg);
  }

  @override
  Widget build(BuildContext context) {
    final box = MirrorGeometry.canvasBoxFor(
      widget.size,
      widget.rotationDeg,
      widget.mirrorAxisDeg,
    );
    final ring = widget.size.shortestSide;
    return SizedBox.fromSize(
      size: widget.size,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.rotate(
                angle: widget.rotationDeg * pi / 180.0,
                child: SizedBox(
                  width: box.width,
                  height: box.height,
                  child: RepaintBoundary(
                    child: FilteredMirrorCanvas(
                      controller: widget.controller,
                      side: widget.side,
                      filter: widget.filter,
                      shaderCache: widget.shaderCache,
                      mirrorAxisDeg: widget.mirrorAxisDeg,
                      faceAnchor: widget.faceAnchor,
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: SizedBox.square(
                  dimension: ring * MirrorStage.outerRingFrac,
                  child: CustomPaint(
                    painter: RotationRingPainter(widget.rotationDeg),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: SizedBox.square(
                  dimension: ring * MirrorStage.innerRingFrac,
                  child: CustomPaint(
                    painter: MirrorAxisRingPainter(widget.mirrorAxisDeg),
                  ),
                ),
              ),
            ),
            GestureDetector(
              key: const Key('mirrorStageGestures'),
              behavior: HitTestBehavior.translucent,
              onPanStart: _start,
              onPanUpdate: _update,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed inner ring with the mirror axis drawn through the centre.
class MirrorAxisRingPainter extends CustomPainter {
  const MirrorAxisRingPainter(this.mirrorAxisDeg);
  final double mirrorAxisDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashCount = 48;
    const sweep = 2 * pi / dashCount;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, ringPaint);
    }
    final theta = mirrorAxisDeg * pi / 180.0;
    final dir = Offset(cos(theta), sin(theta));
    final len = radius - 4.0;
    canvas.drawLine(
      center - dir * len,
      center + dir * len,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      2.0,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(MirrorAxisRingPainter old) =>
      old.mirrorAxisDeg != mirrorAxisDeg;
}

/// Outer ring with 30° ticks and a dot marking where "up" went.
class RotationRingPainter extends CustomPainter {
  const RotationRingPainter(this.rotationDeg);
  final double rotationDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );
    final tick = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = (i * 30 - rotationDeg) * pi / 180.0;
      final inner = radius - (i % 3 == 0 ? 14.0 : 8.0);
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(center + d * inner, center + d * (radius - 2), tick);
    }
    final dot = -rotationDeg * pi / 180.0 - pi / 2;
    canvas.drawCircle(
      center + Offset(cos(dot), sin(dot)) * (radius - 8),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(RotationRingPainter old) => old.rotationDeg != rotationDeg;
}

/// Normalises an angle in degrees to [0, 360).
double normalizeDeg(double deg) {
  final n = deg % 360.0;
  return n < 0 ? n + 360.0 : n;
}
