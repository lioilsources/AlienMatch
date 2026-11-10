import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// One composed mirror face (JPEG). Only ever made live in the app.
class Face {
  const Face(this.id, this.jpeg);
  final String id;
  final Uint8List jpeg;
}

/// Where faces live. Files in the app's private support directory; memory in
/// tests.
abstract class FaceStorage {
  Future<List<Face>> load();
  Future<void> put(Face f);
  Future<void> remove(String id);
  Future<String?> readActive();
  Future<void> writeActive(String? id);
}

class MemoryFaceStorage implements FaceStorage {
  final Map<String, Uint8List> files = {};
  String? active;
  @override
  Future<List<Face>> load() async => [
    for (final e in files.entries) Face(e.key, e.value),
  ];
  @override
  Future<void> put(Face f) async => files[f.id] = f.jpeg;
  @override
  Future<void> remove(String id) async => files.remove(id);
  @override
  Future<String?> readActive() async => active;
  @override
  Future<void> writeActive(String? id) async => active = id;
}

class FileFaceStorage implements FaceStorage {
  Future<Directory> _dir() async {
    final d = Directory(
      '${(await getApplicationSupportDirectory()).path}/faces',
    );
    await d.create(recursive: true);
    return d;
  }

  static final _name = RegExp(r'^[0-9]+\.jpg$');

  @override
  Future<List<Face>> load() async {
    final out = <Face>[];
    await for (final e in (await _dir()).list()) {
      final name = e.uri.pathSegments.last;
      if (e is File && _name.hasMatch(name)) {
        out.add(
          Face(name.substring(0, name.length - 4), await e.readAsBytes()),
        );
      }
    }
    return out;
  }

  @override
  Future<void> put(Face f) async {
    final d = await _dir();
    final tmp = File('${d.path}/${f.id}.tmp');
    await tmp.writeAsBytes(f.jpeg, flush: true);
    await tmp.rename('${d.path}/${f.id}.jpg');
  }

  @override
  Future<void> remove(String id) async {
    final f = File('${(await _dir()).path}/$id.jpg');
    if (await f.exists()) await f.delete();
  }

  Future<File> _active() async => File('${(await _dir()).path}/active.json');

  @override
  Future<String?> readActive() async {
    try {
      final f = await _active();
      if (!await f.exists()) return null;
      return (jsonDecode(await f.readAsString()) as Map)['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeActive(String? id) async =>
      (await _active()).writeAsString(jsonEncode({'id': id}));
}

/// The user's own mirror faces, kept on the phone only. The server knows just
/// the one uploaded as the profile photo ([activeId]); switching uploads
/// another one from here.
class FaceAlbum extends ChangeNotifier {
  FaceAlbum(this.storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FaceStorage storage;
  final DateTime Function() _clock;

  /// Enough to play with, small enough to stay a few MB on the phone.
  static const max = 12;

  /// Newest first.
  List<Face> faces = [];
  String? activeId;
  bool _loaded = false;

  bool get full => faces.length >= max;

  Future<void> load() async {
    if (_loaded) return;
    try {
      faces = await storage.load()
        ..sort((a, b) => b.id.compareTo(a.id));
      activeId = await storage.readActive();
      if (!faces.any((f) => f.id == activeId)) activeId = null;
    } catch (_) {
      faces = [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Stores a new face; throws [AlbumFullException] at [max].
  Future<Face> add(Uint8List jpeg) async {
    await load();
    if (full) throw const AlbumFullException();
    var id = _clock().microsecondsSinceEpoch;
    while (faces.any((f) => f.id == '$id')) {
      id++;
    }
    final f = Face('$id', jpeg);
    await storage.put(f);
    faces = [f, ...faces];
    notifyListeners();
    return f;
  }

  /// Marks [id] as the profile photo. Call after the upload succeeded.
  Future<void> markActive(String id) async {
    activeId = id;
    await storage.writeActive(id);
    notifyListeners();
  }

  /// The current profile photo cannot be removed, only replaced.
  Future<void> remove(String id) async {
    if (id == activeId) return;
    await storage.remove(id);
    faces = faces.where((f) => f.id != id).toList();
    notifyListeners();
  }

  /// Account deletion: nothing of the user stays on the phone either.
  Future<void> wipe() async {
    for (final f in await storage.load()) {
      await storage.remove(f.id);
    }
    await storage.writeActive(null);
    faces = [];
    activeId = null;
    notifyListeners();
  }
}

class AlbumFullException implements Exception {
  const AlbumFullException();
}
