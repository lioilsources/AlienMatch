import 'dart:convert';
import 'dart:typed_data';

import 'package:alienmatch/features/checkin/checkin_screen.dart';
import 'package:alienmatch/features/checkin/recorder.dart';
import 'package:alienmatch/l10n/app_localizations.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

class FakeRecorder implements CheckinRecorder {
  FakeRecorder({this.allowed = true});
  final bool allowed;
  bool? video;
  int frames = 0;
  bool disposed = false;
  @override
  CameraController? get camera => null;
  @override
  Future<bool> prepare({required bool video}) async {
    this.video = video;
    return allowed;
  }

  @override
  Future<void> start() async {}
  @override
  Future<void> captureFrame() async => frames++;
  @override
  Future<Recording> stop() async => Recording(
        [for (var i = 0; i < frames; i++) Uint8List.fromList([0xFF, 0xD8, 0xFF, i])],
        Uint8List.fromList(utf8.encode('voice-bytes')),
      );
  @override
  Future<void> dispose() async => disposed = true;
}

Future<(FakeBackend, FakeRecorder)> pump(WidgetTester tester, {bool consent = true, bool scoring = true, bool allowed = true}) async {
  final be = FakeBackend()
    ..profile = FakeBackend.sampleProfile()
    ..hasPhoto = true
    ..moodConsent = consent
    ..moodScoring = scoring;
  final state = AppState(api: be.api(), tokens: MemoryTokens()..token = 't' * 43);
  await state.load();
  final rec = FakeRecorder(allowed: allowed);
  await tester.pumpWidget(AppScope(
    state: state,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CheckinScreen(recorderFactory: () => rec, promptLength: const Duration(milliseconds: 200))),
    ),
  ));
  await tester.pumpAndSettle();
  return (be, rec);
}

void main() {
  testWidgets('video check-in: prompts, three frames and voice, then own rating', (tester) async {
    final (be, rec) = await pump(tester);
    await tester.tap(find.byKey(const Key('modeVideo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('prompt0')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.byKey(const Key('prompt1')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(rec.video, isTrue);
    expect(rec.frames, 3);
    expect(rec.disposed, isTrue);
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    final body = latin1.decode(be.lastMedia!.bodyBytes);
    expect('name="frame"'.allMatches(body).length, 3);
    expect(body, contains('name="audio"'));
    expect(body, contains('video'));
    expect(be.requests.where((r) => r.url.path == '/v1/checkins'), isEmpty);
    expect(find.byKey(const Key('signalUsed')), findsOneWidget);
  });

  testWidgets('voice check-in sends no frames', (tester) async {
    final (be, rec) = await pump(tester);
    await tester.tap(find.byKey(const Key('modeVoice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(rec.video, isFalse);
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    final body = latin1.decode(be.lastMedia!.bodyBytes);
    expect(body, isNot(contains('name="frame"')));
    expect(body, contains('voice'));
  });

  testWidgets('without consent nothing is recorded', (tester) async {
    final (be, _) = await pump(tester, consent: false);
    expect(find.byKey(const Key('modeVideo')), findsNothing);
    expect(be.requests.any((r) => r.url.path == '/v1/config'), isFalse);
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    expect(be.lastMedia, isNull);
  });

  testWidgets('without scoring on the server nothing is recorded', (tester) async {
    final (be, _) = await pump(tester, scoring: false);
    expect(find.byKey(const Key('modeVideo')), findsNothing);
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    expect(be.requests.last.body, contains('"mode":"self"'));
  });

  testWidgets('missing permission is explained', (tester) async {
    final (_, rec) = await pump(tester, allowed: false);
    await tester.tap(find.byKey(const Key('modeVideo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noPermission')), findsOneWidget);
    expect(rec.disposed, isTrue);
  });

  testWidgets('opening the check-in warms up the models; pending signal is explained', (tester) async {
    final (be, _) = await pump(tester);
    expect(be.warmups, 1);
    be.scoringPending = true;
    await tester.tap(find.byKey(const Key('modeVoice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signalPending')), findsOneWidget);
    expect(find.byKey(const Key('signalUsed')), findsNothing);
  });

  testWidgets('no warm-up without consent', (tester) async {
    final (be, _) = await pump(tester, consent: false);
    expect(be.warmups, 0);
  });

  testWidgets('rating only is always possible', (tester) async {
    final (be, _) = await pump(tester);
    await tester.tap(find.byKey(const Key('modeSelf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    expect(be.lastMedia, isNull);
    expect(find.byKey(const Key('checkinDone')), findsOneWidget);
  });
}
