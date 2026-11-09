import 'dart:ui';

/// Where the face sits in the captured frame, in normalized UV coordinates.
///
/// [center] is the face center, [scale] the face radius as a fraction of the
/// shorter frame dimension. [defaults] relies on the mirror premise — the
/// user's face is centered on the mirror axis, which passes through the
/// canvas center. A face detector can supply per-frame values later without
/// any shader changes.
class FaceAnchor {
  final Offset center;
  final double scale;

  const FaceAnchor(this.center, this.scale);

  static const defaults = FaceAnchor(Offset(0.5, 0.5), 0.35);

  @override
  bool operator ==(Object other) =>
      other is FaceAnchor && other.center == center && other.scale == scale;

  @override
  int get hashCode => Object.hash(center, scale);
}
