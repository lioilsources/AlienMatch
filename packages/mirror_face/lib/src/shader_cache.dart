import 'dart:ui';

import 'mirror_filter.dart';

typedef ShaderCache = Map<MirrorFilter, FragmentProgram>;

/// Compiles every filter shader once. Filters whose shader fails to load are
/// left out, so the strip can hide them instead of crashing the camera.
Future<ShaderCache> loadShaderCache() async {
  final cache = <MirrorFilter, FragmentProgram>{};
  for (final filter in MirrorFilter.values) {
    final asset = filter.shaderAsset;
    if (asset == null) continue;
    try {
      cache[filter] = await FragmentProgram.fromAsset(asset);
    } catch (_) {}
  }
  return cache;
}
