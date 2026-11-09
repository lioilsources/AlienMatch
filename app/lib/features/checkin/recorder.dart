import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// What a check-in recording yields: a few small key frames and the voice.
/// No video file is ever produced or uploaded.
class Recording {
  Recording(this.frames, this.audio);
  final List<Uint8List> frames;
  final Uint8List? audio;
}

/// Abstract so widget tests run without camera and microphone.
abstract class CheckinRecorder {
  /// Prepares camera (video mode) and microphone. False if not permitted.
  Future<bool> prepare({required bool video});
  CameraController? get camera;
  Future<void> start();
  Future<void> captureFrame();
  Future<Recording> stop();
  Future<void> dispose();
}

class DeviceCheckinRecorder implements CheckinRecorder {
  final _mic = AudioRecorder();
  CameraController? _cam;
  final _frames = <Uint8List>[];
  String? _path;

  @override
  CameraController? get camera => _cam;

  @override
  Future<bool> prepare({required bool video}) async {
    if (!await _mic.hasPermission()) return false;
    if (video) {
      try {
        final cams = await availableCameras();
        final front = cams.where((c) => c.lensDirection == CameraLensDirection.front);
        _cam = CameraController(front.isNotEmpty ? front.first : cams.first, ResolutionPreset.medium, enableAudio: false);
        await _cam!.initialize();
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/checkin_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _mic.start(const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 16000, bitRate: 32000), path: _path!);
  }

  @override
  Future<void> captureFrame() async {
    final c = _cam;
    if (c == null || !c.value.isInitialized) return;
    final shot = await c.takePicture();
    final bytes = await shot.readAsBytes();
    await File(shot.path).delete().catchError((_) => File(shot.path));
    _frames.add(await compute(_shrink, bytes));
  }

  @override
  Future<Recording> stop() async {
    final p = await _mic.stop() ?? _path;
    Uint8List? audio;
    if (p != null) {
      final f = File(p);
      if (await f.exists()) {
        audio = await f.readAsBytes();
        await f.delete(); // the recording leaves no file behind
      }
    }
    return Recording(List.of(_frames), audio);
  }

  @override
  Future<void> dispose() async {
    await _mic.dispose();
    await _cam?.dispose();
    _frames.clear();
  }
}

/// 640 px JPEG, well under the server's 600 KB per frame.
Uint8List _shrink(Uint8List jpeg) {
  final src = img.decodeImage(jpeg);
  if (src == null) return jpeg;
  final small = src.width > src.height ? img.copyResize(src, width: 640) : img.copyResize(src, height: 640);
  return img.encodeJpg(small, quality: 80);
}
