import 'package:alienmatch/features/settings/faces_screen.dart';
import 'package:alienmatch/features/stars/stars_screen.dart';
import 'package:alienmatch/l10n/app_localizations.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:alienmatch/state/face_album.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';
import 'faces_test.dart' show jpeg;

Map<String, dynamic> star(String id, {int? rating}) => {
  'user_id': id,
  'photo_id': 'p-$id',
  'level': 'HIGH',
  'trend': 'RISING',
  'rating': rating,
};

Future<FakeBackend> pumpStars(
  WidgetTester tester,
  List<Map<String, dynamic>> deck,
) async {
  final be = FakeBackend()
    ..profile = FakeBackend.sampleProfile()
    ..hasPhoto = true
    ..stars = deck;
  final state = AppState(
    api: be.api(),
    tokens: MemoryTokens()..token = 't' * 43,
  );
  await state.load();
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StarsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return be;
}

Future<void> swipe(WidgetTester tester, String id, Offset by) async {
  await tester.drag(find.byKey(Key('star-$id')), by);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('up likes, down dislikes, each moves on to the next face', (
    tester,
  ) async {
    final be = await pumpStars(tester, [star('a'), star('b'), star('c')]);
    await swipe(tester, 'a', const Offset(0, -200));
    expect(be.ratings['a'], [1]);
    expect(find.byKey(const Key('star-b')), findsOneWidget);

    await swipe(tester, 'b', const Offset(0, 200));
    expect(be.ratings['b'], [-1]);
    expect(find.byKey(const Key('star-c')), findsOneWidget);
  });

  testWidgets('browsing past without rating counts as seen, never overwrites', (
    tester,
  ) async {
    final be = await pumpStars(tester, [
      star('a'),
      star('b', rating: 1),
      star('c'),
    ]);
    await swipe(tester, 'a', const Offset(-600, 0)); // next, unrated
    expect(be.ratings['a'], [0]);
    await swipe(tester, 'b', const Offset(-600, 0)); // already liked
    expect(be.ratings['b'], isNull, reason: 'a like is not reset to seen');
    expect(find.byKey(const Key('star-c')), findsOneWidget);
  });

  testWidgets('going back shows my rating and it can be changed', (
    tester,
  ) async {
    final be = await pumpStars(tester, [star('a'), star('b')]);
    await swipe(tester, 'a', const Offset(0, -200));
    await swipe(tester, 'b', const Offset(600, 0)); // back to a
    expect(find.byKey(const Key('star-a')), findsOneWidget);
    expect(
      find.text('👍 ${lookupAppLocalizations(const Locale('en')).like}'),
      findsOneWidget,
    );
    await swipe(tester, 'a', const Offset(0, 200));
    expect(be.ratings['a'], [1, -1]);
  });

  testWidgets('an empty sky says so', (tester) async {
    await pumpStars(tester, []);
    expect(find.byKey(const Key('starsEmpty')), findsOneWidget);
  });

  testWidgets('my faces show the community echo; no dislikes while hidden', (
    tester,
  ) async {
    final be = FakeBackend()
      ..profile = FakeBackend.sampleProfile()
      ..hasPhoto = true;
    final album = FaceAlbum(MemoryFaceStorage());
    final state = AppState(
      api: be.api(),
      tokens: MemoryTokens()..token = 't' * 43,
      album: album,
    );
    await state.load();
    final f = (await tester.runAsync(() async {
      final f = await album.add(jpeg(80));
      await state.useFace(f); // upload returns photo id 'ph1'
      return f;
    }))!;
    expect(album.photoIdOf(f.id), 'ph1');
    be.faceStats = {
      'dislikes_hidden': true,
      'faces': [
        {
          'photo_id': 'ph1',
          'current': true,
          'likes': 4,
          'dislikes': null,
          'seen': 9,
        },
        {
          'photo_id': 'old',
          'current': false,
          'likes': 1,
          'dislikes': null,
          'seen': 3,
        },
      ],
    };
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FacesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('👀 9 · 👍 4'), findsOneWidget);
    expect(
      find.text('👀 3 · 👍 1'),
      findsOneWidget,
      reason: 'older face listed',
    );
    expect(find.textContaining('👎'), findsNothing);
    expect(find.byKey(const Key('dislikesHidden')), findsOneWidget);
  });
}
