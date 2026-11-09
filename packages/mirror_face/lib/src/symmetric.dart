import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'mirror_side.dart';

/// Builds one symmetric face from a still: the [side] half is kept and
/// reflected across a vertical axis at [axisX] (0..1 of the still width).
///
/// The output is a square of at most [maxSize] px centred on the axis, so the
/// profile photo is always the "alien" face and never the original. The
/// caller owns [still] and the returned image.
///
/// [mirrorStillHorizontally]: front-camera stills come out unmirrored while
/// the preview is mirrored; pass true so the result matches what the user saw.
Future<ui.Image> symmetricVariant(
  ui.Image still,
  MirrorSide side, {
  double axisX = 0.5,
  bool mirrorStillHorizontally = false,
  int maxSize = 1024,
}) async {
  final w = still.width.toDouble();
  final h = still.height.toDouble();
  // Axis in source pixels, as the user saw it (after optional flip).
  final axisSeen = axisX.clamp(0.1, 0.9) * w;
  final axisSrc = mirrorStillHorizontally ? w - axisSeen : axisSeen;
  // Square crop: half-width limited by the distance to the nearer edge.
  final half = min(min(axisSeen, w - axisSeen), h / 2);
  final out = min(maxSize, (2 * half).round());

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..filterQuality = FilterQuality.high
    ..isAntiAlias = false;

  // The kept half as seen on screen: left = [axis-half, axis], right = [axis, axis+half].
  final keepLeft = side.isLeft;
  final top = (h - 2 * half) / 2;
  Rect srcRect;
  if (keepLeft != mirrorStillHorizontally) {
    srcRect = Rect.fromLTWH(axisSrc - half, top, half, 2 * half);
  } else {
    srcRect = Rect.fromLTWH(axisSrc, top, half, 2 * half);
  }
  final halfDst = out / 2;
  // Whether the source half must be flipped to appear as the kept half on screen.
  final flipKept = mirrorStillHorizontally;

  void drawHalf(Rect dst, bool flip) {
    canvas.save();
    if (flip) {
      canvas.translate(dst.center.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-dst.center.dx, 0);
    }
    canvas.drawImageRect(still, srcRect, dst, paint);
    canvas.restore();
  }

  final leftDst = Rect.fromLTWH(0, 0, halfDst, out.toDouble());
  final rightDst = Rect.fromLTWH(halfDst, 0, halfDst, out.toDouble());
  if (keepLeft) {
    drawHalf(leftDst, flipKept);
    drawHalf(rightDst, !flipKept);
  } else {
    drawHalf(rightDst, flipKept);
    drawHalf(leftDst, !flipKept);
  }
  final picture = recorder.endRecording();
  final img = await picture.toImage(out, out);
  picture.dispose();
  return img;
}
