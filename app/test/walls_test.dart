import 'dart:convert';

import 'package:alienmatch/api/api.dart';
import 'package:alienmatch/features/walls/ink.dart';
import 'package:alienmatch/features/walls/queue_store.dart';
import 'package:alienmatch/features/walls/wall_controller.dart';
import 'package:alienmatch/features/walls/wall_screen.dart';
import 'package:alienmatch/l10n/app_localizations.dart';
import 'package:alienmatch/main.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';
import 'fake_socket.dart';

Future<void> settle(WidgetTester t, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<(FakeBackend, AppState)> signedIn(WidgetTester tester) async {
  final be = FakeBackend()
    ..profile = FakeBackend.sampleProfile()
    ..hasPhoto = true;
  final state = AppState(api: be.api(), tokens: MemoryTokens()..token = 't' * 43);
  await state.load();
  return (be, state);
}

Widget wallApp(AppState state, MatchView m, FakeSocket sock) => AppScope(
      state: state,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WallScreen(match: m, connect: (uri) => sock..uri = uri, queueStore: MemoryQueueStore()),
      ),
    );

final match = MatchView(wallId: 7, kind: 'match', otherId: 'u2', otherNickname: 'Zq-7', sharedPlaces: ['Anděl']);

void main() {
  testWidgets('waving from the radar opens a wall when mutual', (tester) async {
    final (be, state) = await signedIn(tester);
    be
      ..waveMatches = true
      ..radar = {
        'off_radar': false,
        'planets': [
          {'user_id': 'u2', 'kind': 'match', 'level': 'HIGH', 'trend': 'RISING', 'intents': ['coffee']},
        ],
      };
    await tester.pumpWidget(AlienMatchApp(state: state));
    await settle(tester);
    await tester.tap(find.byKey(const Key('planet-u2')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('wave')));
    await settle(tester);
    expect(find.textContaining('mutual'), findsOneWidget);
    expect(be.requests.any((r) => r.url.path == '/v1/waves' && r.body.contains('"to":"u2"')), isTrue);
  });

  testWidgets('wave limit is explained', (tester) async {
    final (be, state) = await signedIn(tester);
    be
      ..waveStatus = 429
      ..radar = {'off_radar': false, 'planets': [{'user_id': 'u2', 'kind': 'match', 'level': 'HIGH', 'trend': 'FLAT', 'intents': []}]};
    await tester.pumpWidget(AlienMatchApp(state: state));
    await settle(tester);
    await tester.tap(find.byKey(const Key('planet-u2')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('wave')));
    await settle(tester);
    expect(find.textContaining('waves for today'), findsOneWidget);
  });

  testWidgets('wall: presets, realtime events, report, no keyboard', (tester) async {
    final (be, state) = await signedIn(tester);
    final sock = FakeSocket();
    await tester.pumpWidget(wallApp(state, match, sock));
    await settle(tester);
    expect(sock.uri!.queryParameters['ticket'], 'tk');
    expect(sock.uri!.scheme, 'ws');
    expect(find.text('Anděl'), findsOneWidget, reason: 'shared place revealed after match');
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const Key('preset-ufo')));
    await settle(tester);
    expect(be.stickers.single['preset'], 'ufo');

    sock.push(jsonEncode({'type': 'sticker', 'sticker': {'id': 50, 'client_id': 'c', 'author_id': 'u2', 'kind': 'preset', 'preset': 'heart', 'x': 1500, 'y': 1500, 'z': 9}}));
    await settle(tester);
    expect(find.text('❤️'), findsWidgets);

    await tester.longPress(find.byKey(const ValueKey('c')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('reportSticker')));
    await settle(tester);
    expect(be.reports.single['sticker_id'], 50);

    sock.push(jsonEncode({'type': 'ended'}));
    await settle(tester);
    expect(find.byKey(const Key('wallEnded')), findsOneWidget);
  });

  testWidgets('offline queue resends with the same client_id', (tester) async {
    final (be, state) = await signedIn(tester);
    be.stickFailures = 1;
    final c = WallController(api: state.api, wallId: 7, me: 'u1', connect: (_) => FakeSocket());
    await c.start();
    await c.add(Sticker(clientId: newClientId(), authorId: 'u1', kind: 'preset', preset: 'star'));
    expect(c.queue, hasLength(1));
    expect(c.stickers.single.pending, isTrue);
    expect(c.online, isFalse);
    await c.flush();
    expect(c.queue, isEmpty);
    expect(c.stickers.single.pending, isFalse);
    expect(be.stickClientIds, hasLength(2));
    expect(be.stickClientIds[0], be.stickClientIds[1], reason: 'retry must reuse client_id');
    c.dispose();
  });

  testWidgets('ink pad sends normalized geometry only', (tester) async {
    final (be, state) = await signedIn(tester);
    final sock = FakeSocket();
    await tester.pumpWidget(wallApp(state, match, sock));
    await settle(tester);
    await tester.tap(find.byKey(const Key('drawSticker')));
    await settle(tester);
    final canvas = find.byKey(const Key('inkCanvas'));
    final g = await tester.startGesture(tester.getCenter(canvas));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(8, 3));
    }
    await g.up();
    await tester.pump();
    await tester.tap(find.byKey(const Key('stickIt')));
    await settle(tester);
    final ink = be.stickers.single['ink'] as Map<String, dynamic>;
    expect(ink.keys.toSet(), {'aspect', 'strokes'});
    final pts = [for (final s in ink['strokes'] as List) ...(s['p'] as List)];
    expect(pts, isNotEmpty);
    expect(pts.every((v) => (v as num) >= 0 && v <= 1), isTrue);
    expect((ink['strokes'] as List).first.keys.toSet(), {'c', 'w', 'p'});
  });

  testWidgets('unsent stickers survive an app restart', (tester) async {
    final (be, state) = await signedIn(tester);
    final store = MemoryQueueStore();
    be.stickFailures = 99; // offline the whole first session
    final c1 = WallController(api: state.api, wallId: 7, me: 'u1', connect: (_) => FakeSocket(), queueStore: store);
    await c1.start();
    final ink = InkDrawing(aspect: 1, strokes: [InkStroke(color: 2, width: 0.02, points: [0.1, 0.1, 0.9, 0.9])]);
    await c1.add(Sticker(clientId: newClientId(), authorId: 'u1', kind: 'ink', ink: ink, x: 5, y: 6));
    await c1.add(Sticker(clientId: newClientId(), authorId: 'u1', kind: 'preset', preset: 'ufo'));
    final ids = [for (final s in c1.queue) s.clientId];
    c1.dispose(); // app killed

    be.stickFailures = 0; // back online
    final c2 = WallController(api: state.api, wallId: 7, me: 'u1', connect: (_) => FakeSocket(), queueStore: store);
    await c2.start();
    expect(c2.queue, isEmpty);
    expect(be.stickers.map((s) => s['client_id']), ids, reason: 'same client_ids after restart');
    expect((be.stickers.first['ink'] as Map)['strokes'], isNotEmpty);
    expect(await store.load(7), isEmpty, reason: 'queue cleared once sent');
    c2.dispose();
  });

  test('client ids are v4 UUIDs', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    for (var i = 0; i < 50; i++) {
      expect(re.hasMatch(newClientId()), isTrue);
    }
  });

  test('every preset has an emoji and gentle presets are a subset', () {
    for (final p in gentlePresets) {
      expect(presetEmoji.containsKey(p), isTrue);
    }
  });
}
