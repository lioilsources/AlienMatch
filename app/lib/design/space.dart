import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Deep-space palette. Mood is never shown as a number: only as aura colour
/// and pulse speed around a planet.
abstract final class Space {
  static const void_ = Color(0xFF07060F);
  static const nebula = Color(0xFF1A1433);
  static const ink = Color(0xFFE9E6FF);
  static const dim = Color(0xFF8C86B3);
  static const accent = Color(0xFF7CF5C8); // alien green
  static const beacon = Color(0xFFFFC857); // warm beacon light

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: void_,
    ).copyWith(primary: accent, secondary: beacon, onSurface: ink);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: void_,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: void_,
        foregroundColor: ink,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: nebula,
        selectedColor: accent.withValues(alpha: 0.25),
        side: const BorderSide(color: Color(0x337CF5C8)),
        labelStyle: const TextStyle(color: ink),
      ),
    );
  }

  /// Aura colour for a mood level: grey planet → supernova.
  static Color aura(String level) => switch (level) {
    'HIGH' => const Color(0xFFFFE27A),
    'MID' => const Color(0xFF8FD3FF),
    _ => const Color(0xFF9C8FB8),
  };

  /// Pulse period: rising pulses faster, falling slower.
  static Duration pulse(String trend) => switch (trend) {
    'RISING' => const Duration(milliseconds: 1400),
    'FALLING' => const Duration(milliseconds: 3600),
    _ => const Duration(milliseconds: 2400),
  };
}

/// Icon sets. Placeholders until the illustrated sticker set (one art style,
/// ComfyUI pipeline) exists; labels are for accessibility only.
class Glyph {
  const Glyph(this.id, this.emoji);
  final String id;
  final String emoji;
}

abstract final class Glyphs {
  static const generations = [
    Glyph('genz', '🪐'),
    Glyph('millennial', '🌍'),
    Glyph('genx', '🌕'),
    Glyph('boomer', '☀️'),
  ];
  static const statuses = [
    Glyph('single', '🛸'),
    Glyph('married', '💍'),
    Glyph('divorced', '💔'),
    Glyph('complicated', '🌀'),
  ];
  static const intents = [
    Glyph('flirt', '😉'),
    Glyph('sex', '🔥'),
    Glyph('chat', '💬'),
    Glyph('coffee', '☕'),
    Glyph('beer', '🍺'),
    Glyph('wine', '🍷'),
    Glyph('tea', '🍵'),
    Glyph('walk', '🚶'),
    Glyph('play', '🎲'),
  ];
  static const kidsFlags = [
    Glyph('boys', '👦'),
    Glyph('girls', '👧'),
    Glyph('twins', '👯'),
    Glyph('triplets', '👨‍👩‍👧‍👦'),
  ];

  static String emojiOf(List<Glyph> set, String id) => set
      .firstWhere((g) => g.id == id, orElse: () => const Glyph('', '✨'))
      .emoji;

  static String label(AppLocalizations l, String id) => switch (id) {
    'genz' => l.genGenz,
    'millennial' => l.genMillennial,
    'genx' => l.genGenx,
    'boomer' => l.genBoomer,
    'single' => l.statusSingle,
    'married' => l.statusMarried,
    'divorced' => l.statusDivorced,
    'complicated' => l.statusComplicated,
    'flirt' => l.intentFlirt,
    'sex' => l.intentSex,
    'chat' => l.intentChat,
    'coffee' => l.intentCoffee,
    'beer' => l.intentBeer,
    'wine' => l.intentWine,
    'tea' => l.intentTea,
    'walk' => l.intentWalk,
    'play' => l.intentPlay,
    'boys' => l.kidsBoys,
    'girls' => l.kidsGirls,
    'twins' => l.kidsTwins,
    'triplets' => l.kidsTriplets,
    _ => id,
  };
}

/// Crisis line by (hand-picked) region. Extend together with Regions on the server.
String crisisLine(String region) => switch (region) {
  'CZ-PHA' => '116 123',
  _ => '116 123',
};

/// A tappable icon tile used for every "wordless" choice.
class GlyphTile extends StatelessWidget {
  const GlyphTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Space.accent.withValues(alpha: 0.22)
                  : Space.nebula,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? Space.accent : const Color(0x22FFFFFF),
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 36)),
          ),
        ),
      ),
    );
  }
}
