import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/face_album.dart';
import '../onboarding/capture_screen.dart';

/// "My faces": every mirror face taken in the app, kept on the phone. Tap one
/// to make it the profile photo; only that one is uploaded.
class FacesScreen extends StatefulWidget {
  const FacesScreen({super.key});

  @override
  State<FacesScreen> createState() => _FacesScreenState();
}

class _FacesScreenState extends State<FacesScreen> {
  String? switching;

  /// Community feedback per uploaded face; null while loading or offline.
  FaceStats? stats;

  Future<void> _loadStats() async {
    try {
      final s = await AppScope.of(context).api.faceStats();
      if (mounted) setState(() => stats = s);
    } catch (_) {}
  }

  Future<void> _use(Face f) async {
    final app = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => switching = f.id);
    try {
      await app.useFace(f);
      if (_fromHome) _loadStats();
      // During onboarding this finishes the profile: leave the album.
      if (!_fromHome && nav.canPop()) nav.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    } finally {
      if (mounted) setState(() => switching = null);
    }
  }

  bool _fromHome = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fromHome = AppScope.of(context).stage == Stage.home;
    if (stats == null && _fromHome) _loadStats();
  }

  Future<void> _remove(Face f) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteFace),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('confirmDeleteFace'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.deleteFace),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await AppScope.of(context).album.remove(f.id);
  }

  List<Widget> _feedback(AppLocalizations l, FaceAlbum album, FaceStats st) {
    final mine = {for (final f in album.faces) album.photoIdOf(f.id)};
    final older = st.faces.where((f) => !mine.contains(f.photoId)).toList();
    return [
      const Divider(height: 32),
      Text(l.feedbackTitle, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(l.feedbackNote, style: const TextStyle(color: Space.dim)),
      if (st.dislikesHidden)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l.dislikesHidden,
            key: const Key('dislikesHidden'),
            style: const TextStyle(color: Space.beacon),
          ),
        ),
      if (st.faces.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.feedbackEmpty),
        ),
      for (final f in older)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Text('👽', style: TextStyle(fontSize: 28)),
          title: Text(f.current ? l.faceActive : l.olderFace),
          subtitle: Text(statLine(f)),
        ),
    ];
  }

  void _new() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const CaptureScreen(fromAlbum: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final album = AppScope.of(context).album;
    return Scaffold(
      appBar: AppBar(title: Text(l.albumTitle)),
      body: ListenableBuilder(
        listenable: album,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l.albumNote, style: const TextStyle(color: Space.dim)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: [
                if (_fromHome && !album.full)
                  Semantics(
                    button: true,
                    label: l.newFace,
                    child: InkWell(
                      key: const Key('newFace'),
                      customBorder: const CircleBorder(),
                      onTap: _new,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Space.dim, width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(Icons.add_a_photo, color: Space.ink),
                        ),
                      ),
                    ),
                  ),
                for (final f in album.faces)
                  _FaceTile(
                    face: f,
                    active: f.id == album.activeId,
                    busy: switching == f.id,
                    onTap: switching != null || f.id == album.activeId
                        ? null
                        : () => _use(f),
                    onDelete: f.id == album.activeId ? null : () => _remove(f),
                    stat: stats?.byPhoto(album.photoIdOf(f.id)),
                  ),
              ],
            ),
            if (stats != null) ..._feedback(l, album, stats!),
          ],
        ),
      ),
    );
  }
}

class _FaceTile extends StatelessWidget {
  const _FaceTile({
    required this.face,
    required this.active,
    required this.busy,
    required this.onTap,
    required this.onDelete,
    this.stat,
  });

  final Face face;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final FaceStat? stat;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: onTap != null,
      selected: active,
      label: active ? l.faceActive : l.setAsProfile,
      child: Column(
        children: [
          Expanded(child: _stack(l)),
          const SizedBox(height: 4),
          Text(
            stat == null ? '' : statLine(stat!),
            key: Key('faceStat-${face.id}'),
            style: const TextStyle(color: Space.dim, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _stack(AppLocalizations l) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: InkWell(
              key: Key('face-${face.id}'),
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? Space.accent : Colors.transparent,
                    width: 3,
                  ),
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Image.memory(face.jpeg, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (active)
            const Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Space.accent,
                child: Icon(Icons.check, size: 16, color: Space.void_),
              ),
            ),
          if (onDelete != null)
            Positioned(
              right: -6,
              top: -6,
              child: IconButton(
                key: Key('deleteFace-${face.id}'),
                tooltip: l.deleteFace,
                iconSize: 18,
                onPressed: onDelete,
                icon: const Icon(Icons.close, color: Space.dim),
              ),
            ),
        ],
      ),
    );
  }
}

/// "👀 12 · 👍 7 · 👎 2"; the dislike part is left out while hidden.
String statLine(FaceStat s) => [
  '👀 ${s.seen}',
  '👍 ${s.likes}',
  if (s.dislikes != null) '👎 ${s.dislikes}',
].join(' · ');
