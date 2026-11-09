import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// BLE identifiers shared with the native code (AppDelegate.swift, FlybyRadio.kt).
const flybyServiceUuid = 'f2778610-eac3-4781-be9f-5e09caeb3d02';
const flybyCharacteristicUuid = 'f2b4e644-2063-4f97-8533-4bce9d3fabbc';

/// Rolling identifiers rotate every 15 minutes (Exposure Notification style).
const rpiInterval = Duration(minutes: 15);
const tekLength = 16;
// 12 bytes: 128-bit service UUID + RPI must fit a 31-byte BLE scan response.
const rpiLength = 12;
const retentionDays = 14;

/// UTC day string, e.g. 2026-11-08.
String dayOf(DateTime t) {
  final u = t.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
}

DateTime dayStart(String day) => DateTime.parse('${day}T00:00:00Z');

/// Interval number since the epoch.
int intervalOf(DateTime t) =>
    t.toUtc().millisecondsSinceEpoch ~/ rpiInterval.inMilliseconds;

Uint8List newTek([Random? r]) {
  final rnd = r ?? Random.secure();
  return Uint8List.fromList(
    List<int>.generate(tekLength, (_) => rnd.nextInt(256)),
  );
}

/// RPI = first 12 bytes of HMAC-SHA256(TEK, "AM-RPI" || interval as uint32 LE).
/// The day key never leaves the phone before the next day; the RPI changes
/// every interval so a fixed sniffer cannot follow anyone.
Uint8List rpiFor(List<int> tek, int interval) {
  final msg = BytesBuilder()
    ..add('AM-RPI'.codeUnits)
    ..add(
      (ByteData(4)..setUint32(0, interval & 0xffffffff, Endian.little)).buffer
          .asUint8List(),
    );
  final mac = Hmac(sha256, tek).convert(msg.toBytes()).bytes;
  return Uint8List.fromList(mac.sublist(0, rpiLength));
}

/// All RPIs a key produced during [day].
List<Uint8List> rpisForDay(List<int> tek, String day) {
  final start = intervalOf(dayStart(day));
  final perDay =
      const Duration(days: 1).inMilliseconds ~/ rpiInterval.inMilliseconds;
  return [for (var i = 0; i < perDay; i++) rpiFor(tek, start + i)];
}

String hexOf(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

/// Contact types, classified on the phone; only the label is ever sent.
enum ContactKind { vehicle, stop, venue }

/// Classifies an aggregated contact (Prompts/01-GPS.md §1, layer B):
/// - vehicle: ≥ 8 min while moving (same tram/bus/train)
/// - stop: 2–10 min while stationary
/// - venue: ≥ 20 min while stationary
/// Returns null for contacts too short to mean anything.
ContactKind? classify(Duration contact, {required bool moving}) {
  final m = contact.inSeconds / 60;
  if (moving) return m >= 8 ? ContactKind.vehicle : null;
  if (m >= 20) return ContactKind.venue;
  if (m >= 2 && m <= 10) return ContactKind.stop;
  return null;
}
