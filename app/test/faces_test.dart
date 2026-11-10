import 'dart:typed_data';

import 'package:alienmatch/main.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:alienmatch/state/face_album.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'fake_backend.dart';

Uint8List jpeg(int shade) => img.encodeJpg(
  img.Image(width: 4, height: 4)..clear(img.ColorRgb8(shade, shade, shade)),
);

FaceAlbum album() {
  var t = 1000;
  return FaceAlbum(
    MemoryFaceStorage(),
    clock: () => DateTime.fromMicrosecondsSinceEpoch(t++),
  );
}

void main() {
  test(
    'album keeps newest first, caps at 12 and never drops the profile photo',
    () async {
      final a = album();
      final first = await a.add(jpeg(10));
      final second = await a.add(jpeg(20));
      expect(a.faces.map((f) => f.id), [second.id, first.id]);

      await a.markActive(first.id);
      await a.remove(first.id);
      expect(a.faces, hasLength(2), reason: 'active face cannot be deleted');
      await a.remove(second.id);
      expect(a.faces.map((f) => f.id), [first.id]);

      for (var i = 0; i < FaceAlbum.max - 1; i++) {
        await a.add(jpeg(i));
      }
      expect(a.full, isTrue);
      expect(() => a.add(jpeg(1)), throwsA(isA<AlbumFullException>()));
    },
  );

  test('album survives a restart and forgets a missing active face', () async {
    final storage = MemoryFaceStorage();
    final a = FaceAlbum(storage);
    final f = await a.add(jpeg(5));
    await a.markActive(f.id);
    final again = FaceAlbum(storage);
    await again.load();
    expect(again.faces.single.id, f.id);
    expect(again.activeId, f.id);

    storage.meta.active = 'gone';
    final third = FaceAlbum(storage);
    await third.load();
    expect(third.activeId, isNull);
  });

  Future<(FakeBackend, AppState)> pumpHome(
    WidgetTester tester,
    FaceAlbum a,
  ) async {
    final be = FakeBackend()
      ..profile = FakeBackend.sampleProfile()
      ..hasPhoto = true;
    final state = AppState(
      api: be.api(),
      tokens: MemoryTokens()..token = 't' * 43,
      album: a,
    );
    await tester.pumpWidget(AlienMatchApp(state: state));
    await state.load();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('openFaces')));
    await tester.pumpAndSettle();
    return (be, state);
  }

  testWidgets('switching the profile photo uploads only the chosen face', (
    tester,
  ) async {
    final a = album();
    final (old, other) =
        await tester.runAsync(() async {
              final o = await a.add(jpeg(30));
              final n = await a.add(jpeg(200));
              await a.markActive(o.id);
              return (o, n);
            })
            as (Face, Face);
    final (be, _) = await pumpHome(tester, a);

    expect(find.byKey(Key('deleteFace-${old.id}')), findsNothing);
    expect(find.byKey(Key('deleteFace-${other.id}')), findsOneWidget);
    expect(find.byKey(const Key('newFace')), findsOneWidget);

    await tester.tap(find.byKey(Key('face-${other.id}')));
    await tester.pumpAndSettle();
    expect(be.photos, hasLength(1));
    expect(be.photos.single, other.jpeg);
    expect(a.activeId, other.id);

    // Now the old one can go.
    await tester.tap(find.byKey(Key('deleteFace-${old.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteFace')));
    await tester.pumpAndSettle();
    expect(a.faces.map((f) => f.id), [other.id]);
    expect(
      be.photos,
      hasLength(1),
      reason: 'deleting a local face uploads nothing',
    );
  });

  testWidgets('deleting the account wipes the faces on the phone', (
    tester,
  ) async {
    final a = album();
    await tester.runAsync(() => a.add(jpeg(1)));
    final be = FakeBackend()
      ..profile = FakeBackend.sampleProfile()
      ..hasPhoto = true;
    final state = AppState(
      api: be.api(),
      tokens: MemoryTokens()..token = 't' * 43,
      album: a,
    );
    await state.load();
    await state.deleteAccount();
    expect(a.faces, isEmpty);
    expect(a.activeId, isNull);
  });
}
