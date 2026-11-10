import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api.dart';
import '../flyby/controller.dart';
import 'face_album.dart';

/// Where the token lives. Abstracted so tests do not need platform channels.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  static const _key = 'alienmatch_token';
  final _s = const FlutterSecureStorage();
  @override
  Future<String?> read() => _s.read(key: _key);
  @override
  Future<void> write(String token) => _s.write(key: _key, value: token);
  @override
  Future<void> clear() => _s.delete(key: _key);
}

enum Stage { loading, welcome, onboarding, home }

/// App-wide session: the anonymous account token and the caller's profile.
class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    required this.tokens,
    this.flybyFactory,
    FaceAlbum? album,
  }) : album = album ?? FaceAlbum(MemoryFaceStorage());

  final Api api;
  final TokenStore tokens;

  /// The user's mirror faces, on the phone only.
  final FaceAlbum album;

  /// Builds the fly-by controller (native BLE in the app, fakes in tests).
  final FlybyController Function(Api api)? flybyFactory;
  FlybyController? _flyby;

  /// Layer B, created on first use and loaded once.
  FlybyController? get flyby {
    if (_flyby == null && flybyFactory != null) {
      _flyby = flybyFactory!(api)..load();
    }
    return _flyby;
  }

  Stage stage = Stage.loading;
  Me? me;
  Object? error;

  Future<void> load() async {
    album.load().ignore(); // local files, never blocks startup
    String? t;
    try {
      t = await tokens.read();
    } catch (e) {
      // Unreadable keychain: start over rather than spin forever.
      error = e;
      t = null;
    }
    if (t == null) {
      _set(Stage.welcome);
      return;
    }
    api.token = t;
    await refresh();
  }

  Future<void> refresh() async {
    try {
      me = await api.me();
      error = null;
      _set(me!.profile != null && me!.hasPhoto ? Stage.home : Stage.onboarding);
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 404) {
        await tokens.clear();
        api.token = null;
        me = null;
        _set(Stage.welcome);
      } else {
        error = e;
        notifyListeners();
      }
    } catch (e) {
      // Network down or timed out: the UI shows a retry button.
      error = e;
      notifyListeners();
    }
  }

  Future<void> createAccount({required bool moodConsent}) async {
    final r = await api.createAccount(adult: true, moodConsent: moodConsent);
    await tokens.write(r.token);
    api.token = r.token;
    await refresh();
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    await _flyby?.store.wipe();
    await album.wipe();
    _flyby?.dispose();
    _flyby = null;
    await tokens.clear();
    api.token = null;
    me = null;
    _set(Stage.welcome);
  }

  /// Uploads [face] as the profile photo, then remembers it as active.
  Future<void> useFace(Face face) async {
    await api.uploadPhoto(face.jpeg);
    await album.markActive(face.id);
    await refresh();
  }

  void _set(Stage s) {
    stage = s;
    notifyListeners();
  }
}

/// Exposes [AppState] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
