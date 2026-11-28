// One session through the real widgets with a fake receiver: screens come
// out as the dictionary's enum, flows and events fire, and nothing from the
// account or profile is in any event.

import 'package:alienmatch/main.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:alienmatch/telemetry/telemetry_dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';
import 'package:ol1n_telemetry/testing.dart';

import 'fake_backend.dart';

Future<void> _init(WidgetTester tester) => tester.runAsync(
  () => Telemetry.init(
    app: 'alienmatch',
    appVersion: kAppVersion,
    dictionary: appDictionary,
    store: MemoryTelemetryStore(),
    lang: () => 'en',
    sink: FakeSink(),
    startTimer: false,
    observeLifecycle: false,
  ),
);

List<String> _screens() => [
  for (final e in Telemetry.debugQueue)
    if (e.name == 'screen_view') e.props['screen']! as String,
];

void _nothingFromTheAccount(String token) {
  for (final e in Telemetry.debugQueue) {
    for (final v in e.props.values) {
      expect('$v'.contains(token), isFalse, reason: '${e.name}: token');
      for (final p in ['genz', 'single', 'CZ-PHA', 'coffee', 'MID', 'LOW']) {
        expect('$v', isNot(p), reason: '${e.name}: profile value $p');
      }
    }
  }
}

void main() {
  setUp(Telemetry.resetForTest);
  tearDown(Telemetry.resetForTest);

  testWidgets('home tabs, pushed screens and the stats switch', (tester) async {
    await _init(tester);
    final be = FakeBackend()
      ..profile = FakeBackend.sampleProfile()
      ..hasPhoto = true;
    final token = 't' * 43;
    final tokens = MemoryTokens()..token = token;
    final state = AppState(api: be.api(), tokens: tokens);
    await tester.pumpWidget(AlienMatchApp(state: state));
    await state.load();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('statsSwitch')), findsOneWidget);
    await tester.tap(find.byKey(const Key('openFaces')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(_screens(), [
      'loading',
      'radar',
      'checkin',
      'settings',
      'faces',
      'settings',
    ]);
    final names = [for (final e in Telemetry.debugQueue) e.name];
    expect(names, contains('checkin_send'));
    expect(names, contains('feature_use'));
    _nothingFromTheAccount(token);
  });

  testWidgets('new user: welcome, account, profile steps', (tester) async {
    await _init(tester);
    final be = FakeBackend();
    final tokens = MemoryTokens();
    final state = AppState(api: be.api(), tokens: tokens);
    await tester.pumpWidget(AlienMatchApp(state: state));
    await state.load();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adult')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('g-genx')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('next')));
    await tester.pumpAndSettle();

    expect(_screens(), ['loading', 'welcome', 'onboarding']);
    final create = Telemetry.debugQueue.firstWhere(
      (e) => e.name == 'account_create',
    );
    expect(create.props['result'], 'ok');
    expect(create.props.containsKey('mood_consent'), isFalse);
    expect(
      Telemetry.debugQueue.where((e) => e.name == 'onboarding_start'),
      hasLength(1),
    );
    _nothingFromTheAccount(tokens.token!);
  });

  testWidgets('without a key the stats switch is hidden', (tester) async {
    final be = FakeBackend()
      ..profile = FakeBackend.sampleProfile()
      ..hasPhoto = true;
    final state = AppState(
      api: be.api(),
      tokens: MemoryTokens()..token = 't' * 43,
    );
    await tester.pumpWidget(AlienMatchApp(state: state));
    await state.load();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('statsSwitch')), findsNothing);
  });
}
