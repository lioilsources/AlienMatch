import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_face/mirror_face.dart';

/// 40×20 still: left half red, right half blue, with a green column at x=2.
Future<ui.Image> _still() async {
  const w = 40, h = 20;
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final green = x == 2;
      px[i] = (!green && x < w / 2) ? 255 : 0;
      px[i + 1] = green ? 255 : 0;
      px[i + 2] = (!green && x >= w / 2) ? 255 : 0;
      px[i + 3] = 255;
    }
  }
  final c = await ui.ImmutableBuffer.fromUint8List(px);
  final d = ui.ImageDescriptor.raw(c, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await d.instantiateCodec();
  return (await codec.getNextFrame()).image;
}

Future<List<int>> _rgbAt(ui.Image img, int x, int y) async {
  final bd = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * img.width + x) * 4;
  return [bd.getUint8(i), bd.getUint8(i + 1), bd.getUint8(i + 2)];
}

void main() {
  testWidgets('L+L keeps the left half on both sides', (tester) async {
    await tester.runAsync(() async {
      final still = await _still();
      final out = await symmetricVariant(still, MirrorSide.left);
      expect(out.width, 20); // square limited by height
      expect(out.height, 20);
      expect(await _rgbAt(out, 1, 10), [255, 0, 0]);
      expect(await _rgbAt(out, 18, 10), [255, 0, 0]);
    });
  });

  testWidgets('R+R keeps the right half', (tester) async {
    await tester.runAsync(() async {
      final out = await symmetricVariant(await _still(), MirrorSide.right);
      expect(await _rgbAt(out, 1, 10), [0, 0, 255]);
      expect(await _rgbAt(out, 18, 10), [0, 0, 255]);
    });
  });

  testWidgets('result is mirror-symmetric around the axis', (tester) async {
    await tester.runAsync(() async {
      final out = await symmetricVariant(await _still(), MirrorSide.left, axisX: 0.4);
      for (var x = 0; x < out.width ~/ 2; x++) {
        expect(await _rgbAt(out, x, 5), await _rgbAt(out, out.width - 1 - x, 5), reason: 'x=$x');
      }
    });
  });

  testWidgets('front-camera still is flipped so L means left as seen', (tester) async {
    await tester.runAsync(() async {
      // Seen on screen the flipped still has blue on the left.
      final out = await symmetricVariant(await _still(), MirrorSide.left, mirrorStillHorizontally: true);
      expect(await _rgbAt(out, 1, 10), [0, 0, 255]);
      expect(await _rgbAt(out, 18, 10), [0, 0, 255]);
    });
  });

  testWidgets('maxSize caps the output', (tester) async {
    await tester.runAsync(() async {
      final out = await symmetricVariant(await _still(), MirrorSide.left, maxSize: 8);
      expect(out.width, 8);
    });
  });
}
