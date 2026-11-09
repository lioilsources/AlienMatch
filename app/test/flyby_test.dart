import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:alienmatch/features/settings/flyby_tile.dart';
import 'package:alienmatch/flyby/controller.dart';
import 'package:alienmatch/flyby/protocol.dart';
import 'package:alienmatch/flyby/radio.dart';
import 'package:alienmatch/flyby/store.dart';
import 'package:alienmatch/l10n/app_localizations.dart';
import 'package:alienmatch/main.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

class FakeRadio implements FlybyRadio {
  bool ok = true;
  Uint8List? advertising;
  bool started = false;
  final ctl = StreamController<Sighting>.broadcast();
  @override
  Future<bool> start(Uint8List rpi) async {
    advertising = rpi;
    started = ok;
    return ok;
  }

  @override
  Future<void> updateRpi(Uint8List rpi) async => advertising = rpi;
  @override
  Future<void> stop() async => started = false;
  @override
  Stream<Sighting> get sightings => ctl.stream;
}

Uint8List tekOf(int b) => Uint8List.fromList(List.filled(16, b));

Observation obsFor(Uint8List tek, DateTime from, Duration span, {bool moving = false}) {
  final rpi = rpiFor(tek, intervalOf(from));
  return Observation(rpi: hexOf(rpi), first: from, last: from.add(span), maxRssi: -60, samples: 10, movingSamples: moving ? 10 : 0);
}

