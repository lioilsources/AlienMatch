import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'wall_screen.dart';

/// All open walls. Shared places are named here, revealed by the match.
class WallsScreen extends StatefulWidget {
  const WallsScreen({super.key});

  @override
  State<WallsScreen> createState() => WallsScreenState();
}

class WallsScreenState extends State<WallsScreen> {
  Future<List<MatchView>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= AppScope.of(context).api.matches();
  }

  void reload() => setState(() => future = AppScope.of(context).api.matches());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final api = AppScope.of(context).api;
    return RefreshIndicator(
      onRefresh: () async => reload(),
      child: FutureBuilder<List<MatchView>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final ms = snap.data ?? const <MatchView>[];
          if (snap.hasError || ms.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(32),
              children: [
                const SizedBox(height: 120),
                const Text(
                  '🪐',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 16),
                Text(
                  snap.hasError ? l.errorGeneric : l.wallsEmpty,
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }
          return ListView(
            children: [
              for (final m in ms)
                ListTile(
                  key: Key('wall-${m.wallId}'),
                  leading: ClipOval(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.network(
                        api.photoUrl(m.otherId),
                        headers: api.imageHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Text('👽', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                  title: Text(m.otherNickname.isEmpty ? '👽' : m.otherNickname),
                  subtitle: m.sharedPlaces.isEmpty
                      ? null
                      : Text(
                          '⭐ ${m.sharedPlaces.join(' · ')}',
                          style: const TextStyle(color: Space.dim),
                        ),
                  trailing: Text(
                    m.kind == 'encourage' ? '🗼' : '🛸',
                    style: const TextStyle(fontSize: 22),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/wall'),
                      builder: (_) => WallScreen(match: m),
                    ),
                  ).then((_) => reload()),
                ),
            ],
          );
        },
      ),
    );
  }
}
