import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/api.dart';
import 'queue_store.dart';

/// Opens a socket; injectable for tests.
typedef SocketConnector = WebSocketChannel Function(Uri uri);

WebSocketChannel defaultConnector(Uri uri) => WebSocketChannel.connect(uri);

/// Random v4 UUID for idempotent offline resends.
String newClientId([Random? r]) {
  final rnd = r ?? Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// One wall: server stickers + an offline queue, kept in sync over a
/// WebSocket with REST catch-up (`after=lastId`) on every reconnect.
class WallController extends ChangeNotifier {
  WallController({
    required this.api,
    required this.wallId,
    required this.me,
    this.connect = defaultConnector,
    StickerQueueStore? queueStore,
  }) : queueStore = queueStore ?? MemoryQueueStore();

  final Api api;
  final int wallId;
  final String me;
  final SocketConnector connect;

  /// Where unsent stickers wait across restarts.
  final StickerQueueStore queueStore;

  final Map<int, Sticker> _byId = {};
  final List<Sticker> queue = [];
  bool ended = false;
  bool online = false;
  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  int _backoff = 1;
  bool _disposed = false;

  /// Bottom to top.
  List<Sticker> get stickers =>
      [..._byId.values, ...queue]..sort((a, b) => a.z.compareTo(b.z));

  int get _lastId => _byId.keys.fold(0, max);

  Future<void> start() async {
    for (final s in await queueStore.load(wallId)) {
      if (!queue.any((q) => q.clientId == s.clientId)) queue.add(s);
    }
    _notify();
    await _catchUp();
    await _openSocket();
  }

  Future<void> _catchUp() async {
    try {
      for (final s in await api.stickers(wallId, after: _lastId)) {
        _byId[s.id] = s;
      }
      online = true;
      _notify();
      await flush();
    } on ApiException catch (e) {
      if (e.status == 404) _end();
    } catch (_) {
      online = false;
      _notify();
    }
  }

  Future<void> _openSocket() async {
    if (_disposed || ended) return;
    try {
      final uri = await api.wallSocket(wallId);
      final ch = connect(uri);
      _ch = ch;
      _sub = ch.stream.listen(
        _onEvent,
        onDone: _onDrop,
        onError: (_) => _onDrop(),
        cancelOnError: true,
      );
      _backoff = 1;
    } on ApiException catch (e) {
      if (e.status == 404) {
        _end();
      } else {
        _onDrop();
      }
    } catch (_) {
      _onDrop();
    }
  }

  void _onEvent(dynamic msg) {
    final ev = jsonDecode(msg as String) as Map<String, dynamic>;
    switch (ev['type']) {
      case 'sticker' || 'move':
        final s = Sticker.fromJson(ev['sticker'] as Map<String, dynamic>);
        final old = _byId[s.id];
        if (ev['type'] == 'move' && old != null) {
          old
            ..x = s.x
            ..y = s.y
            ..rotation = s.rotation
            ..scale = s.scale
            ..z = s.z;
        } else {
          _byId[s.id] = s;
          if (queue.any((q) => q.clientId == s.clientId)) {
            queue.removeWhere((q) => q.clientId == s.clientId);
            _persist();
          }
        }
      case 'peel' || 'hide':
        _byId.remove(ev['id'] as int);
      case 'ended':
        _end();
    }
    _notify();
  }

  void _onDrop() {
    online = false;
    _notify();
    _sub?.cancel();
    _sub = null;
    if (_disposed || ended) return;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _backoff), () async {
      _backoff = min(_backoff * 2, 30);
      await _catchUp();
      await _openSocket();
    });
  }

  /// Adds a sticker locally at once and sends it when possible.
  Future<void> add(Sticker s) async {
    s
      ..pending = true
      ..z = (stickers.isEmpty ? 0 : stickers.last.z) + 1;
    queue.add(s);
    _notify();
    await _persist();
    await flush();
  }

  Future<void> _persist() => queueStore.save(wallId, queue);

  /// Sends queued stickers; the server de-duplicates by client_id.
  Future<void> flush() async {
    for (final s in List.of(queue)) {
      try {
        final saved = await api.stick(wallId, s);
        queue.removeWhere((q) => q.clientId == s.clientId);
        _byId[saved.id] = saved;
        online = true;
      } on ApiException catch (e) {
        if (e.status == 400) {
          queue.removeWhere(
            (q) => q.clientId == s.clientId,
          ); // rejected for good
        }
        if (e.status == 404) _end();
        break;
      } catch (_) {
        online = false;
        break;
      }
    }
    await _persist();
    _notify();
  }

  Future<void> moveTo(Sticker s, double x, double y) async {
    if (s.authorId != me || s.id == 0) return;
    s
      ..x = x
      ..y = y
      ..z = (stickers.isEmpty ? 0 : stickers.last.z) + 1;
    _notify();
    try {
      await api.move(wallId, s);
    } catch (_) {}
  }

  Future<void> peel(Sticker s) async {
    if (s.authorId != me) return;
    _byId.remove(s.id);
    _notify();
    try {
      await api.peel(wallId, s.id);
    } catch (_) {}
  }

  Future<void> report(Sticker s, {required bool block}) async {
    _byId.remove(s.id);
    _notify();
    await api.report(stickerId: s.id, block: block);
    if (block) _end();
  }

  void _end() {
    ended = true;
    queue.clear();
    _persist(); // nothing left to send to an ended wall
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    _ch?.sink.close();
    super.dispose();
  }
}
