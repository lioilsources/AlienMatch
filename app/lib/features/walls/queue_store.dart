import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../api/api.dart';

/// Persists a wall's unsent stickers so they survive an app restart.
/// Only the sticker payload (ink geometry or preset id) is kept, per wall.
abstract class StickerQueueStore {
  Future<List<Sticker>> load(int wallId);
  Future<void> save(int wallId, List<Sticker> queue);
}

Map<String, dynamic> _encode(Sticker s) => {...s.toInput(), 'author_id': s.authorId, 'z': s.z};

Sticker _decode(Map<String, dynamic> j) => Sticker(
      clientId: j['client_id'] as String,
      authorId: j['author_id'] as String,
      kind: j['kind'] as String,
      preset: j['preset'] as String?,
      ink: j['ink'] == null ? null : InkDrawing.fromJson(j['ink'] as Map<String, dynamic>),
      x: (j['x'] as num).toDouble(),
      y: (j['y'] as num).toDouble(),
      rotation: (j['rotation'] as num? ?? 0).toDouble(),
      scale: (j['scale'] as num? ?? 1).toDouble(),
      z: j['z'] as int? ?? 0,
      pending: true,
    );

class MemoryQueueStore implements StickerQueueStore {
  final Map<int, String> data = {};
  @override
  Future<List<Sticker>> load(int wallId) async =>
      [for (final j in jsonDecode(data[wallId] ?? '[]') as List) _decode(j as Map<String, dynamic>)];
  @override
  Future<void> save(int wallId, List<Sticker> queue) async => data[wallId] = jsonEncode([for (final s in queue) _encode(s)]);
}

class FileQueueStore implements StickerQueueStore {
  Future<File> _file(int wallId) async => File('${(await getApplicationSupportDirectory()).path}/wall_queue_$wallId.json');

  @override
  Future<List<Sticker>> load(int wallId) async {
    try {
      final f = await _file(wallId);
      if (!await f.exists()) return [];
      return [for (final j in jsonDecode(await f.readAsString()) as List) _decode(j as Map<String, dynamic>)];
    } catch (_) {
      return []; // a corrupt queue must never block the wall
    }
  }

  @override
  Future<void> save(int wallId, List<Sticker> queue) async {
    final f = await _file(wallId);
    if (queue.isEmpty) {
      if (await f.exists()) await f.delete();
      return;
    }
    await f.writeAsString(jsonEncode([for (final s in queue) _encode(s)]), flush: true);
  }
}
