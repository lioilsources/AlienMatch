import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mirror_face/mirror_face.dart';

import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'filter_strip.dart';

/// Compiled once per app run; FragmentProgram compilation is not free.
Future<ShaderCache>? _shaders;

/// MirrorBooth inside onboarding: live mirror with a free axis, whole-image
/// rotation and every filter shader. Live capture only, there is deliberately
/// no gallery picker. The still never leaves the phone; only the composed
/// mirror face is uploaded.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? cam;
  List<CameraDescription> cams = const [];
  ShaderCache shaders = const {};
  bool unavailable = false;
  bool busy = false;
  bool failed = false;

  MirrorSide side = MirrorSide.left;
  double rotationDeg = 0;
  double mirrorAxisDeg = 90;
  MirrorFilter filter = MirrorFilter.none;
  Size stageSize = Size.zero;

  /// Composed square face waiting for confirmation.
  ui.Image? result;

  bool get front => cam?.description.lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      final loaded = await (_shaders ??= loadShaderCache());
      cams = await availableCameras();
      if (!mounted) return;
      shaders = loaded;
      await _open(
        cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cams.first,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => unavailable = true);
    }
  }

  Future<void> _open(CameraDescription desc) async {
    final c = CameraController(
      desc,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    await c.initialize();
    try {
      await c.setFlashMode(FlashMode.off);
    } catch (_) {}
    if (!mounted) return c.dispose();
    setState(() => cam = c);
  }

  Future<void> _switchCamera() async {
    final c = cam;
    if (c == null || busy || cams.length < 2) return;
    final next = cams.firstWhere(
      (d) => d.lensDirection != c.description.lensDirection,
      orElse: () => c.description,
    );
    setState(() => cam = null);
    await c.dispose();
    try {
      await _open(next);
    } catch (_) {
      if (mounted) setState(() => unavailable = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final c = cam;
    if (s == AppLifecycleState.inactive && c != null) {
      setState(() => cam = null);
      c.dispose();
    } else if (s == AppLifecycleState.resumed &&
        cam == null &&
        cams.isNotEmpty) {
      _open(
        cams.firstWhere(
          (d) => d.lensDirection == CameraLensDirection.front,
          orElse: () => cams.first,
        ),
      ).catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cam?.dispose();
    result?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = cam;
    if (c == null || busy || stageSize.isEmpty) return;
    setState(() {
      busy = true;
      failed = false;
    });
    ui.Image? still;
    ui.FragmentShader? shader;
    try {
      final file = await c.takePicture();
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      still = (await codec.getNextFrame()).image;
      codec.dispose();
      shader = shaders[filter]?.fragmentShader();
      final composed = await composeMirrorPhoto(
        PhotoComposeJob(
          still: still,
          mirrorStillHorizontally: front,
          screenSize: stageSize,
          rotationDeg: rotationDeg,
          mirrorAxisDeg: mirrorAxisDeg,
          directOnLeft: side.isLeft,
          portraitAspect: 1.0 / c.value.aspectRatio,
          shader: shader,
          shaderNeedsTime: filter.needsTime,
          time: (DateTime.now().millisecondsSinceEpoch / 1000.0) % 100.0,
          shaderNeedsFace: filter.needsFace,
        ),
      );
      final square = await squareCrop(composed);
      composed.dispose();
      if (!mounted) return square.dispose();
      setState(() => result = square);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      still?.dispose();
      shader?.dispose();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _use() async {
    final app = AppScope.of(context);
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await app.api.uploadPhoto(await encodeJpeg(result!));
      await app.refresh();
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _retake() {
    final r = result;
    setState(() => result = null);
    r?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = result;
    return Scaffold(
      body: SafeArea(child: r != null ? _review(l, r) : _camera(l)),
    );
  }

  Widget _camera(AppLocalizations l) {
    if (unavailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l.cameraUnavailable, textAlign: TextAlign.center),
        ),
      );
    }
    final c = cam;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            l.captureHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Space.dim),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: LayoutBuilder(
                builder: (context, box) {
                  stageSize = box.biggest;
                  if (c == null || !c.value.isInitialized) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return MirrorStage(
                    controller: c,
                    size: stageSize,
                    side: side,
                    filter: filter,
                    shaderCache: shaders,
                    rotationDeg: rotationDeg,
                    mirrorAxisDeg: mirrorAxisDeg,
                    onRotate: (d) => setState(
                      () => rotationDeg = normalizeDeg(rotationDeg + d),
                    ),
                    onMirrorAxis: (d) => setState(
                      () => mirrorAxisDeg = normalizeDeg(mirrorAxisDeg + d),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FilterStrip(
          selected: filter,
          available: shaders.keys.toSet(),
          onSelect: (f) => setState(() => filter = f),
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.errorGeneric,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundButton(
                key: const Key('switchSide'),
                tooltip: l.switchSide,
                onTap: () => setState(() => side = side.toggled),
                child: Text(
                  '${side.label}·${side.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Space.ink,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l.capture,
                child: GestureDetector(
                  key: const Key('shutter'),
                  onTap: busy ? null : _shoot,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Space.accent, width: 4),
                    ),
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: busy ? Space.dim : Space.ink,
                      ),
                    ),
                  ),
                ),
              ),
              _RoundButton(
                key: const Key('switchCamera'),
                tooltip: l.switchCamera,
                onTap: cams.length < 2 ? null : _switchCamera,
                child: const Icon(Icons.cameraswitch, color: Space.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _review(AppLocalizations l, ui.Image r) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
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
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipOval(
                  child: RawImage(
                    key: const Key('composedFace'),
                    image: r,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          if (failed)
            Text(
              l.errorGeneric,
              style: const TextStyle(color: Colors.redAccent),
            ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('usePhoto'),
            onPressed: busy ? null : _use,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(l.usePhoto),
            ),
          ),
          TextButton.icon(
            onPressed: busy ? null : _retake,
            icon: const Icon(Icons.refresh),
            label: Text(l.retake),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Space.nebula,
            border: Border.all(color: Space.dim.withValues(alpha: 0.5)),
          ),
          child: Opacity(opacity: onTap == null ? 0.4 : 1, child: child),
        ),
      ),
    ),
  );
}

/// Centre square of [image], scaled down to at most [maxSize] px: the profile
/// photo is drawn in circles everywhere.
Future<ui.Image> squareCrop(ui.Image image, {int maxSize = 1024}) async {
  final side = min(image.width, image.height).toDouble();
  final out = min(maxSize, side.round());
  final src = Rect.fromCenter(
    center: Offset(image.width / 2, image.height / 2),
    width: side,
    height: side,
  );
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(
    image,
    src,
    Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final pic = rec.endRecording();
  final res = await pic.toImage(out, out);
  pic.dispose();
  return res;
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
