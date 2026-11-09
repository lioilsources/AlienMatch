import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mirror_face/mirror_face.dart';

import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Live capture only: there is deliberately no gallery picker. The still
/// never leaves the phone; only the chosen symmetric variant is uploaded.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? cam;
  bool unavailable = false;
  bool busy = false;
  bool failed = false;
  bool frontCamera = true;
  Map<MirrorSide, ui.Image>? variants;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final front = cams.where(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final desc = front.isNotEmpty ? front.first : cams.first;
      frontCamera = desc.lensDirection == CameraLensDirection.front;
      final c = CameraController(
        desc,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await c.initialize();
      if (!mounted) return c.dispose();
      setState(() => cam = c);
    } catch (_) {
      if (mounted) setState(() => unavailable = true);
    }
  }

  @override
  void dispose() {
    cam?.dispose();
    for (final i in variants?.values ?? const <ui.Image>[]) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = cam;
    if (c == null || busy) return;
    setState(() => busy = true);
    try {
      final file = await c.takePicture();
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final still = (await codec.getNextFrame()).image;
      final out = {
        for (final side in MirrorSide.values)
          side: await symmetricVariant(
            still,
            side,
            mirrorStillHorizontally: frontCamera,
          ),
      };
      still.dispose();
      if (mounted) setState(() => variants = out);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _choose(MirrorSide side) async {
    final app = AppScope.of(context);
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await app.api.uploadPhoto(await encodeJpeg(variants![side]!));
      await app.refresh();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final v = variants;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: v != null ? _pick(l, v) : _camera(l),
        ),
      ),
    );
  }

  Widget _camera(AppLocalizations l) {
    if (unavailable) {
      return Center(
        child: Text(l.cameraUnavailable, textAlign: TextAlign.center),
      );
    }
    final c = cam;
    if (c == null) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Text(l.captureHint, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 1,
                    height: c.value.aspectRatio,
                    child: CameraPreview(c),
                  ),
                ),
                const CustomPaint(painter: _GuidePainter()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (failed)
          Text(l.errorGeneric, style: const TextStyle(color: Colors.redAccent)),
        FilledButton.icon(
          onPressed: busy ? null : _shoot,
          icon: const Icon(Icons.camera_alt),
          label: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l.capture),
          ),
        ),
      ],
    );
  }

  Widget _pick(AppLocalizations l, Map<MirrorSide, ui.Image> v) {
    return Column(
      children: [
        Text(l.pickVariant, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          l.variantNote,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Space.dim),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              for (final side in MirrorSide.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: InkWell(
                      key: Key('variant-${side.label}'),
                      onTap: busy ? null : () => _choose(side),
                      borderRadius: BorderRadius.circular(20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: RawImage(image: v[side], fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (failed)
          Text(l.errorGeneric, style: const TextStyle(color: Colors.redAccent)),
        if (busy) const LinearProgressIndicator(),
        TextButton.icon(
          onPressed: busy ? null : () => setState(() => variants = null),
          icon: const Icon(Icons.refresh),
          label: Text(l.retake),
        ),
      ],
    );
  }
}

/// Oval face guide with the mirror axis through its centre.
class _GuidePainter extends CustomPainter {
  const _GuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Space.accent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final c = size.center(Offset.zero);
    canvas.drawOval(
      Rect.fromCenter(
        center: c,
        width: size.width * 0.62,
        height: size.width * 0.82,
      ),
      p,
    );
    canvas.drawLine(
      Offset(c.dx, 0),
      Offset(c.dx, size.height),
      p..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// JPEG for upload (server accepts JPEG/WebP/PNG, max 1 MB).
Future<Uint8List> encodeJpeg(ui.Image image, {int quality = 85}) async {
  final bd = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final raw = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: bd.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(raw, quality: quality);
}
