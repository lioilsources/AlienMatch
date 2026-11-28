import 'package:flutter/material.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'liked_screen.dart';

/// The brightest stars on my radar, one face at a time. Swipe sideways to
/// browse, up to like, down to dislike. Rating moves on to the next face;
/// browsing past an unrated face counts it as seen (0). Going back shows my
/// rating, which can still be changed. Ratings never create a match.
class StarsScreen extends StatefulWidget {
  const StarsScreen({super.key});

  @override
  State<StarsScreen> createState() => _StarsScreenState();
}

class _StarsScreenState extends State<StarsScreen> {
  late Future<List<StarCard>> deck;
  final pages = PageController();
  int index = 0;

  /// Vertical drag of the current card, in logical px.
  double drag = 0;
  static const _threshold = 90.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    deck = AppScope.of(context).api.stars();
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> _send(StarCard c, int value) async {
    final prev = c.rating;
    setState(() => c.rating = value);
    try {
      await AppScope.of(context).api.rate(c.userId, value);
    } catch (_) {
      if (!mounted) return;
      setState(() => c.rating = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorGeneric)),
      );
    }
  }

  Future<void> _rate(List<StarCard> cards, int value) async {
    // Only that stars were rated: never whom or how.
    Telemetry.feature('stars_rate');
    final c = cards[index];
    await _send(c, value);
    if (!mounted) return;
    if (index < cards.length) {
      pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _onPage(List<StarCard> cards, int next) {
    // Leaving an unrated face: it was seen, neither liked nor disliked.
    if (index < cards.length && cards[index].rating == null) {
      _send(cards[index], 0);
    }
    setState(() {
      index = next;
      drag = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.starsTitle),
        actions: [
          IconButton(
            key: const Key('openLiked'),
            tooltip: l.likedTitle,
            icon: const Icon(Icons.favorite_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/liked'),
                builder: (_) => const LikedScreen(),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<StarCard>>(
        future: deck,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: TextButton(
                onPressed: () =>
                    setState(() => deck = AppScope.of(context).api.stars()),
                child: Text('${l.errorGeneric} ${l.retry}'),
              ),
            );
          }
          final cards = snap.data!;
          if (cards.isEmpty) {
            return _Note(key: const Key('starsEmpty'), text: l.starsEmpty);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  l.starsHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Space.dim),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const Key('starPages'),
                  controller: pages,
                  itemCount: cards.length + 1,
                  onPageChanged: (i) => _onPage(cards, i),
                  itemBuilder: (context, i) => i == cards.length
                      ? _Note(key: const Key('starsDone'), text: l.starsDone)
                      : _card(cards, i),
                ),
              ),
              if (index < cards.length) _buttons(l, cards),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _card(List<StarCard> cards, int i) {
    final c = cards[i];
    final api = AppScope.of(context).api;
    final current = i == index;
    final dy = current ? drag : 0.0;
    final hint = dy < -_threshold / 2
        ? 1
        : dy > _threshold / 2
        ? -1
        : null;
    return GestureDetector(
      key: Key('star-${c.userId}'),
      onVerticalDragUpdate: (d) => setState(() => drag += d.delta.dy),
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (drag < -_threshold || v < -800) {
          _rate(cards, 1);
        } else if (drag > _threshold || v > 800) {
          _rate(cards, -1);
        }
        setState(() => drag = 0);
      },
      child: Center(
        child: Transform.translate(
          offset: Offset(0, dy),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Space.aura(c.level).withValues(alpha: 0.6),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    api.photoUrl(c.userId),
                    headers: api.imageHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Space.nebula,
                      child: Center(
                        child: Text('👽', style: TextStyle(fontSize: 96)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _Badge(rating: hint ?? c.rating, preview: hint != null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buttons(AppLocalizations l, List<StarCard> cards) {
    final r = cards[index].rating;
    Widget b(int v, String emoji, String label) => Semantics(
      button: true,
      selected: r == v,
      label: label,
      child: InkResponse(
        key: Key(v == 1 ? 'like' : 'dislike'),
        onTap: () => _rate(cards, v),
        radius: 40,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: r == v ? Space.accent.withValues(alpha: 0.25) : Space.nebula,
            border: Border.all(color: r == v ? Space.accent : Space.dim),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [b(-1, '👎', l.dislike), b(1, '👍', l.like)],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.rating, required this.preview});
  final int? rating;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (emoji, text) = switch (rating) {
      1 => ('👍', l.like),
      -1 => ('👎', l.dislike),
      0 => ('👀', l.ratedSeen),
      _ => ('', ''),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: rating == null ? 0 : (preview ? 0.7 : 1),
      child: Chip(key: const Key('myRating'), label: Text('$emoji $text')),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌌', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
