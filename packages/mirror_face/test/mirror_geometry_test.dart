import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_face/mirror_face.dart';

void main() {
  const screen = Size(390, 844);

  group('canvasBoxFor', () {
    test('is tight (screen + pad) at the default state', () {
      final box = MirrorGeometry.canvasBoxFor(screen, 0, 90);
      expect(box.width, closeTo(screen.width + 2, 0.01));
      expect(box.height, closeTo(screen.height + 2, 0.01));
    });

    test('grows under rotation but never beyond the diagonal', () {
      final box = MirrorGeometry.canvasBoxFor(screen, 45, 90);
      final diagonal = sqrt(pow(screen.width, 2) + pow(screen.height, 2));
      // At 45° the bounding box is (w+h)/√2 square (+pad).
      expect(box.width,
          closeTo((screen.width + screen.height) / sqrt2 + 2, 0.5));
      expect(box.width, lessThanOrEqualTo(diagonal + 3));
      expect(box.height, lessThanOrEqualTo(diagonal + 3));
    });
  });

  group('coverFit', () {
    test('covers the box preserving aspect', () {
      for (final aspect in [9 / 16, 3 / 4]) {
        for (final box in [const Size(390, 844), const Size(900, 500)]) {
          final fit = MirrorGeometry.coverFit(box, aspect);
          expect(fit.width, greaterThanOrEqualTo(box.width - 0.01));
          expect(fit.height, greaterThanOrEqualTo(box.height - 0.01));
          expect(fit.width / fit.height, closeTo(aspect, 0.001));
        }
      }
    });
  });

  test('direct and reflected halves cover the screen for all angle combos',
      () {
    // Screen sample points (centered coordinates): corners and edge midpoints
    // are the extremes of the convex screen rect.
    final samples = <Offset>[
      for (final sx in [-1.0, 0.0, 1.0])
        for (final sy in [-1.0, 0.0, 1.0])
          Offset(sx * screen.width / 2, sy * screen.height / 2),
    ];

    for (var rotDeg = 0; rotDeg < 360; rotDeg += 15) {
      for (var axisDeg = 0; axisDeg < 180; axisDeg += 15) {
        for (final aspect in [9 / 16, 3 / 4]) {
          final box = MirrorGeometry.canvasBoxFor(
              screen, rotDeg.toDouble(), axisDeg.toDouble());
          final cam = MirrorGeometry.coverFit(box, aspect);

          final rot = rotDeg * pi / 180.0;
          final theta = axisDeg * pi / 180.0;
          final cos2t = cos(2 * theta);
          final sin2t = sin(2 * theta);

          for (final p in samples) {
            // Screen point in canvas-local coordinates (canvas is rotated by
            // +rot on screen, so map back by −rot).
            final q = Offset(
              p.dx * cos(rot) + p.dy * sin(rot),
              -p.dx * sin(rot) + p.dy * cos(rot),
            );
            // Reflection of q across the axis line through the centre.
            final r = Offset(
              q.dx * cos2t + q.dy * sin2t,
              q.dx * sin2t - q.dy * cos2t,
            );
            for (final pt in [q, r]) {
              expect(pt.dx.abs(), lessThanOrEqualTo(cam.width / 2 + 1.5),
                  reason: 'rot=$rotDeg axis=$axisDeg aspect=$aspect pt=$pt');
              expect(pt.dy.abs(), lessThanOrEqualTo(cam.height / 2 + 1.5),
                  reason: 'rot=$rotDeg axis=$axisDeg aspect=$aspect pt=$pt');
            }
          }
        }
      }
    }
  });
}
