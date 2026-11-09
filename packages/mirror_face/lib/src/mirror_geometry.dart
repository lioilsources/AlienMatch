import 'dart:math';
import 'dart:ui';

/// Shared geometry for the mirror composition, used by both the live preview
/// widgets and the offline photo compositor so that saved photos match the
/// on-screen framing exactly.
abstract final class MirrorGeometry {
  /// Safety margin against hairline gaps from float rounding at box edges.
  static const double _pad = 2.0;

  /// Canvas size needed so the composition covers the full [screen] at
  /// rotation [rotationDeg] — in the direct half AND in the half reflected
  /// across the mirror axis at [mirrorAxisDeg].
  ///
  /// The direct half needs the axis-aligned bounding box of the screen
  /// rotated by rotationDeg. The reflected half shows the camera reflected
  /// across the axis; the screen region mapped through that reflection is the
  /// screen rect rotated by (2·mirrorAxisDeg + rotationDeg), so the camera
  /// must contain that bounding box too. At the default state (vertical
  /// axis, no rotation) both boxes collapse to the screen itself, giving the
  /// widest possible framing.
  static Size canvasBoxFor(Size screen, double rotationDeg, double mirrorAxisDeg) {
    final direct = _rotatedBoundingBox(screen, rotationDeg);
    final reflected = _rotatedBoundingBox(screen, 2 * mirrorAxisDeg + rotationDeg);
    return Size(
      max(direct.width, reflected.width) + _pad,
      max(direct.height, reflected.height) + _pad,
    );
  }

  static Size _rotatedBoundingBox(Size size, double angleDeg) {
    final rad = angleDeg * pi / 180.0;
    final c = cos(rad).abs();
    final s = sin(rad).abs();
    return Size(
      size.width * c + size.height * s,
      size.width * s + size.height * c,
    );
  }

  /// Cover-fits a portrait camera image of aspect [portraitAspect] (w/h)
  /// over [box], returning the displayed size (≥ box in both dimensions).
  static Size coverFit(Size box, double portraitAspect) {
    if (box.width / box.height > portraitAspect) {
      return Size(box.width, box.width / portraitAspect);
    }
    return Size(box.height * portraitAspect, box.height);
  }

  /// Path covering the half-plane divided by a line through the centre of
  /// [size] at [theta] radians from horizontal. [left] = true keeps the left
  /// side relative to the axis direction vector.
  static Path axisHalfPlanePath(Size size, double theta, bool left) {
    final center = Offset(size.width / 2, size.height / 2);
    final axisDir = Offset(cos(theta), sin(theta));
    // Left-normal: 90° CCW from axisDir.
    final leftNormal = Offset(-sin(theta), cos(theta));
    final sign = left ? 1.0 : -1.0;
    final far = size.longestSide * 2;

    final p1 = center + axisDir * far;
    final p2 = center - axisDir * far;
    final p3 = p2 + leftNormal * sign * far;
    final p4 = p1 + leftNormal * sign * far;

    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
  }
}
