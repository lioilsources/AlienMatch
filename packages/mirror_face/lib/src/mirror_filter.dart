/// Filter collections, grouped like in MirrorBooth. All are free here.
enum FilterCollection {
  pretty('Pretty'),
  ugly('Ugly'),
  art('Art'),
  fantasy('Fantasy');

  const FilterCollection(this.label);

  final String label;
}

// Copied from MirrorBooth (lib/core/mirror_filter.dart); keep the
// `// @shadergen:*` markers so new shaders can be ported the same way.
enum MirrorFilter {
  none,
  // Pretty
  glow,
  slim,
  doll,
  chibi,
  lips,
  // @shadergen:enum:pretty
  // Ugly
  bigNose,
  alien,
  melt,
  bigEars,
  longNeck,
  // @shadergen:enum:ugly
  // Art
  pencil,
  comic,
  glitch,
  neon,
  thermal,
  oil,
  crt,
  popArt,
  // @shadergen:enum:art
  // Fantasy
  vampire,
  zombie,
  ghost,
  demon,
  cyborg,
  frozen,
  // @shadergen:enum:fantasy
  ;

  String get label => switch (this) {
        MirrorFilter.none => 'None',
        MirrorFilter.glow => 'Glow',
        MirrorFilter.slim => 'Slim',
        MirrorFilter.doll => 'Doll',
        MirrorFilter.chibi => 'Chibi',
        MirrorFilter.lips => 'Lips',
        MirrorFilter.bigNose => 'Nose',
        MirrorFilter.alien => 'Alien',
        MirrorFilter.melt => 'Melt',
        MirrorFilter.bigEars => 'Ears',
        MirrorFilter.longNeck => 'Neck',
        MirrorFilter.pencil => 'Pencil',
        MirrorFilter.comic => 'Comic',
        MirrorFilter.glitch => 'Glitch',
        MirrorFilter.neon => 'Neon',
        MirrorFilter.thermal => 'Heat',
        MirrorFilter.oil => 'Oil',
        MirrorFilter.crt => 'CRT',
        MirrorFilter.popArt => 'Pop',
        MirrorFilter.vampire => 'Vamp',
        MirrorFilter.zombie => 'Zombie',
        MirrorFilter.ghost => 'Ghost',
        MirrorFilter.demon => 'Demon',
        MirrorFilter.cyborg => 'Cyborg',
        MirrorFilter.frozen => 'Frost',
        // @shadergen:label
      };

  String get icon => switch (this) {
        MirrorFilter.none => 'O',
        MirrorFilter.glow => '✧',
        MirrorFilter.slim => '|',
        MirrorFilter.doll => '◉',
        MirrorFilter.chibi => '◕',
        MirrorFilter.lips => 'ω',
        MirrorFilter.bigNose => '▲',
        MirrorFilter.alien => 'Λ',
        MirrorFilter.melt => '≈',
        MirrorFilter.bigEars => '◖',
        MirrorFilter.longNeck => 'Y',
        MirrorFilter.pencil => '/',
        MirrorFilter.comic => '!',
        MirrorFilter.glitch => '~',
        MirrorFilter.neon => 'N',
        MirrorFilter.thermal => 'T',
        MirrorFilter.oil => 'Q',
        MirrorFilter.crt => 'V',
        MirrorFilter.popArt => '●',
        MirrorFilter.vampire => '†',
        MirrorFilter.zombie => 'Ж',
        MirrorFilter.ghost => '◌',
        MirrorFilter.demon => 'Ψ',
        MirrorFilter.cyborg => '▣',
        MirrorFilter.frozen => '❆',
        // @shadergen:icon
      };

  bool get needsTime => switch (this) {
        MirrorFilter.melt => true,
        MirrorFilter.glitch => true,
        MirrorFilter.neon => true,
        MirrorFilter.ghost => true,
        MirrorFilter.demon => true,
        MirrorFilter.cyborg => true,
        MirrorFilter.frozen => true,
        // @shadergen:needsTime
        _ => false,
      };

