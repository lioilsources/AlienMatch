import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Aliens whose face I liked. A wave still goes through the radar: only
/// people the mood matrix lets through right now can be waved at.
class LikedScreen extends StatefulWidget {
  const LikedScreen({super.key});

  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> {
  late Future<List<LikedAlien>> liked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    liked = AppScope.of(context).api.liked();
  }

  Future<void> _wave(LikedAlien a) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String text;
    try {
      final r = await AppScope.of(context).api.wave(a.userId);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final api = AppScope.of(context).api;
    return Scaffold(
      appBar: AppBar(title: Text(l.likedTitle)),
      body: FutureBuilder<List<LikedAlien>>(
        future: liked,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? const <LikedAlien>[];
          if (snap.hasError || list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  snap.hasError ? l.errorGeneric : l.likedEmpty,
                  key: const Key('likedEmpty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.78,
            children: [
              for (final a in list)
                Column(
                  key: Key('liked-${a.userId}'),
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipOval(
                          child: Image.network(
                            api.photoUrl(a.userId),
                            headers: api.imageHeaders,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Space.nebula,
                              child: Center(
                                child: Text(
                                  '👽',
                                  style: TextStyle(fontSize: 48),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (a.onRadar)
                      FilledButton.tonalIcon(
                        key: Key('waveLiked-${a.userId}'),
                        onPressed: () => _wave(a),
                        icon: const Text('👋'),
                        label: Text(l.wave),
                      )
                    else
                      Text(
                        l.notOnRadarNow,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Space.dim, fontSize: 12),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
