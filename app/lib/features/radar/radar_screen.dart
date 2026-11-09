import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'flyby_strip.dart';

/// Star map, not a swipe deck. Planets are people the mood matrix lets
/// through; shared places are drawn as a line to one of MY stars.
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  Future<Radar>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).api.radar();
  }

  void _reload() => setState(() => future = AppScope.of(context).api.radar());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<Radar>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Message(
              text: l.errorGeneric,
              action: TextButton(onPressed: _reload, child: Text(l.retry)),
            );
          }
          final r = snap.data!;
          if (r.offRadar) {
            return _Message(key: const Key('offRadar'), text: l.offRadar);
          }
          final flyby = AppScope.of(context).flyby;
          final map = r.planets.isEmpty
              ? _Message(text: l.radarEmpty)
              : StarMap(planets: r.planets);
          if (flyby == null) return map;
          return Column(
            children: [
              FlybyStrip(flyby: flyby),
              Expanded(child: map),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 120),
      const Text(
        '🔭',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 64),
      ),
      const SizedBox(height: 16),
      Text(text, textAlign: TextAlign.center),
      if (action != null) Center(child: action),
    ],
  );
}

/// Deterministic position in 0..1 from an id, so planets don't jump around.
Offset positionOf(String id, int salt) {
  final r = Random(id.hashCode ^ salt);
  return Offset(0.12 + r.nextDouble() * 0.76, 0.1 + r.nextDouble() * 0.8);
}

class StarMap extends StatelessWidget {
  const StarMap({super.key, required this.planets});
  final List<Planet> planets;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final stars = {
          for (final p in planets)
            if (p.star != null) p.star!,
        };
        final starPos = {for (final s in stars) s: positionOf(s, 7)};
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SkyPainter(planets: planets, starPos: starPos),
              ),
            ),
            for (final s in stars)
              Positioned(
                left: starPos[s]!.dx * size.width - 10,
                top: starPos[s]!.dy * size.height - 10,
                child: const Text('⭐', style: TextStyle(fontSize: 20)),
              ),
            for (var i = 0; i < planets.length; i++)
              Positioned(
                left: positionOf(planets[i].userId, 1).dx * size.width - 36,
                top: positionOf(planets[i].userId, 1).dy * size.height - 36,
                child: PlanetView(
                  key: Key('planet-${planets[i].userId}'),
                  planet: planets[i],
                  rank: i,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.planets, required this.starPos});
  final List<Planet> planets;
  final Map<String, Offset> starPos;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    final dot = Paint()..color = Colors.white24;
    for (var i = 0; i < 140; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 1.2,
        dot,
      );
    }
    final line = Paint()
      ..color = Space.accent.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    for (final p in planets) {
      final s = p.star;
      if (s == null) continue;
      final a = positionOf(p.userId, 1), b = starPos[s]!;
      canvas.drawLine(
        Offset(a.dx * size.width, a.dy * size.height),
        Offset(b.dx * size.width, b.dy * size.height),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.planets != planets;
}

/// A person as a planet: their alien face inside a pulsing aura.
class PlanetView extends StatefulWidget {
  const PlanetView({super.key, required this.planet, required this.rank});
  final Planet planet;
  final int rank;

  @override
  State<PlanetView> createState() => _PlanetViewState();
}

class _PlanetViewState extends State<PlanetView>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: Space.pulse(widget.planet.trend),
  )..repeat(reverse: true);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = AppScope.of(context).api;
    final p = widget.planet;
    final aura = p.kind == 'encourage' ? Space.beacon : Space.aura(p.level);
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: p.kind == 'encourage' ? l.planetEncourage : l.planetMatch,
      child: GestureDetector(
        onTap: () => _detail(context, p),
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, child) => Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: p.weakSignal
                  ? Border.all(
                      color: Space.accent.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: aura.withValues(alpha: 0.35 + 0.35 * pulse.value),
                  blurRadius: 18 + 14 * pulse.value,
                  spreadRadius: 2 + 4 * pulse.value,
                ),
              ],
            ),
            child: child,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipOval(
                  child: Image.network(
                    api.photoUrl(p.userId),
                    headers: api.imageHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Space.nebula,
                      child: Center(
                        child: Text('👽', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                ),
              ),
              if (p.comet != null)
                const Positioned(
                  right: -6,
                  top: -6,
                  child: Text('☄️', style: TextStyle(fontSize: 20)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _wave(BuildContext sheet, Planet p) async {
    final l = AppLocalizations.of(context);
    final api = AppScope.of(context).api;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(sheet);
    String text;
    try {
      final r = await api.wave(p.userId);
      text = r.matched ? '🪐 ${l.matched}' : '👋 ${l.waveSent}';
    } on ApiException catch (e) {
      text = e.status == 429 ? l.waveLimit : l.errorGeneric;
    } catch (_) {
      text = l.errorGeneric;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(text, key: const Key('waveResult'))),
    );
  }

  void _detail(BuildContext context, Planet p) {
    final l = AppLocalizations.of(context);
    final api = AppScope.of(context).api;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Space.nebula,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Image.network(
                    api.photoUrl(p.userId),
                    headers: api.imageHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Text('👽', style: TextStyle(fontSize: 80)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                p.kind == 'encourage'
                    ? '🗼 ${l.planetEncourage}'
                    : '🛸 ${l.planetMatch}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final i in p.intents)
                    Chip(
                      label: Text(
                        '${Glyphs.emojiOf(Glyphs.intents, i)} ${Glyphs.label(l, i)}',
                      ),
                    ),
                ],
              ),
              if (p.star != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('⭐ ${l.sharedStar}'),
                ),
              if (p.weakSignal)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '✨ ${l.weakSignal}',
                    style: const TextStyle(color: Space.dim),
                  ),
                ),
              if (p.comet != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '☄️ ${l.flybyComet}: ${contactLabel(l, p.comet!)}',
                    key: const Key('comet'),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('wave'),
                onPressed: () => _wave(context, p),
                icon: const Text('👋', style: TextStyle(fontSize: 22)),
                label: Text(l.wave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