  /// Whether the shader declares uFaceCenter/uFaceScale uniforms. Today they
  /// receive constant defaults (mirror axis premise: face centered on the
  /// canvas); a face detector can feed real coordinates later.
  bool get needsFace => switch (this) {
        MirrorFilter.slim => true,
        MirrorFilter.doll => true,
        MirrorFilter.chibi => true,
        MirrorFilter.lips => true,
        MirrorFilter.bigNose => true,
        MirrorFilter.alien => true,
        MirrorFilter.bigEars => true,
        MirrorFilter.longNeck => true,
        MirrorFilter.vampire => true,
        MirrorFilter.zombie => true,
        MirrorFilter.demon => true,
        // @shadergen:needsFace
        _ => false,
      };

  // Deliberately no wildcard branch: a new filter must be assigned to a
  // collection consciously (compile error otherwise).
  FilterCollection? get collection => switch (this) {
        MirrorFilter.none => null,
        // @shadergen:collection:pretty
        MirrorFilter.glow ||
        MirrorFilter.slim ||
        MirrorFilter.doll ||
        MirrorFilter.chibi ||
        MirrorFilter.lips =>
          FilterCollection.pretty,
        // @shadergen:collection:ugly
        MirrorFilter.bigNose ||
        MirrorFilter.alien ||
        MirrorFilter.melt ||
        MirrorFilter.bigEars ||
        MirrorFilter.longNeck =>
          FilterCollection.ugly,
        // @shadergen:collection:art
        MirrorFilter.pencil ||
        MirrorFilter.comic ||
        MirrorFilter.glitch ||
        MirrorFilter.neon ||
        MirrorFilter.thermal ||
        MirrorFilter.oil ||
        MirrorFilter.crt ||
        MirrorFilter.popArt =>
          FilterCollection.art,
        // @shadergen:collection:fantasy
        MirrorFilter.vampire ||
        MirrorFilter.zombie ||
        MirrorFilter.ghost ||
        MirrorFilter.demon ||
        MirrorFilter.cyborg ||
        MirrorFilter.frozen =>
          FilterCollection.fantasy,
      };

  static List<MirrorFilter> inCollection(FilterCollection c) =>
      values.where((f) => f.collection == c).toList();

  String? get shaderAsset => switch (this) {
        MirrorFilter.none => null,
        MirrorFilter.glow => 'packages/mirror_face/shaders/filter_glow.frag',
        MirrorFilter.slim => 'packages/mirror_face/shaders/filter_slim.frag',
        MirrorFilter.doll => 'packages/mirror_face/shaders/filter_doll.frag',
        MirrorFilter.chibi => 'packages/mirror_face/shaders/filter_chibi.frag',
        MirrorFilter.lips => 'packages/mirror_face/shaders/filter_lips.frag',
        MirrorFilter.bigNose => 'packages/mirror_face/shaders/filter_big_nose.frag',
        MirrorFilter.alien => 'packages/mirror_face/shaders/filter_alien.frag',
        MirrorFilter.melt => 'packages/mirror_face/shaders/filter_melt.frag',
        MirrorFilter.bigEars => 'packages/mirror_face/shaders/filter_big_ears.frag',
        MirrorFilter.longNeck => 'packages/mirror_face/shaders/filter_long_neck.frag',
        MirrorFilter.pencil => 'packages/mirror_face/shaders/filter_pencil.frag',
        MirrorFilter.comic => 'packages/mirror_face/shaders/filter_comic.frag',
        MirrorFilter.glitch => 'packages/mirror_face/shaders/filter_glitch.frag',
        MirrorFilter.neon => 'packages/mirror_face/shaders/filter_neon.frag',
        MirrorFilter.thermal => 'packages/mirror_face/shaders/filter_thermal.frag',
        MirrorFilter.oil => 'packages/mirror_face/shaders/filter_oil.frag',
        MirrorFilter.crt => 'packages/mirror_face/shaders/filter_crt.frag',
        MirrorFilter.popArt => 'packages/mirror_face/shaders/filter_pop_art.frag',
        MirrorFilter.vampire => 'packages/mirror_face/shaders/filter_vampire.frag',
        MirrorFilter.zombie => 'packages/mirror_face/shaders/filter_zombie.frag',
        MirrorFilter.ghost => 'packages/mirror_face/shaders/filter_ghost.frag',
        MirrorFilter.demon => 'packages/mirror_face/shaders/filter_demon.frag',
        MirrorFilter.cyborg => 'packages/mirror_face/shaders/filter_cyborg.frag',
        MirrorFilter.frozen => 'packages/mirror_face/shaders/filter_frozen.frag',
        // @shadergen:shaderAsset
      };
}
