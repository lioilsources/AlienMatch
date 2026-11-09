import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'protocol.dart';

/// One observed rolling identifier. Kept only on this phone, 14 days.
class Observation {
  Observation({
    required this.rpi,
    required this.first,
    required this.last,
    required this.maxRssi,
    this.samples = 0,
    this.movingSamples = 0,
  });
  final String rpi; // hex
  DateTime first;
  DateTime last;
  int maxRssi;
  int samples;
  int movingSamples;

  Map<String, dynamic> toJson() => {
    'r': rpi,
    'f': first.millisecondsSinceEpoch,
    'l': last.millisecondsSinceEpoch,
    'x': maxRssi,
    's': samples,
    'm': movingSamples,
  };
  factory Observation.fromJson(Map<String, dynamic> j) => Observation(
    rpi: j['r'] as String,
    first: DateTime.fromMillisecondsSinceEpoch(j['f'] as int, isUtc: true),
    last: DateTime.fromMillisecondsSinceEpoch(j['l'] as int, isUtc: true),
    maxRssi: j['x'] as int,
    samples: j['s'] as int? ?? 0,
    movingSamples: j['m'] as int? ?? 0,
  );
}

/// Local persistence for layer B. Abstract so tests run without platform IO.
abstract class FlybyStore {
  /// Day key per UTC day (secret until uploaded the next day).
  Future<Map<String, Uint8List>> loadKeys();
  Future<void> saveKeys(Map<String, Uint8List> keys);
  Future<List<Observation>> loadObservations();
  Future<void> saveObservations(List<Observation> obs);

  /// Small JSON state: uploaded days, waved encounters.
  Future<Map<String, dynamic>> loadState();
  Future<void> saveState(Map<String, dynamic> s);

  /// Deletes everything (opt-out).
  Future<void> wipe();
}

class MemoryFlybyStore implements FlybyStore {
  Map<String, Uint8List> keys = {};
  List<Observation> obs = [];
  Map<String, dynamic> state = {};
  @override
  Future<Map<String, Uint8List>> loadKeys() async => Map.of(keys);
  @override
  Future<void> saveKeys(Map<String, Uint8List> k) async => keys = Map.of(k);
  @override
  Future<List<Observation>> loadObservations() async => List.of(obs);
  @override
  Future<void> saveObservations(List<Observation> o) async => obs = List.of(o);
  @override
  Future<Map<String, dynamic>> loadState() async => Map.of(state);
  @override
  Future<void> saveState(Map<String, dynamic> s) async => state = Map.of(s);
  @override
  Future<void> wipe() async {
    keys = {};
    obs = [];
    state = {};
  }
}

/// Keys in the secure keystore; observations in the app support directory.
class DeviceFlybyStore implements FlybyStore {
  static const _keysKey = 'alienmatch_flyby_keys';
  final _secure = const FlutterSecureStorage();

  Future<File> _file(String name) async =>
      File('${(await getApplicationSupportDirectory()).path}/$name');

  @override
  Future<Map<String, Uint8List>> loadKeys() async {
    final raw = await _secure.read(key: _keysKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (d, v) => MapEntry(d, base64Decode(v as String)),
    );
  }

  @override
  Future<void> saveKeys(Map<String, Uint8List> keys) => _secure.write(
    key: _keysKey,
    value: jsonEncode(keys.map((d, v) => MapEntry(d, base64Encode(v)))),
  );

  @override
  Future<List<Observation>> loadObservations() async {
    final f = await _file('flyby_observations.json');
    if (!await f.exists()) return [];
    return [
      for (final o in jsonDecode(await f.readAsString()) as List)
        Observation.fromJson(o as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> saveObservations(List<Observation> obs) async => (await _file(
    'flyby_observations.json',
  )).writeAsString(jsonEncode([for (final o in obs) o.toJson()]), flush: true);

  @override
  Future<Map<String, dynamic>> loadState() async {
    final f = await _file('flyby_state.json');
    if (!await f.exists()) return {};
    return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
  }

  @override
  Future<void> saveState(Map<String, dynamic> s) async => (await _file(
    'flyby_state.json',
  )).writeAsString(jsonEncode(s), flush: true);

  @override
  Future<void> wipe() async {
    await _secure.delete(key: _keysKey);
    for (final n in ['flyby_observations.json', 'flyby_state.json']) {
      final f = await _file(n);
      if (await f.exists()) await f.delete();
    }
  }
}

/// Matches downloaded keys against local observations. Pure, for tests.
List<LocalEncounter> matchEncounters(
  List<({String day, Uint8List tek})> keys,
  List<Observation> obs,
) {
  final byRpi = {for (final o in obs) o.rpi: o};
  final out = <LocalEncounter>[];
  for (final k in keys) {
    final seen = <Observation>[];
    for (final r in rpisForDay(k.tek, k.day)) {
      final o = byRpi[hexOf(r)];
      if (o != null) seen.add(o);
    }
    if (seen.isEmpty) continue;
    seen.sort((a, b) => a.first.compareTo(b.first));
    // Contact = longest run of sightings with gaps under 5 minutes
    // (the RPI rotates every 15 minutes, so one ride spans several RPIs).
    var best = (d: Duration.zero, samples: 0, moving: 0);
    var start = seen.first.first,
        end = seen.first.last,
        samples = 0,
        moving = 0;
    for (final o in seen) {
      if (o.first.difference(end) > const Duration(minutes: 5)) {
        start = o.first;
        end = o.last;
        samples = 0;
        moving = 0;
      }
      if (o.last.isAfter(end)) end = o.last;
      samples += o.samples;
      moving += o.movingSamples;
      final d = end.difference(start);
      if (d >= best.d) best = (d: d, samples: samples, moving: moving);
    }
    final kind = classify(
      best.d,
      moving: best.samples > 0 && best.moving * 2 > best.samples,
    );
    if (kind != null) {
      out.add(
        LocalEncounter(
          day: k.day,
          tek: k.tek,
          kind: kind,
          minutes: best.d.inMinutes,
        ),
      );
    }
  }
  return out;
}

/// A fly-by known only to this phone: no identity, no time, no place.
class LocalEncounter {
  LocalEncounter({
    required this.day,
    required this.tek,
    required this.kind,
    required this.minutes,
  });
  final String day;
  final Uint8List tek;
  final ContactKind kind;
  final int minutes;
  String get id => '$day:${hexOf(tek)}';
}
