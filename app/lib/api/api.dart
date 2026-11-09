import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Base URL of alienmatch-api, set at build time:
/// `--dart-define=API_BASE_URL=https://api.example`.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

class ApiException implements Exception {
  ApiException(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'ApiException($status): $body';
}

/// The server never receives coordinates, e-mail or free text other than the
/// nickname and catalog search. Keep it that way in every new method.
class Api {
  Api({http.Client? client, this.baseUrl = apiBaseUrl}) : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Headers for authenticated image requests (profile photos).
  Map<String, String> get imageHeaders => {if (token != null) 'Authorization': 'Bearer $token'};

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final req = http.Request(method, _u(path, query))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode >= 300) throw ApiException(res.statusCode, res.body);
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<({String userId, String token})> createAccount({required bool adult, required bool moodConsent}) async {
    final j = await _send('POST', '/v1/accounts', body: {'adult_confirmed': adult, 'mood_consent': moodConsent});
    return (userId: j['user_id'] as String, token: j['token'] as String);
  }

  Future<Me> me() async => Me.fromJson(await _send('GET', '/v1/me'));

  Future<void> saveProfile(Profile p) => _send('PUT', '/v1/me/profile', body: p.toJson());

  Future<void> uploadPhoto(Uint8List jpeg) async {
    final res = await _http.put(_u('/v1/me/photo'), headers: {..._headers, 'Content-Type': 'image/jpeg'}, body: jpeg);
    if (res.statusCode >= 300) throw ApiException(res.statusCode, res.body);
  }

  String photoUrl(String userId) => '$baseUrl/v1/users/$userId/photo';

  Future<void> deleteAccount() => _send('DELETE', '/v1/me');

  Future<CheckinResult> checkin({required String mode, required double self}) async =>
      CheckinResult.fromJson(await _send('POST', '/v1/checkins', body: {'mode': mode, 'self': self}));

  Future<Radar> radar() async => Radar.fromJson(await _send('GET', '/v1/radar'));

  Future<List<CatalogPlace>> searchPlaces(String q) async {
    final j = await _send('GET', '/v1/places', query: {'q': q});
    return [for (final p in j['places'] as List) CatalogPlace.fromJson(p)];
  }

  Future<void> setPlaces(List<String> ids) => _send('PUT', '/v1/me/places', body: {'place_ids': ids});

  Future<LocationData> locationData() async => LocationData.fromJson(await _send('GET', '/v1/me/location-data'));
}

List<String> _strs(dynamic v) => [for (final x in (v as List? ?? const [])) x as String];

class Profile {
  Profile({
    this.nickname = '',
    required this.generation,
    required this.status,
    this.kidsCount,
    this.kidsFlags = const [],
    this.region = 'CZ-PHA',
    this.seekGenerations = const [],
    this.seekStatuses = const [],
    required this.intents,
    this.canBeBeacon = false,
    this.wantsEncouragement = false,
    this.beaconOnly = false,
  });

  String nickname;
  String generation;
  String status;
  int? kidsCount;
  List<String> kidsFlags;
  String region;
  List<String> seekGenerations;
  List<String> seekStatuses;
  List<String> intents;
  bool canBeBeacon;
  bool wantsEncouragement;
  bool beaconOnly;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        nickname: j['nickname'] as String? ?? '',
        generation: j['generation'] as String,
        status: j['status'] as String,
        kidsCount: j['kids_count'] as int?,
        kidsFlags: _strs(j['kids_flags']),
        region: j['region'] as String,
        seekGenerations: _strs(j['seek_generations']),
        seekStatuses: _strs(j['seek_statuses']),
        intents: _strs(j['intents']),
        canBeBeacon: j['can_be_beacon'] as bool? ?? false,
        wantsEncouragement: j['wants_encouragement'] as bool? ?? false,
        beaconOnly: j['beacon_only'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        if (nickname.isNotEmpty) 'nickname': nickname,
        'generation': generation,
        'status': status,
        if (kidsCount != null) 'kids_count': kidsCount,
        'kids_flags': kidsFlags,
        'region': region,
        'seek_generations': seekGenerations,
        'seek_statuses': seekStatuses,
        'intents': intents,
        'can_be_beacon': canBeBeacon,
        'wants_encouragement': wantsEncouragement,
        'beacon_only': beaconOnly,
      };
}

class Me {
  Me({required this.userId, required this.moodConsent, required this.hasPhoto, this.profile});
  final String userId;
  final bool moodConsent;
  final bool hasPhoto;
  final Profile? profile;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        userId: j['user_id'] as String,
        moodConsent: j['mood_consent'] as bool? ?? false,
        hasPhoto: j['has_photo'] as bool? ?? false,
        profile: j['profile'] == null ? null : Profile.fromJson(j['profile'] as Map<String, dynamic>),
      );
}

class CheckinResult {
  CheckinResult(this.level, this.trend, this.supportCard, this.askAgainSoon);
  final String level;
  final String trend;
  final bool supportCard;
  final bool askAgainSoon;

  factory CheckinResult.fromJson(Map<String, dynamic> j) => CheckinResult(
      j['level'] as String, j['trend'] as String, j['support_card'] as bool? ?? false, j['ask_again_soon'] as bool? ?? false);
}

class Planet {
  Planet({required this.userId, required this.kind, required this.level, required this.trend, required this.intents, this.star, this.weakSignal = false});
  final String userId;
  final String kind; // match | encourage
  final String level;
  final String trend;
  final List<String> intents;
  final String? star;
  final bool weakSignal;

  factory Planet.fromJson(Map<String, dynamic> j) => Planet(
        userId: j['user_id'] as String,
        kind: j['kind'] as String,
        level: j['level'] as String,
        trend: j['trend'] as String,
        intents: _strs(j['intents']),
        star: j['star'] as String?,
        weakSignal: j['weak_signal'] as bool? ?? false,
      );
}

class Radar {
  Radar(this.offRadar, this.planets);
  final bool offRadar;
  final List<Planet> planets;
  factory Radar.fromJson(Map<String, dynamic> j) =>
      Radar(j['off_radar'] as bool? ?? false, [for (final p in j['planets'] as List) Planet.fromJson(p as Map<String, dynamic>)]);
}

class CatalogPlace {
  CatalogPlace({required this.id, required this.kind, required this.name, this.subtype = ''});
  final String id;
  final String kind;
  final String name;
  final String subtype;
  factory CatalogPlace.fromJson(Map<String, dynamic> j) =>
      CatalogPlace(id: j['place_id'] as String, kind: j['kind'] as String, name: j['name'] as String, subtype: j['subtype'] as String? ?? '');
}

class LocationData {
  LocationData(this.places, this.activeKeys, this.venueCheckins);
  final List<CatalogPlace> places;
  final int activeKeys;
  final List<String> venueCheckins;
  factory LocationData.fromJson(Map<String, dynamic> j) => LocationData(
        [for (final p in j['places'] as List) CatalogPlace.fromJson(p as Map<String, dynamic>)],
        j['active_encounter_keys'] as int? ?? 0,
        _strs(j['venue_checkins']),
      );
}
