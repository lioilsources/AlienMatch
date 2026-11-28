import 'package:flutter/material.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'ink.dart';
import 'queue_store.dart';
import 'wall_controller.dart';

const _canvas = 3000.0;
const _inkWidth = 220.0;

/// Shared, endless wall. Communication is only sticking stickers.
class WallScreen extends StatefulWidget {
  const WallScreen({
    super.key,
    required this.match,
    this.connect = defaultConnector,
    this.queueStore,
  });
  final MatchView match;
  final SocketConnector connect;
  final StickerQueueStore? queueStore;

  @override
  State<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends State<WallScreen> {
  WallController? c;
  final view = TransformationController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (c == null) {
      final app = AppScope.of(context);
      c = WallController(
        api: app.api,
        wallId: widget.match.wallId,
        me: app.me!.userId,
        connect: widget.connect,
        queueStore: widget.queueStore ?? FileQueueStore(),
      )..start();
      view.value = Matrix4.translationValues(
        -_canvas / 2 + 180,
        -_canvas / 2 + 300,
        0,
      );
    }
  }

  @override
  void dispose() {
    c?.dispose();
    view.dispose();
    super.dispose();
  }

  /// Wall coordinates of the current viewport centre.
  Offset _centre() {
    final size = MediaQuery.sizeOf(context);
    return view.toScene(Offset(size.width / 2, size.height / 2.5));
  }

  Future<void> _draw() async {
    final ink = await Navigator.push<InkDrawing?>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/ink'),
        builder: (_) => const InkPad(),
        fullscreenDialog: true,
      ),
    );
    if (ink == null) return;
    Telemetry.feature('sticker_ink');
    final p = _centre();
    await c!.add(
      Sticker(
        clientId: newClientId(),
        authorId: c!.me,
        kind: 'ink',
        ink: ink,
        x: p.dx - _inkWidth / 2,
        y: p.dy - _inkWidth / ink.aspect / 2,
      ),
    );
  }

  Future<void> _preset(String id) async {
    Telemetry.feature('sticker_preset'); // never which sticker
    final p = _centre();
    await c!.add(
      Sticker(
        clientId: newClientId(),
        authorId: c!.me,
        kind: 'preset',
        preset: id,
        x: p.dx - 32,
        y: p.dy - 32,
      ),
    );
  }

  void _menu(Sticker s) {
    final l = AppLocalizations.of(context);
    final mine = s.authorId == c!.me;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Space.nebula,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine)
              ListTile(
                leading: const Icon(Icons.layers_clear),
                title: Text(l.peel),
                onTap: () {
                  Navigator.pop(ctx);
                  c!.peel(s);
                },
              ),
            if (!mine) ...[
              ListTile(
                key: const Key('reportSticker'),
                leading: const Icon(Icons.flag_outlined),
                title: Text(l.report),
                onTap: () {
                  Navigator.pop(ctx);
                  Telemetry.feature('report');
                  c!.report(s, block: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l.reportBlock),
                onTap: () {
                  Navigator.pop(ctx);
                  Telemetry.feature('report');
                  c!.report(s, block: true);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gentle = widget.match.kind == 'encourage';
    final presets = gentle ? gentlePresets : presetEmoji.keys.toList();
    return ListenableBuilder(
      listenable: c!,
      builder: (context, _) {
        final ctl = c!;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(gentle ? '🗼' : '🛸'),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.match.otherNickname.isEmpty
                        ? (gentle ? l.encouragementWall : '👽')
                        : widget.match.otherNickname,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  ctl.online
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  color: ctl.online ? Space.accent : Space.dim,
                  semanticLabel: ctl.online ? null : l.pendingSync,
                ),
              ),
            ],
          ),
          body: ctl.ended
              ? Center(child: Text(l.wallEnded, key: const Key('wallEnded')))
              : Column(
                  children: [
                    if (widget.match.sharedPlaces.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '⭐ ${l.youShare}:',
                              style: const TextStyle(color: Space.dim),
                            ),
                            for (final p in widget.match.sharedPlaces)
                              Chip(
                                label: Text(p),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: view,
                          constrained: false,
                          minScale: 0.3,
                          maxScale: 3,
                          boundaryMargin: const EdgeInsets.all(400),
                          child: SizedBox(
                            width: _canvas,
                            height: _canvas,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: gentle
                                          ? const Color(0xFF15122B)
                                          : Space.void_,
                                    ),
                                  ),
                                ),
                                for (final s in ctl.stickers)
                                  _StickerView(
                                    key: ValueKey(s.clientId),
                                    s: s,
                                    mine: s.authorId == ctl.me,
                                    onMenu: () => _menu(s),
                                    onMoved: (o) => ctl.moveTo(s, o.dx, o.dy),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: SizedBox(
                        height: 64,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            for (final p in presets)
                              IconButton(
                                key: Key('preset-$p'),
                                onPressed: () => _preset(p),
                                icon: Text(
                                  presetEmoji[p]!,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          floatingActionButton: ctl.ended
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 64),
                  child: FloatingActionButton(
                    key: const Key('drawSticker'),
                    tooltip: l.draw,
                    onPressed: _draw,
                    child: const Icon(Icons.gesture),
                  ),
                ),
        );
      },
    );
  }
}

class _StickerView extends StatefulWidget {
  const _StickerView({
    super.key,
    required this.s,
    required this.mine,
    required this.onMenu,
    required this.onMoved,
  });
  final Sticker s;
  final bool mine;
  final VoidCallback onMenu;
  final ValueChanged<Offset> onMoved;

  @override
  State<_StickerView> createState() => _StickerViewState();
}

class _StickerViewState extends State<_StickerView> {
  Offset? drag;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final pos = drag ?? Offset(s.x, s.y);
    final Widget body = s.kind == 'ink' && s.ink != null
        ? CustomPaint(
            size: Size(_inkWidth, _inkWidth / s.ink!.aspect),
            painter: InkPainter(s.ink!),
          )
        : Text(
            presetEmoji[s.preset] ?? '✨',
            style: const TextStyle(fontSize: 56),
          );
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onLongPress: widget.onMenu,
        onPanUpdate: widget.mine && s.id != 0
            ? (d) => setState(() => drag = (drag ?? Offset(s.x, s.y)) + d.delta)
            : null,
        onPanEnd: widget.mine && s.id != 0
            ? (_) {
                widget.onMoved(drag!);
                setState(() => drag = null);
              }
            : null,
        child: Opacity(
          opacity: s.pending ? 0.5 : 1,
          child: Transform.rotate(
            angle: s.rotation,
            child: Transform.scale(scale: s.scale, child: body),
          ),
        ),
      ),
    );
  }
}
