import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// "Am I on the move?" from the user accelerometer: mean magnitude over a
/// sliding window. Coarse on purpose; it only separates riding from waiting.
Stream<bool> motionStream({
  Duration window = const Duration(seconds: 20),
  double threshold = 0.35,
}) async* {
  final samples = <({DateTime t, double a})>[];
  var last = false;
  await for (final e in userAccelerometerEventStream(
    samplingPeriod: SensorInterval.normalInterval,
  )) {
    final now = DateTime.now();
    samples.add((t: now, a: sqrt(e.x * e.x + e.y * e.y + e.z * e.z)));
    samples.removeWhere((s) => now.difference(s.t) > window);
    final mean = samples.fold(0.0, (s, x) => s + x.a) / samples.length;
    final moving = mean > threshold;
    if (moving != last) {
      last = moving;
      yield moving;
    }
  }
}
