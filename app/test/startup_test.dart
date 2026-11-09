import 'dart:async';

import 'package:alienmatch/api/api.dart';
import 'package:alienmatch/main.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fake_backend.dart';

class BrokenTokens implements TokenStore {
  @override
  Future<String?> read() async => throw StateError('keychain unavailable');
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

// Regression: the app spun forever on the iPhone when startup failed.
void main() {
  testWidgets('unreadable token store does not spin forever', (tester) async {
    final state = AppState(api: FakeBackend().api(), tokens: BrokenTokens());
    await tester.pumpWidget(AlienMatchApp(state: state));
    await state.load();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(state.stage, isNot(Stage.loading));
  });

  testWidgets('a hanging server ends in a retry screen, not an endless spinner', (tester) async {
    final hang = MockClient((_) => Completer<http.Response>().future);
    final state = AppState(api: Api(client: hang, baseUrl: 'http://test'), tokens: MemoryTokens()..token = 't' * 43);
    await tester.pumpWidget(AlienMatchApp(state: state));
    unawaited(state.load());
    await tester.pump(const Duration(seconds: 25));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('startupRetry')), findsOneWidget);
  });
}
