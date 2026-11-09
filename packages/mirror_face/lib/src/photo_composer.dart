import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'face_anchor.dart';
import 'mirror_geometry.dart';

/// Inputs for [composeMirrorPhoto]. All geometry values are in logical points
/// and must match what the live preview rendered when the shutter was tapped.
class PhotoComposeJob {
  final ui.Image still;

  /// The platform camera plugins mirror only the front-camera *preview*
  /// stream; stills come out unmirrored. Set true for the front camera so the
  /// composed photo matches what the user saw.
  final bool mirrorStillHorizontally;

  final Size screenSize;
  final double rotationDeg;
  final double mirrorAxisDeg;

  /// Whether the direct (unreflected) feed occupies the left half of the
  /// axis, i.e. `side.isLeft`.
  final bool directOnLeft;

  /// Camera aspect as width/height in portrait, same value the preview uses
  /// (`1 / controller.value.aspectRatio`).
  final double portraitAspect;

  final ui.FragmentShader? shader;
  final bool shaderNeedsTime;
  final double time;
  final bool shaderNeedsFace;
  final FaceAnchor faceAnchor;

  const PhotoComposeJob({
    required this.still,
    required this.mirrorStillHorizontally,
    required this.screenSize,
    required this.rotationDeg,
    required this.mirrorAxisDeg,
    required this.directOnLeft,
    required this.portraitAspect,
    this.shader,
    this.shaderNeedsTime = false,
    this.time = 0.0,
    this.shaderNeedsFace = false,
    this.faceAnchor = FaceAnchor.defaults,
  });
}

/// Renders the mirror composition from a full-resolution still, reproducing
/// the preview geometry (cover-fit into the rotation-aware canvas box, axis
/// mirror, whole-image rotation, screen crop) at the still's native pixel
/// density, then optionally runs the filter shader over the result.
///
/// The caller owns the returned image and the [PhotoComposeJob.still].
Future<ui.Image> composeMirrorPhoto(PhotoComposeJob job) async {
  final box = MirrorGeometry.canvasBoxFor(
      job.screenSize, job.rotationDeg, job.mirrorAxisDeg);
  final camFit = MirrorGeometry.coverFit(box, job.portraitAspect);

  // The preview shows the (16:9) video texture; the still is typically 4:3
  // with extra vertical field of view. Centre-crop the still to the preview
  // aspect so the framing matches what the user saw.
  final stillW = job.still.width.toDouble();
  final stillH = job.still.height.toDouble();
  var srcW = stillW;
  var srcH = stillW / job.portraitAspect;
  if (srcH > stillH) {
    srcH = stillH;
    srcW = stillH * job.portraitAspect;
  }
  final src = Rect.fromCenter(
      center: Offset(stillW / 2, stillH / 2), width: srcW, height: srcH);

  // Render at the still's density over the cover-fit: every output pixel is
  // backed by a real source pixel, none are wasted on upscaling.
  final s = srcH / camFit.height;
  final outW = (job.screenSize.width * s).round();
  final outH = (job.screenSize.height * s).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..filterQuality = FilterQuality.high
    ..isAntiAlias = true;

  canvas.translate(outW / 2, outH / 2);
  canvas.rotate(job.rotationDeg * pi / 180.0);

  final boxPx = Size(box.width * s, box.height * s);
  final theta = job.mirrorAxisDeg * pi / 180.0;
  final dst = Rect.fromCenter(
      center: Offset.zero, width: camFit.width * s, height: camFit.height * s);

  // Half-plane clip in box coordinates, shifted so the box centre sits at
  // the (translated) canvas origin.
  Path halfPlane(bool left) =>
      MirrorGeometry.axisHalfPlanePath(boxPx, theta, left)
          .shift(Offset(-boxPx.width / 2, -boxPx.height / 2));

  void drawCam() {
    if (job.mirrorStillHorizontally) {
      canvas.save();
      canvas.scale(-1, 1);
      canvas.drawImageRect(job.still, src, dst, paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(job.still, src, dst, paint);
    }
  }

  // Direct half.
  canvas.save();
  canvas.clipPath(halfPlane(job.directOnLeft));
  drawCam();
  canvas.restore();

  // Reflected half: 2-D reflection across a line at angle theta through the
  // centre, same matrix the preview uses in MirrorCanvas.
  canvas.save();
  canvas.clipPath(halfPlane(!job.directOnLeft));
  final cos2t = cos(2 * theta);
  final sin2t = sin(2 * theta);
  canvas.transform((Matrix4.identity()
        ..setEntry(0, 0, cos2t)
        ..setEntry(0, 1, sin2t)
        ..setEntry(1, 0, sin2t)
        ..setEntry(1, 1, -cos2t))
      .storage);
  drawCam();
  canvas.restore();

  final picture = recorder.endRecording();
  var image = await picture.toImage(outW, outH);
  picture.dispose();

  final shader = job.shader;
  if (shader != null) {
    // Float slots follow GLSL declaration order, matching the live painter:
    // uResolution, then uTime (needsTime), then uFaceCenter + uFaceScale
    // (needsFace). Shaders sample via fragCoord/uResolution, so passing the
    // output pixel size keeps UVs consistent with the preview.
    shader.setImageSampler(0, image);
    shader.setFloat(0, outW.toDouble());
    shader.setFloat(1, outH.toDouble());
    var i = 2;
    if (job.shaderNeedsTime) shader.setFloat(i++, job.time);
    if (job.shaderNeedsFace) {
      shader.setFloat(i++, job.faceAnchor.center.dx);
      shader.setFloat(i++, job.faceAnchor.center.dy);
      shader.setFloat(i++, job.faceAnchor.scale);
    }
    final shaderRecorder = ui.PictureRecorder();
    Canvas(shaderRecorder).drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..shader = shader,
    );
    final shaderPicture = shaderRecorder.endRecording();
    final filtered = await shaderPicture.toImage(outW, outH);
    shaderPicture.dispose();
    image.dispose();
    image = filtered;
  }

  return image;
}
