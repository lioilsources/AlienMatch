import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'face_anchor.dart';
import 'mirror_filter.dart';
import 'mirror_side.dart';
import 'shader_cache.dart';
import 'mirror_canvas.dart';

class FilteredMirrorCanvas extends StatefulWidget {
  final CameraController controller;
  final MirrorSide side;
  final MirrorFilter filter;
  final ShaderCache shaderCache;
  final double mirrorAxisDeg;
  final FaceAnchor faceAnchor;

  const FilteredMirrorCanvas({
    super.key,
    required this.controller,
    required this.side,
    required this.filter,
    required this.shaderCache,
    this.mirrorAxisDeg = 90.0,
    this.faceAnchor = FaceAnchor.defaults,
  });

  @override
  State<FilteredMirrorCanvas> createState() => _FilteredMirrorCanvasState();
}

class _FilteredMirrorCanvasState extends State<FilteredMirrorCanvas>
    with SingleTickerProviderStateMixin {
  // Captures above the camera's ~30fps just duplicate identical frames.
  static const Duration _minCaptureInterval = Duration(milliseconds: 33);
  // Full device pixel ratio (3.0 on iPhone 12 mini) makes each captured
  // frame ~28 MB; stylizing shaders don't need that much detail.
  static const double _capturePixelRatioCap = 2.0;

  final _repaintKey = GlobalKey();
  late final Ticker _ticker;
  ui.Image? _frame;
  // Superseded frames kept alive until the raster pipeline (at most 2 frames
  // deep) can no longer sample them via setImageSampler.
  final List<ui.Image> _retiredFrames = [];
  ui.FragmentShader? _shader;
  MirrorFilter? _shaderFilter;
  bool _capturing = false;
  double _devicePixelRatio = 1.0;
  Duration _lastCaptureAt = Duration.zero;
  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(FilteredMirrorCanvas old) {
    super.didUpdateWidget(old);
    if (widget.filter != old.filter && widget.filter == MirrorFilter.none) {
      _retireAllFrames();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _retireShader();
    _retireAllFrames();
    super.dispose();
  }

  /// Returns a reusable shader for [filter], creating it on filter change.
  ui.FragmentShader? _shaderFor(MirrorFilter filter) {
    if (_shaderFilter != filter) {
      _retireShader();
      _shaderFilter = filter;
      final program = widget.shaderCache[filter];
      if (program != null) _shader = program.fragmentShader();
    }
    return _shader;
  }

  /// Defers native disposal by two frames so the raster pipeline can no
  /// longer reference the shader. The closure keeps it alive and runs even
  /// after this State is unmounted.
  void _retireShader() {
    final old = _shader;
    _shader = null;
    _shaderFilter = null;
    if (old == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
    });
  }

  void _retireAllFrames() {
    final doomed = <ui.Image>[..._retiredFrames, ?_frame];
    _retiredFrames.clear();
    _frame = null;
    if (doomed.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final img in doomed) {
          img.dispose();
        }
      });
    });
  }

  void _onTick(Duration elapsed) {
    if (widget.filter == MirrorFilter.none) return;
    if (_capturing) return;
    if (!widget.controller.value.isInitialized) return;
    if (elapsed - _lastCaptureAt < _minCaptureInterval) return;
    _lastCaptureAt = elapsed;
    _captureFrame();
  }

  Future<void> _captureFrame() async {
    _capturing = true;
    try {
      final ctx = _repaintKey.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ratio = math.min(_devicePixelRatio, _capturePixelRatioCap);
      final image = await boundary.toImage(pixelRatio: ratio);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        // Keep the last 2 superseded frames alive: a frame sampled by the
        // shader for frame N must not be disposed before frame N+2 is built.
        if (_frame != null) _retiredFrames.add(_frame!);
        _frame = image;
        while (_retiredFrames.length > 2) {
          _retiredFrames.removeAt(0).dispose();
        }
      });
    } catch (e) {
      debugPrint('filter capture: $e');
    } finally {
      _capturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    final mirrorCanvas = MirrorCanvas(
      controller: widget.controller,
      side: widget.side,
      mirrorAxisDeg: widget.mirrorAxisDeg,
    );

    if (widget.filter == MirrorFilter.none) return mirrorCanvas;

    final shader = _shaderFor(widget.filter);
    final frame = _frame;

    return Stack(
      fit: StackFit.expand,
      children: [
        // MirrorCanvas stays composited so the Texture widget keeps receiving
        // camera frames. RepaintBoundary isolates it for toImage() captures.
        RepaintBoundary(key: _repaintKey, child: mirrorCanvas),

        // Shader overlay drawn once we have a captured frame.
        if (shader != null && frame != null)
          CustomPaint(
            painter: _FilterShaderPainter(
              image: frame,
              shader: shader,
              needsTime: widget.filter.needsTime,
              time: (_stopwatch.elapsedMilliseconds / 1000.0) % 100.0,
              needsFace: widget.filter.needsFace,
              faceAnchor: widget.faceAnchor,
            ),
          ),
      ],
    );
  }
}

class _FilterShaderPainter extends CustomPainter {
  final ui.Image image;
  final ui.FragmentShader shader;
  final bool needsTime;
  final double time;
  final bool needsFace;
  final FaceAnchor faceAnchor;

  _FilterShaderPainter({
    required this.image,
    required this.shader,
    required this.needsTime,
    required this.time,
    required this.needsFace,
    required this.faceAnchor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform values are snapshotted into the display list at draw time, so
    // re-setting them each paint on the reused shader is safe.
    // Float slots follow GLSL declaration order: uResolution, then uTime
    // (needsTime shaders), then uFaceCenter + uFaceScale (needsFace shaders).
    shader.setImageSampler(0, image);
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    var i = 2;
    if (needsTime) shader.setFloat(i++, time);
    if (needsFace) {
      shader.setFloat(i++, faceAnchor.center.dx);
      shader.setFloat(i++, faceAnchor.center.dy);
      shader.setFloat(i++, faceAnchor.scale);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_FilterShaderPainter old) =>
      old.image != image ||
      old.shader != shader ||
      (needsTime && old.time != time) ||
      (needsFace && old.faceAnchor != faceAnchor);
}
