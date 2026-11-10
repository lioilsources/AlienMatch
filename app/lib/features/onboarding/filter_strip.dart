import 'package:flutter/material.dart';
import 'package:mirror_face/mirror_face.dart';

import '../../design/space.dart';
import '../../l10n/app_localizations.dart';

/// MirrorBooth filter picker: collection tabs over a row of filter chips.
/// Every collection is free in AlienMatch; filters whose shader failed to
/// compile on this device ([available]) are hidden.
class FilterStrip extends StatefulWidget {
  const FilterStrip({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.available,
  });

  final MirrorFilter selected;
  final ValueChanged<MirrorFilter> onSelect;
  final Set<MirrorFilter> available;

  @override
  State<FilterStrip> createState() => _FilterStripState();
}

class _FilterStripState extends State<FilterStrip> {
  late FilterCollection tab =
      widget.selected.collection ?? FilterCollection.pretty;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final filters = MirrorFilter.inCollection(
      tab,
    ).where(widget.available.contains).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _Pill(
                key: const Key('filter-none'),
                text: '${MirrorFilter.none.icon} ${l.filterNone}',
                active: widget.selected == MirrorFilter.none,
                onTap: () => widget.onSelect(MirrorFilter.none),
              ),
              for (final c in FilterCollection.values)
                _Pill(
                  key: Key('collection-${c.name}'),
                  text: collectionLabel(l, c).toUpperCase(),
                  active: c == tab,
                  outline: true,
                  onTap: () => setState(() => tab = c),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in filters)
                _Pill(
                  key: Key('filter-${f.name}'),
                  text: '${f.icon} ${filterLabel(l, f)}',
                  semantics: l.filterLabel(filterLabel(l, f)),
                  active: f == widget.selected,
                  onTap: () => widget.onSelect(f),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.text,
    required this.active,
    required this.onTap,
    this.outline = false,
    this.semantics,
  });

  final String text;
  final bool active;
  final bool outline;
  final VoidCallback onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final filled = active && !outline;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: active,
        label: semantics,
        excludeSemantics: semantics != null,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled
                  ? Space.accent
                  : Space.nebula.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: active ? Space.accent : Space.dim.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: filled ? Space.void_ : Space.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: outline ? 0.8 : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String collectionLabel(AppLocalizations l, FilterCollection c) => switch (c) {
  FilterCollection.pretty => l.collectionPretty,
  FilterCollection.ugly => l.collectionUgly,
  FilterCollection.art => l.collectionArt,
  FilterCollection.fantasy => l.collectionFantasy,
};

String filterLabel(AppLocalizations l, MirrorFilter f) => switch (f) {
  MirrorFilter.none => l.filterNone,
  MirrorFilter.glow => l.filterGlow,
  MirrorFilter.slim => l.filterSlim,
  MirrorFilter.doll => l.filterDoll,
  MirrorFilter.chibi => l.filterChibi,
  MirrorFilter.lips => l.filterLips,
  MirrorFilter.bigNose => l.filterBigNose,
  MirrorFilter.alien => l.filterAlien,
  MirrorFilter.melt => l.filterMelt,
  MirrorFilter.bigEars => l.filterBigEars,
  MirrorFilter.longNeck => l.filterLongNeck,
  MirrorFilter.pencil => l.filterPencil,
  MirrorFilter.comic => l.filterComic,
  MirrorFilter.glitch => l.filterGlitch,
  MirrorFilter.neon => l.filterNeon,
  MirrorFilter.thermal => l.filterThermal,
  MirrorFilter.oil => l.filterOil,
  MirrorFilter.crt => l.filterCrt,
  MirrorFilter.popArt => l.filterPopArt,
  MirrorFilter.vampire => l.filterVampire,
  MirrorFilter.zombie => l.filterZombie,
  MirrorFilter.ghost => l.filterGhost,
  MirrorFilter.demon => l.filterDemon,
  MirrorFilter.cyborg => l.filterCyborg,
  MirrorFilter.frozen => l.filterFrozen,
};
