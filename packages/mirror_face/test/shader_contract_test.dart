import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirror_face/mirror_face.dart';

/// _FilterShaderPainter sets uniforms by float slot: uResolution(2), then
/// uTime(1) for needsTime shaders, then uFaceCenter(2) + uFaceScale(1) for
/// needsFace shaders; the only sampler is uTexture. A shader declaring them in
/// another order (or declaring extra ones) compiles fine and renders garbage
/// on the device, so the declarations are checked here for every filter.
List<String> expectedUniforms(MirrorFilter f) => [
      'sampler2D uTexture',
      'vec2 uResolution',
      if (f.needsTime) 'float uTime',
      if (f.needsFace) ...['vec2 uFaceCenter', 'float uFaceScale'],
    ];

final _uniformRe = RegExp(r'^\s*uniform\s+(\w+)\s+(\w+)\s*;', multiLine: true);
final _blockComment = RegExp(r'/\*.*?\*/', dotAll: true);
final _lineComment = RegExp(r'//[^\n]*');

List<String> declaredUniforms(String source) {
  final code =
      source.replaceAll(_blockComment, '').replaceAll(_lineComment, '');
  return _uniformRe
      .allMatches(code)
      .map((m) => '${m.group(1)} ${m.group(2)}')
      .toList();
}

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final shaderFilters =
      MirrorFilter.values.where((f) => f.shaderAsset != null).toList();

  test('every filter except none has a shader', () {
    expect(shaderFilters.length, MirrorFilter.values.length - 1);
  });

  for (final f in shaderFilters) {
    group(f.name, () {
      final asset = f.shaderAsset!.replaceFirst('packages/mirror_face/', '');

      test('is registered in pubspec.yaml', () {
        expect(pubspec, contains('    - $asset\n'));
      });

      test('declares uniforms in contract order', () {
        final source = File(asset).readAsStringSync();
        expect(declaredUniforms(source), expectedUniforms(f),
            reason: '$asset must match needsTime=${f.needsTime}, '
                'needsFace=${f.needsFace}');
      });

      test('belongs to a collection', () {
        expect(f.collection, isNotNull);
      });
    });
  }
}
