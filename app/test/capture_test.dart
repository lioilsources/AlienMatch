import 'dart:ui' as ui;

import 'package:alienmatch/features/onboarding/capture_screen.dart';
import 'package:alienmatch/features/onboarding/filter_strip.dart';
import 'package:alienmatch/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_face/mirror_face.dart';

Future<ui.Image> _image(int w, int h) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF00FF00),
  );
  final pic = rec.endRecording();
  final img = await pic.toImage(w, h);
  pic.dispose();
  return img;
}

void main() {
  testWidgets('filter strip reaches every MirrorBooth filter, all free', (
    tester,
  ) async {
    var selected = MirrorFilter.none;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => FilterStrip(
              selected: selected,
              available: MirrorFilter.values.toSet(),
              onSelect: (f) => set(() => selected = f),
            ),
          ),
        ),
      ),
    );
    final seen = <MirrorFilter>{};
    for (final c in FilterCollection.values) {
      await tester.tap(find.byKey(Key('collection-${c.name}')));
      await tester.pumpAndSettle();
      for (final f in MirrorFilter.inCollection(c)) {
        final chip = find.byKey(Key('filter-${f.name}'));
        await tester.scrollUntilVisible(
          chip,
          80,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(selected, f);
        seen.add(f);
      }
    }
    expect(seen, MirrorFilter.values.toSet()..remove(MirrorFilter.none));
    expect(find.byIcon(Icons.lock), findsNothing);
    await tester.tap(find.byKey(const Key('filter-none')));
    expect(selected, MirrorFilter.none);
  });

  testWidgets('filters whose shader did not compile are hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FilterStrip(
            selected: MirrorFilter.none,
            available: const {MirrorFilter.glow},
            onSelect: (_) {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('filter-glow')), findsOneWidget);
    expect(find.byKey(const Key('filter-slim')), findsNothing);
  });

  test('upload is a centre square capped at 1024 px', () async {
    final portrait = await _image(1500, 3000);
    final sq = await squareCrop(portrait);
    expect((sq.width, sq.height), (1024, 1024));
    final small = await _image(300, 500);
    final sq2 = await squareCrop(small);
    expect((sq2.width, sq2.height), (300, 300));
  });

  test(
    'composed photo is mirrored across the axis, never the original',
    () async {
      // Left half red, right half blue: keeping the left half must give red on
      // both sides of a vertical axis.
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 20, 40),
        Paint()..color = const Color(0xFFFF0000),
      );
      canvas.drawRect(
        const Rect.fromLTWH(20, 0, 20, 40),
        Paint()..color = const Color(0xFF0000FF),
      );
      final pic = rec.endRecording();
      final still = await pic.toImage(40, 40);
      final out = await composeMirrorPhoto(
        PhotoComposeJob(
          still: still,
          mirrorStillHorizontally: false,
          screenSize: const Size(40, 40),
          rotationDeg: 0,
          mirrorAxisDeg: 90,
          directOnLeft: true,
          portraitAspect: 1,
        ),
      );
      final px = (await out.toByteData())!;
      int redAt(int x) => px.getUint8((20 * out.width + x) * 4);
      expect(redAt(3), greaterThan(200));
      expect(redAt(out.width - 4), greaterThan(200));
    },
  );
}
