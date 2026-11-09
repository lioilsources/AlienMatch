import 'dart:async';

import 'package:flutter/services.dart';

import 'protocol.dart';

/// One BLE sighting of another AlienMatch phone.
class Sighting {
  Sighting(this.rpi, this.rssi);
  final Uint8List rpi;
  final int rssi;
}

/// Native BLE: advertise our current RPI and report others'.
/// Android puts the RPI in the advertisement's service data; iOS cannot, so
/// it serves it from a GATT characteristic that the scanner reads.
abstract class FlybyRadio {
  /// Returns false if Bluetooth is off or permission was denied.
  Future<bool> start(Uint8List rpi);
  Future<void> updateRpi(Uint8List rpi);
  Future<void> stop();
  Stream<Sighting> get sightings;
}

class NativeFlybyRadio implements FlybyRadio {
  static const _m = MethodChannel('alienmatch/flyby');
  static const _e = EventChannel('alienmatch/flyby/sightings');

  @override
  Future<bool> start(Uint8List rpi) async =>
      await _m.invokeMethod<bool>('start', {
        'rpi': rpi,
        'service': flybyServiceUuid,
        'characteristic': flybyCharacteristicUuid,
      }) ??
      false;

  @override
  Future<void> updateRpi(Uint8List rpi) =>
      _m.invokeMethod('updateRpi', {'rpi': rpi});

  @override
  Future<void> stop() => _m.invokeMethod('stop');

  @override
  Stream<Sighting> get sightings => _e
      .receiveBroadcastStream()
      .where((e) => e is Map)
      .map((e) {
        final m = e as Map;
        return Sighting(m['rpi'] as Uint8List, m['rssi'] as int);
      })
      .where((s) => s.rpi.length == rpiLength);
}