void main() {
  group('protocol', () {
    test('RPI is deterministic, rotates per interval and is 12 bytes', () {
      final t = tekOf(7);
      expect(rpiFor(t, 100), rpiFor(t, 100));
      expect(rpiFor(t, 100), isNot(rpiFor(t, 101)));
      expect(rpiFor(t, 100), isNot(rpiFor(tekOf(8), 100)));
      expect(rpiFor(t, 100).length, rpiLength);
      expect(rpisForDay(t, '2026-11-08'), hasLength(96));
    });

    test('contact classification', () {
      expect(classify(const Duration(minutes: 15), moving: true), ContactKind.vehicle);
      expect(classify(const Duration(minutes: 5), moving: true), isNull);
      expect(classify(const Duration(minutes: 5), moving: false), ContactKind.stop);
      expect(classify(const Duration(minutes: 25), moving: false), ContactKind.venue);
      expect(classify(const Duration(minutes: 1), moving: false), isNull);
      expect(classify(const Duration(minutes: 14), moving: false), isNull);
    });
  });

  group('matching', () {
    final day = '2026-11-08';
    final t0 = DateTime.utc(2026, 11, 8, 7, 50);

    test('a ride across several RPIs becomes one vehicle contact', () {
      final other = tekOf(3);
      final obs = [
        obsFor(other, t0, const Duration(minutes: 9), moving: true),
        obsFor(other, t0.add(const Duration(minutes: 10)), const Duration(minutes: 12), moving: true),
        obsFor(tekOf(9), t0, const Duration(minutes: 30)), // someone else
      ];
      final enc = matchEncounters([(day: day, tek: other)], obs);
      expect(enc, hasLength(1));
      expect(enc.single.kind, ContactKind.vehicle);
      expect(enc.single.minutes, 22);
    });

    test('long stationary contact is a venue, short is a stop, gaps split', () {
      final a = tekOf(4), b = tekOf(5), c = tekOf(6);
      final obs = [
        obsFor(a, t0, const Duration(minutes: 25)),
        obsFor(b, t0, const Duration(minutes: 4)),
        obsFor(c, t0, const Duration(minutes: 1)),
        obsFor(c, t0.add(const Duration(minutes: 40)), const Duration(minutes: 1)),
      ];
      final enc = {for (final e in matchEncounters([(day: day, tek: a), (day: day, tek: b), (day: day, tek: c)], obs)) e.tek[0]: e.kind};
      expect(enc, {4: ContactKind.venue, 5: ContactKind.stop});
    });

    test('keys never seen produce nothing', () {
      expect(matchEncounters([(day: day, tek: tekOf(1))], [obsFor(tekOf(2), t0, const Duration(minutes: 30))]), isEmpty);
    });
  });

  group('controller', () {
    late FakeBackend be;
    late FakeRadio radio;
    late MemoryFlybyStore store;
    late DateTime now;
    late FlybyController c;

    setUp(() {
      be = FakeBackend();
      radio = FakeRadio();
      store = MemoryFlybyStore();
      now = DateTime.utc(2026, 11, 8, 7, 55);
      c = FlybyController(api: be.api()..token = 't' * 43, store: store, radio: radio, now: () => now);
    });

    test('enable advertises today\'s RPI, records, uploads yesterday\'s key next day, matches, waves', () async {
      await c.load();
      await c.setEnabled(true);
      expect(be.flybyEnabled, isTrue);
      expect(radio.started, isTrue);
      final today = store.keys['2026-11-08']!;
      expect(radio.advertising, rpiFor(today, intervalOf(now)));
      expect(be.uploadedKeys, isEmpty, reason: "today's key never leaves the phone");

      // Ride together with someone holding key K.
      final k = tekOf(42);
      c.moving = true;
      for (var m = 0; m <= 16; m++) {
        now = DateTime.utc(2026, 11, 8, 7, 55).add(Duration(minutes: m));
        await c.rotateIfNeeded();
        c.record(Sighting(rpiFor(k, intervalOf(now)), -55));
      }
      expect(radio.advertising, rpiFor(today, intervalOf(now)), reason: 'RPI rotated');

      // Next day: upload yesterday's key, download K, find the ride.
      now = DateTime.utc(2026, 11, 9, 8, 0);
      be.flybyKeys = [{'day': '2026-11-08', 'tek': base64Encode(k)}];
      await c.sync();
      expect(be.uploadedKeys.single['day'], '2026-11-08');
      expect(base64Decode(be.uploadedKeys.single['tek'] as String), today);
      expect(c.encounters, hasLength(1));
      expect(c.encounters.single.kind, ContactKind.vehicle);

      await c.sync();
      expect(be.uploadedKeys, hasLength(1), reason: 'upload once per day');

      await c.wave(c.encounters.single);
      expect(be.flybyWaves.single, {'day': '2026-11-08', 'tek': base64Encode(k), 'kind': 'vehicle'});
      expect(c.encounters, isEmpty);
      await c.sync();
      expect(c.encounters, isEmpty, reason: 'waved encounters stay hidden');
    });

    test('disable stops the radio and wipes local data', () async {
      await c.setEnabled(true);
      c.record(Sighting(rpiFor(tekOf(1), intervalOf(now)), -60));
      await store.saveObservations([]);
      await c.setEnabled(false);
      expect(be.flybyEnabled, isFalse);
      expect(radio.started, isFalse);
      expect(store.keys, isEmpty);
      expect(store.obs, isEmpty);
      expect(c.enabled, isFalse);
    });

    test('Bluetooth off is reported', () async {
      radio.ok = false;
      await c.setEnabled(true);
      expect(c.enabled, isTrue);
      expect(c.radioOn, isFalse);
    });

    test('old data is pruned after 14 days', () async {
      await c.setEnabled(true);
      c.record(Sighting(rpiFor(tekOf(1), intervalOf(now)), -60));
      now = now.add(const Duration(days: 15));
      await c.sync();
      expect(store.obs, isEmpty);
      expect(store.keys.keys.every((d) => !d.startsWith('2026-11-08')), isTrue);
    });
  });

  testWidgets('settings switch, radio hint, radar strip and comet', (tester) async {
    final be = FakeBackend()
      ..profile = FakeBackend.sampleProfile()
      ..hasPhoto = true
      ..radar = {
        'off_radar': false,
        'planets': [
          {'user_id': 'u2', 'kind': 'match', 'level': 'HIGH', 'trend': 'RISING', 'intents': [], 'comet': 'vehicle'},
        ],
      };
    final radio = FakeRadio()..ok = false;
    final store = MemoryFlybyStore();
    final state = AppState(
      api: be.api(),
      tokens: MemoryTokens()..token = 't' * 43,
      flybyFactory: (api) => FlybyController(api: api, store: store, radio: radio, now: () => DateTime.utc(2026, 11, 9, 8)),
    );
    await state.load();
    await tester.pumpWidget(AlienMatchApp(state: state));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('☄️'), findsOneWidget, reason: 'comet badge on the planet');
    await tester.tap(find.byKey(const Key('planet-u2')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('comet')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('comet')))).pop();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(Icons.tune));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.scrollUntilVisible(find.byKey(const Key('flybySwitch')), 200);
    await tester.tap(find.byKey(const Key('flybySwitch')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(be.flybyEnabled, isTrue);
    expect(find.byKey(const Key('flybyRadioOff')), findsOneWidget);
    state.flyby!.dispose(); // stop rotation and persist timers
  });

  testWidgets('flyby tile hidden without a controller', (tester) async {
    final state = AppState(api: FakeBackend().api(), tokens: MemoryTokens());
    await tester.pumpWidget(AppScope(
      state: state,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: FlybyTile()),
      ),
    ));
    expect(find.byKey(const Key('flybySwitch')), findsNothing);
  });
}
