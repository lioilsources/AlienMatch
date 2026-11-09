import 'package:alienmatch/main.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

Future<(FakeBackend, AppState, MemoryTokens)> pumpApp(WidgetTester tester, {bool signedIn = false, bool complete = false}) async {
  final be = FakeBackend();
  final tokens = MemoryTokens();
  if (signedIn) tokens.token = 't' * 43;
  if (complete) {
    be.profile = FakeBackend.sampleProfile();
    be.hasPhoto = true;
  }
  final state = AppState(api: be.api(), tokens: tokens);
  await tester.pumpWidget(AlienMatchApp(state: state));
  await state.load();
  await tester.pumpAndSettle();
  return (be, state, tokens);
}

void main() {
  testWidgets('welcome requires 18+ and creates an anonymous account without mood consent', (tester) async {
    final (be, state, tokens) = await pumpApp(tester);
    expect(find.byType(TextField), findsNothing);
    final start = find.byKey(const Key('start'));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.tap(find.byKey(const Key('adult')));
    await tester.pump();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(tokens.token, isNotNull);
    expect(state.stage, Stage.onboarding);
    final create = be.requests.firstWhere((r) => r.url.path == '/v1/accounts');
    expect(create.body, contains('"mood_consent":false'));
  });

  testWidgets('onboarding is wordless: the only text field is the nickname', (tester) async {
    final (be, _, _) = await pumpApp(tester, signedIn: true);
    Future<void> next() async {
      await tester.tap(find.byKey(const Key('next')));
      await tester.pumpAndSettle();
    }

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('g-genx')));
    await tester.pump();
    await next();
    await tester.tap(find.byKey(const Key('g-divorced')));
    await tester.pump();
    await next();
    expect(find.byType(TextField), findsNothing);
    await next(); // kids optional
    expect(tester.widget<FilledButton>(find.byKey(const Key('next'))).onPressed, isNull, reason: 'intents required');
    await tester.tap(find.byKey(const Key('m-wine')));
    await tester.pump();
    await next();
    await next(); // seek: any
    expect(find.byType(TextField), findsNothing);
    await next(); // modes
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const Key('nickname')), findsOneWidget);
    await tester.tap(find.byKey(const Key('next')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // camera screen spinner never settles
    }
    expect(find.byType(TextField), findsNothing, reason: 'camera step is wordless');
    expect(be.profile!['generation'], 'genx');
    expect(be.profile!['status'], 'divorced');
    expect(be.profile!['intents'], ['wine']);
    expect((be.profile!['nickname'] as String).length, lessThanOrEqualTo(12));
  });

  testWidgets('off radar without a fresh check-in', (tester) async {
    await pumpApp(tester, signedIn: true, complete: true);
    expect(find.byKey(const Key('offRadar')), findsOneWidget);
  });

  testWidgets('radar shows planets and a shared star', (tester) async {
    final be = FakeBackend()
      ..profile = FakeBackend.sampleProfile()
      ..hasPhoto = true
      ..radar = {
        'off_radar': false,
        'planets': [
          {'user_id': 'a', 'kind': 'match', 'level': 'HIGH', 'trend': 'RISING', 'intents': ['coffee'], 'star': 'stop:pid:N1'},
          {'user_id': 'b', 'kind': 'encourage', 'level': 'LOW', 'trend': 'FLAT', 'intents': ['tea'], 'weak_signal': true},
        ],
      };
    final tokens = MemoryTokens()..token = 't' * 43;
    final state = AppState(api: be.api(), tokens: tokens);
    await tester.pumpWidget(AlienMatchApp(state: state));
    await state.load();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // pulsing auras never settle
    }
    expect(find.byKey(const Key('planet-a')), findsOneWidget);
    expect(find.byKey(const Key('planet-b')), findsOneWidget);
    expect(find.text('⭐'), findsOneWidget);
  });

  testWidgets('check-in sends mode self and shows the support card', (tester) async {
    final (be, _, _) = await pumpApp(tester, signedIn: true, complete: true);
    be.checkinResult = {'level': 'LOW', 'trend': 'FALLING', 'support_card': true, 'ask_again_soon': false};
    await tester.tap(find.byIcon(Icons.wb_sunny_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendSignal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('supportCard')), findsOneWidget);
    expect(find.textContaining('116 123'), findsOneWidget);
    final req = be.requests.lastWhere((r) => r.url.path == '/v1/checkins');
    expect(req.body, contains('"mode":"self"'));
  });

  testWidgets('home has no text fields except the place search', (tester) async {
    await pumpApp(tester, signedIn: true, complete: true);
    for (final icon in [Icons.radar, Icons.wb_sunny_outlined, Icons.tune]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsNothing, reason: 'tab $icon');
    }
    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).hitTestable(), findsOneWidget);
  });

  testWidgets('places: search, pick and save', (tester) async {
    final (be, _, _) = await pumpApp(tester, signedIn: true, complete: true);
    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('placeSearch')), 'andel');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(be.myPlaces, ['stop:pid:N1040']);
  });

  testWidgets('delete account returns to welcome and clears the token', (tester) async {
    final (be, state, tokens) = await pumpApp(tester, signedIn: true, complete: true);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deleteAccount')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDelete')));
    await tester.pumpAndSettle();
    expect(be.deleted, isTrue);
    expect(tokens.token, isNull);
    expect(state.stage, Stage.welcome);
  });
}
