// The checks every ol1n app copies from ol1n_telemetry's example: dictionary
// ↔ docs/telemetry.md, no free text, version constant ↔ pubspec, literal
// event names, no key → no network, off → nothing.

import 'dart:io';

import 'package:alienmatch/telemetry/telemetry_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ol1n_telemetry/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('docs/telemetry.md lists exactly the dictionary', () {
    final doc = File('../docs/telemetry.md').readAsStringSync();
    final problems = telemetryDocProblems(appDictionary, doc);
    if (problems.isNotEmpty) {
      // ignore: avoid_print
      print(telemetryDocSkeleton(appDictionary));
    }
    expect(problems, isEmpty);
  });

  test('no property is free text', () {
    expect(telemetryDictionaryProblems(appDictionary), isEmpty);
  });

  test('app version matches pubspec.yaml', () {
    expect(
      telemetryVersionProblems(
        kAppVersion,
        File('pubspec.yaml').readAsStringSync(),
      ),
      isEmpty,
    );
  });

  test('the code sends only dictionary events, and every one of them', () {
    expect(telemetryTrackCallProblems(appDictionary), isEmpty);
  });

  test('no key, no network', () async {
    expect(await telemetryNoKeyProblems(appDictionary), isEmpty);
  }, skip: const bool.fromEnvironment('TELEMETRY_DEBUG'));

  test('off means nothing', () async {
    expect(await telemetryOffProblems(appDictionary), isEmpty);
  });

  test('nothing linkable to the account is in the dictionary', () {
    // AlienMatch's own rule: no token, id, nickname, region, generation,
    // kids, mood, consent or anything from the profile, walls or check-ins.
    const banned = [
      'token',
      'user',
      'id',
      'nick',
      'region',
      'generation',
      'status',
      'kids',
      'mood',
      'level',
      'trend',
      'aura',
      'consent',
      'intent',
      'beacon',
      'encourage',
      'place',
      'mode',
      'rating',
      'value',
      'kind',
    ];
    final names = {
      ...appDictionary.common.keys,
      for (final e in appDictionary.appEvents) ...appDictionary.events[e]!.keys,
    };
    for (final n in names) {
      for (final b in banned) {
        expect(
          n == b || n.startsWith('${b}_') || n.endsWith('_$b'),
          isFalse,
          reason: 'property $n',
        );
      }
    }
  });
}
