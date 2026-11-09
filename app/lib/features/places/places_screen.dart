import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

const maxPlaces = 8;

String placeEmoji(String kind) => switch (kind) {
  'stop' => '🚏',
  'route' => '🚋',
  'poi' => '☕',
  'edu' => '🎓',
  'office' => '🏢',
  'partner' => '🛬',
  'event' => '🎪',
  _ => '⭐',
};

/// "My stars": pick up to 8 places from the public catalog. Search is a
/// catalog lookup, not communication; no GPS is read or sent.
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final q = TextEditingController();
  Timer? debounce;
  List<CatalogPlace> results = [];
  List<CatalogPlace> mine = [];
  bool loaded = false, saving = false, failed = false, saved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      AppScope.of(context).api.locationData().then((d) {
        if (mounted) setState(() => mine = d.places);
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    q.dispose();
    super.dispose();
  }

  void _search(String text) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () async {
      if (text.trim().length < 2) {
        setState(() => results = []);
        return;
      }
      try {
        final r = await AppScope.of(context).api.searchPlaces(text.trim());
        if (mounted) setState(() => results = r);
      } catch (_) {
        if (mounted) setState(() => results = []);
      }
    });
  }

  void _toggle(CatalogPlace p) {
    setState(() {
      saved = false;
      if (mine.any((m) => m.id == p.id)) {
        mine.removeWhere((m) => m.id == p.id);
      } else if (mine.length < maxPlaces) {
        mine.add(p);
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await AppScope.of(context).api.setPlaces([for (final m in mine) m.id]);
      if (mounted) setState(() => saved = true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.placesTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          l.placesLimit(maxPlaces),
          style: const TextStyle(color: Space.dim),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in mine)
              InputChip(
                label: Text('${placeEmoji(m.kind)} ${m.name}'),
                onDeleted: () => _toggle(m),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('placeSearch'),
          controller: q,
          onChanged: _search,
          maxLength: 64,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l.placesSearchHint,
            counterText: '',
          ),
        ),
        for (final r in results)
          CheckboxListTile(
            value: mine.any((m) => m.id == r.id),
            onChanged: (_) => _toggle(r),
            secondary: Text(
              placeEmoji(r.kind),
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(r.name),
            subtitle: r.subtype.isEmpty
                ? null
                : Text(r.subtype, style: const TextStyle(color: Space.dim)),
          ),
        const SizedBox(height: 16),
        if (failed)
          Text(l.errorGeneric, style: const TextStyle(color: Colors.redAccent)),
        if (saved)
          Text(l.placesSaved, style: const TextStyle(color: Space.accent)),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l.save),
          ),
        ),
      ],
    );
  }
}
