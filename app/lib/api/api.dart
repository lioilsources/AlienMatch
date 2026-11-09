import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Base URL of alienmatch-api, set at build time:
/// `--dart-define=API_BASE_URL=https://api.example`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

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
  Api({http.Client? client, this.baseUrl = apiBaseUrl})
    : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  /// Headers for authenticated image requests (profile photos).
  Map<String, String> get imageHeaders => {
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final req = http.Request(method, _u(path, query))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode >= 300) throw ApiException(res.statusCode, res.body);
    if (res.body.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<({String userId, String token})> createAccount({
    required bool adult,
    required bool moodConsent,
  }) async {
    final j = await _send(
      'POST',
      '/v1/accounts',
      body: {'adult_confirmed': adult, 'mood_consent': moodConsent},
    );
    return (userId: j['user_id'] as String, token: j['token'] as String);
  }

  Future<Me> me() async => Me.fromJson(await _send('GET', '/v1/me'));

  Future<void> saveProfile(Profile p) =>
      _send('PUT', '/v1/me/profile', body: p.toJson());

  Future<void> uploadPhoto(Uint8List jpeg) async {
    final res = await _http.put(
      _u('/v1/me/photo'),
      headers: {..._headers, 'Content-Type': 'image/jpeg'},
      body: jpeg,
    );
    if (res.statusCode >= 300) throw ApiException(res.statusCode, res.body);
  }

  String photoUrl(String userId) => '$baseUrl/v1/users/$userId/photo';

  Future<void> deleteAccount() => _send('DELETE', '/v1/me');

  Future<CheckinResult> checkin({
    required String mode,
    required double self,
  }) async => CheckinResult.fromJson(
    await _send('POST', '/v1/checkins', body: {'mode': mode, 'self': self}),
  );

  Future<Radar> radar() async =>
      Radar.fromJson(await _send('GET', '/v1/radar'));

  Future<List<CatalogPlace>> searchPlaces(String q) async {
    final j = await _send('GET', '/v1/places', query: {'q': q});
    return [for (final p in j['places'] as List) CatalogPlace.fromJson(p)];
  }

  Future<void> setPlaces(List<String> ids) =>
      _send('PUT', '/v1/me/places', body: {'place_ids': ids});

  Future<LocationData> locationData() async =>
      LocationData.fromJson(await _send('GET', '/v1/me/location-data'));

  /// Wordless hello to someone on the radar. Returns the wall id when mutual.
  Future<({bool matched, int? wallId})> wave(String to) async {
    final j = await _send('POST', '/v1/waves', body: {'to': to});
    return (
      matched: j['matched'] as bool? ?? false,
      wallId: j['wall_id'] as int?,
    );
  }

  Future<List<MatchView>> matches() async {
    final j = await _send('GET', '/v1/matches');
    return [
      for (final m in j['matches'] as List)
        MatchView.fromJson(m as Map<String, dynamic>),
    ];
  }

  Future<List<Sticker>> stickers(int wall, {int after = 0}) async {
    final j = await _send(
      'GET',
      '/v1/walls/$wall/stickers',
      query: {'after': '$after'},
    );
    return [
      for (final s in j['stickers'] as List)
        Sticker.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<Sticker> stick(int wall, Sticker s) async => Sticker.fromJson(
    await _send('POST', '/v1/walls/$wall/stickers', body: s.toInput()),
  );

  Future<void> move(int wall, Sticker s) => _send(
    'PATCH',
    '/v1/walls/$wall/stickers/${s.id}',
    body: {
      'X': s.x,
      'Y': s.y,
      'Rotation': s.rotation,
      'Scale': s.scale,
      'Z': s.z,
    },
  );

  Future<void> peel(int wall, int id) =>
      _send('DELETE', '/v1/walls/$wall/stickers/$id');

  Future<void> report({int? stickerId, String? userId, bool block = false}) =>
      _send(
        'POST',
        '/v1/reports',
        body: {'sticker_id': ?stickerId, 'user_id': ?userId, 'block': block},
      );

  /// Layer B opt-in. Turning it off deletes keys and encounters on the server.
  Future<void> setFlyby(bool enabled) =>
      _send('PUT', '/v1/me/flyby', body: {'enabled': enabled});

  /// Yesterday's key only; the server rejects any other day.
  Future<void> uploadFlybyKey(String day, List<int> tek) => _send(
    'POST',
    '/v1/flyby/keys',
    body: {'day': day, 'tek': base64Encode(tek)},
  );

  Future<List<({String day, Uint8List tek})>> flybyKeys() async {
    final j = await _send('GET', '/v1/flyby/keys');
    return [
      for (final k in j['keys'] as List)
        (day: k['day'] as String, tek: base64Decode(k['tek'] as String)),
    ];
  }

  Future<void> waveFlyby(String day, List<int> tek, String kind) => _send(
    'POST',
    '/v1/flyby/waves',
    body: {'day': day, 'tek': base64Encode(tek), 'kind': kind},
  );

  /// WebSocket URL with a single-use ticket (the token never goes into a URL).
  Future<Uri> wallSocket(int wall) async {
    final j = await _send('POST', '/v1/walls/$wall/ticket');
    final base = Uri.parse(baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/walls/$wall/ws',
      queryParameters: {'ticket': j['ticket'] as String},
    );
  }
}

class MatchView {
  MatchView({
    required this.wallId,
    required this.kind,
    required this.otherId,
    this.otherNickname = '',
    this.sharedPlaces = const [],
  });
  final int wallId;
  final String kind;
  final String otherId;
  final String otherNickname;
  final List<String> sharedPlaces;
  factory MatchView.fromJson(Map<String, dynamic> j) => MatchView(
    wallId: j['wall_id'] as int,
    kind: j['kind'] as String,
    otherId: j['other_id'] as String,
    otherNickname: j['other_nickname'] as String? ?? '',
    sharedPlaces: _strs(j['shared_places']),
  );
}

/// Handwritten vector ink: strokes of 0..1 points within a box of [aspect].
class InkDrawing {
  InkDrawing({required this.aspect, required this.strokes});
  final double aspect;
  final List<InkStroke> strokes;
  Map<String, dynamic> toJson() => {
    'aspect': aspect,
    'strokes': [for (final s in strokes) s.toJson()],
  };
  factory InkDrawing.fromJson(Map<String, dynamic> j) => InkDrawing(
    aspect: (j['aspect'] as num).toDouble(),
    strokes: [
      for (final s in j['strokes'] as List)
        InkStroke.fromJson(s as Map<String, dynamic>),
    ],
  );
}

class InkStroke {
  InkStroke({required this.color, required this.width, required this.points});
  final int color;
  final double width;
  final List<double> points;
  Map<String, dynamic> toJson() => {'c': color, 'w': width, 'p': points};
  factory InkStroke.fromJson(Map<String, dynamic> j) => InkStroke(
    color: j['c'] as int,
    width: (j['w'] as num).toDouble(),
    points: [for (final v in j['p'] as List) (v as num).toDouble()],
  );
}

class Sticker {
  Sticker({
    this.id = 0,
    required this.clientId,
    required this.authorId,
    required this.kind,
    this.preset,
    this.ink,
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.scale = 1,
    this.z = 0,
    this.pending = false,
  });
  int id;
  final String clientId;
  final String authorId;
  final String kind; // ink | preset
  final String? preset;
  final InkDrawing? ink;
  double x, y, rotation, scale;
  int z;
  bool pending; // queued offline, not yet on the server

  factory Sticker.fromJson(Map<String, dynamic> j) => Sticker(
    id: j['id'] as int,
    clientId: j['client_id'] as String,
    authorId: j['author_id'] as String,
    kind: j['kind'] as String,
    preset: j['preset'] as String?,
    ink: j['ink'] == null
        ? null
        : InkDrawing.fromJson(j['ink'] as Map<String, dynamic>),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    rotation: (j['rotation'] as num? ?? 0).toDouble(),
    scale: (j['scale'] as num? ?? 1).toDouble(),
    z: j['z'] as int? ?? 0,
  );

  Map<String, dynamic> toInput() => {
    'client_id': clientId,
    'kind': kind,
    'preset': ?preset,
    if (ink != null) 'ink': ink!.toJson(),
    'x': x,
    'y': y,
    'rotation': rotation,
    'scale': scale,
  };
}

List<String> _strs(dynamic v) => [
  for (final x in (v as List? ?? const [])) x as String,
];

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
  Me({
    required this.userId,
    required this.moodConsent,
    required this.hasPhoto,
    this.profile,
  });
  final String userId;
  final bool moodConsent;
  final bool hasPhoto;
  final Profile? profile;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
    userId: j['user_id'] as String,
    moodConsent: j['mood_consent'] as bool? ?? false,
    hasPhoto: j['has_photo'] as bool? ?? false,
    profile: j['profile'] == null
        ? null
        : Profile.fromJson(j['profile'] as Map<String, dynamic>),
  );
}

