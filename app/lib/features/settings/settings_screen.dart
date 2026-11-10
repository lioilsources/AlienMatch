import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../places/places_screen.dart';
import 'faces_screen.dart';
import 'flyby_tile.dart';

/// "What we know about your location" (Prompts/01-GPS.md §0.7) and account
/// deletion (store requirement, free, one tap + confirm).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<LocationData>? data;
  bool deleting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    data ??= AppScope.of(context).api.locationData();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final app = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('confirmDelete'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => deleting = true);
    try {
      await app.deleteAccount();
    } catch (_) {
      if (mounted) {
        setState(() => deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.errorGeneric)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l.locationDataTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(l.locationDataBody, style: const TextStyle(color: Space.dim)),
        FutureBuilder<LocationData>(
          future: data,
          builder: (context, snap) {
            final d = snap.data;
            if (d == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (d.places.isEmpty) ListTile(title: Text(l.noPlaces)),
                for (final p in d.places)
                  ListTile(
                    leading: Text(
                      placeEmoji(p.kind),
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(p.name),
                  ),
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(l.activeKeys(d.activeKeys)),
                ),
                ListTile(
                  leading: const Icon(Icons.storefront),
                  title: Text(l.venueCheckins(d.venueCheckins.length)),
                ),
              ],
            );
          },
        ),
        ListTile(
          key: const Key('openFaces'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.face_retouching_natural),
          title: Text(l.albumTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const FacesScreen())),
        ),
        const Divider(height: 32),
        const FlybyTile(),
        const Divider(height: 32),
        OutlinedButton.icon(
          key: const Key('deleteAccount'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          onPressed: deleting ? null : _delete,
          icon: const Icon(Icons.delete_forever),
          label: Text(l.deleteAccount),
        ),
      ],
    );
  }
}
