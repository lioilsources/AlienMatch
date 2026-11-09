import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/api.dart';
import 'protocol.dart';
import 'radio.dart';
import 'store.dart';

/// Layer B on the phone: keeps today's key, advertises rotating RPIs,
/// records sightings locally, uploads yesterday's key, matches downloaded
/// keys on the phone and lets the user wave at a fly-by.
///
/// Full function while the app is open (iOS limits background BLE); the
/// morning check-in on the tram is when the app is open anyway.
class FlybyController extends ChangeNotifier {
  FlybyController({
    required this.api,
    required this.store,
    required this.radio,
    Stream<bool>? motion,
    DateTime Function()? now,
  }) : _motion = motion, // ignore: prefer_initializing_formals
       _now = now ?? DateTime.now;

  final Api api;
  final FlybyStore store;
  final FlybyRadio radio;
  final Stream<bool>? _motion;
  final DateTime Function() _now;

  bool enabled = false;
  bool radioOn = false;
  bool moving = false;
  List<LocalEncounter> encounters = [];

  final Map<String, Observation> _obs = {};
  Map<String, Uint8List> _keys = {};
  Map<String, dynamic> _state = {};
  StreamSubscription<Sighting>? _sightSub;
  StreamSubscription<bool>? _motionSub;
  Timer? _rotate;
  Timer? _persist;
  int _interval = -1;

  Future<void> load() async {
    _state = await store.loadState();
    enabled = _state['enabled'] == true;
    _keys = await store.loadKeys();
    for (final o in await store.loadObservations()) {
      _obs[o.rpi] = o;
    }
    notifyListeners();
    if (enabled) await _startRadio();
  }

  Future<void> setEnabled(bool on) async {
    await api.setFlyby(on);
    if (on) {
      enabled = true;
      _state['enabled'] = true;
      await store.saveState(_state);
      await _startRadio();
      await sync();
    } else {
      await _stopRadio();
      await store.wipe();
      _obs.clear();
      _keys = {};
      _state = {};
      enabled = false;
      encounters = [];
    }
    notifyListeners();
  }

  Uint8List _todayKey() {
    final d = dayOf(_now());
    return _keys.putIfAbsent(d, newTek);
  }

  Uint8List currentRpi() => rpiFor(_todayKey(), intervalOf(_now()));

  Future<void> _startRadio() async {
    final rpi = currentRpi();
    await store.saveKeys(_keys);
    _interval = intervalOf(_now());
    radioOn = await radio.start(rpi);
    _sightSub ??= radio.sightings.listen(record);
    _motionSub ??= _motion?.listen((m) => moving = m);
    _rotate ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => rotateIfNeeded(),
    );
    _persist ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => store.saveObservations(_obs.values.toList()),
    );
    notifyListeners();
  }

  /// Switches to the next RPI at each 15-minute boundary (and a new key at midnight UTC).
  Future<void> rotateIfNeeded() async {
    final i = intervalOf(_now());
    if (i == _interval) return;
    _interval = i;
    final rpi = currentRpi();
    await store.saveKeys(_keys);
    if (radioOn) await radio.updateRpi(rpi);
  }

  Future<void> _stopRadio() async {
    _rotate?.cancel();
    _persist?.cancel();
    _rotate = null;
    _persist = null;
    await _sightSub?.cancel();
    await _motionSub?.cancel();
    _sightSub = null;
    _motionSub = null;
    if (radioOn) await radio.stop();
    radioOn = false;
  }

  /// Records one sighting. Nothing leaves the phone.
  void record(Sighting s) {
    final k = hexOf(s.rpi);
    final t = _now().toUtc();
    final o = _obs.putIfAbsent(
      k,
      () => Observation(rpi: k, first: t, last: t, maxRssi: s.rssi),
    );
    o
      ..last = t
      ..maxRssi = max(o.maxRssi, s.rssi)
      ..samples += 1
      ..movingSamples += moving ? 1 : 0;
  }

  /// Daily: upload yesterday's key, download others, match locally, prune.
  Future<void> sync() async {
    if (!enabled) return;
    final now = _now();
    final yesterday = dayOf(now.subtract(const Duration(days: 1)));
    final uploaded = List<String>.from(_state['uploaded'] as List? ?? const []);
    final yKey = _keys[yesterday];
    if (yKey != null && !uploaded.contains(yesterday)) {
      try {
        await api.uploadFlybyKey(yesterday, yKey);
        uploaded.add(yesterday);
      } on ApiException catch (e) {
        if (e.status == 400) {
          uploaded.add(yesterday); // already there or not yesterday anymore
        }
      }
    }
    // Prune local data past the retention window.
    final cutoff = now.toUtc().subtract(const Duration(days: retentionDays));
    _obs.removeWhere((_, o) => o.last.isBefore(cutoff));
    _keys.removeWhere(
      (d, _) => dayStart(d).isBefore(cutoff.subtract(const Duration(days: 1))),
    );
    uploaded.removeWhere((d) => dayStart(d).isBefore(cutoff));
    _state['uploaded'] = uploaded;
    await store.saveKeys(_keys);
    await store.saveObservations(_obs.values.toList());

    final keys = await api.flybyKeys();
    final waved = Set<String>.from(_state['waved'] as List? ?? const []);
    encounters = [
      for (final e in matchEncounters(keys, _obs.values.toList()))
        if (!waved.contains(e.id)) e,
    ];
    await store.saveState(_state);
    notifyListeners();
  }

  Future<void> wave(LocalEncounter e) async {
    await api.waveFlyby(e.day, e.tek, e.kind.name);
    final waved = List<String>.from(_state['waved'] as List? ?? const [])
      ..add(e.id);
    _state['waved'] = waved;
    await store.saveState(_state);
    encounters = [
      for (final x in encounters)
        if (x.id != e.id) x,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _stopRadio();
    super.dispose();
  }
}