class CheckinResult {
  CheckinResult(this.level, this.trend, this.supportCard, this.askAgainSoon);
  final String level;
  final String trend;
  final bool supportCard;
  final bool askAgainSoon;

  factory CheckinResult.fromJson(Map<String, dynamic> j) => CheckinResult(
    j['level'] as String,
    j['trend'] as String,
    j['support_card'] as bool? ?? false,
    j['ask_again_soon'] as bool? ?? false,
  );
}

class Planet {
  Planet({
    required this.userId,
    required this.kind,
    required this.level,
    required this.trend,
    required this.intents,
    this.star,
    this.weakSignal = false,
    this.comet,
  });
  final String userId;
  final String kind; // match | encourage
  final String level;
  final String trend;
  final List<String> intents;
  final String? star;
  final bool weakSignal;
  final String? comet; // mutual fly-by: vehicle | stop | venue

  factory Planet.fromJson(Map<String, dynamic> j) => Planet(
    userId: j['user_id'] as String,
    kind: j['kind'] as String,
    level: j['level'] as String,
    trend: j['trend'] as String,
    intents: _strs(j['intents']),
    star: j['star'] as String?,
    weakSignal: j['weak_signal'] as bool? ?? false,
    comet: j['comet'] as String?,
  );
}

class Radar {
  Radar(this.offRadar, this.planets);
  final bool offRadar;
  final List<Planet> planets;
  factory Radar.fromJson(Map<String, dynamic> j) =>
      Radar(j['off_radar'] as bool? ?? false, [
        for (final p in j['planets'] as List)
          Planet.fromJson(p as Map<String, dynamic>),
      ]);
}

class CatalogPlace {
  CatalogPlace({
    required this.id,
    required this.kind,
    required this.name,
    this.subtype = '',
  });
  final String id;
  final String kind;
  final String name;
  final String subtype;
  factory CatalogPlace.fromJson(Map<String, dynamic> j) => CatalogPlace(
    id: j['place_id'] as String,
    kind: j['kind'] as String,
    name: j['name'] as String,
    subtype: j['subtype'] as String? ?? '',
  );
}

class LocationData {
  LocationData(this.places, this.activeKeys, this.venueCheckins);
  final List<CatalogPlace> places;
  final int activeKeys;
  final List<String> venueCheckins;
  factory LocationData.fromJson(Map<String, dynamic> j) => LocationData(
    [
      for (final p in j['places'] as List)
        CatalogPlace.fromJson(p as Map<String, dynamic>),
    ],
    j['active_encounter_keys'] as int? ?? 0,
    _strs(j['venue_checkins']),
  );
}
