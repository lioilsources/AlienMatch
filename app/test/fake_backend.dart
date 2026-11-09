import 'dart:convert';

import 'package:alienmatch/api/api.dart';
import 'package:alienmatch/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryTokens implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> clear() async => token = null;
}

const _coordinateKeys = ['lat', 'lon', 'lng', 'latitude', 'longitude', 'geohash', 'gps', 'location', 'coords'];

/// In-memory backend. Every request is checked: the app must never send
/// coordinates or an e-mail, in the query or the body.
class FakeBackend {
  final requests = <http.Request>[];
  Map<String, dynamic>? profile;
  bool hasPhoto = false;
  Map<String, dynamic> radar = {'off_radar': true, 'planets': []};
  Map<String, dynamic> checkinResult = {'level': 'MID', 'trend': 'FLAT', 'support_card': false, 'ask_again_soon': false};
  List<String> myPlaces = [];
  bool deleted = false;
  bool waveMatches = false;
  int waveStatus = 200;
  List<Map<String, dynamic>> matchList = [];
  final stickers = <Map<String, dynamic>>[];
  int stickFailures = 0; // simulate offline: first N sticker posts fail
  final stickClientIds = <String>[];
  final reports = <Map<String, dynamic>>[];
  bool? flybyEnabled;
  final uploadedKeys = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> flybyKeys = [];
  final flybyWaves = <Map<String, dynamic>>[];

  late final client = MockClient((req) async {
    requests.add(req);
    for (final k in req.url.queryParameters.keys) {
      expect(_coordinateKeys.contains(k.toLowerCase()), isFalse, reason: 'coordinate in query: ${req.url}');
    }
    if (req.headers['content-type']?.contains('json') == true && req.body.isNotEmpty) {
      _noForbiddenKeys(jsonDecode(req.body));
    }
    final path = '${req.method} ${req.url.path}';
    final wallStickers = RegExp(r'^(GET|POST) /v1/walls/(\d+)/stickers$').firstMatch(path);
    if (wallStickers != null) {
      if (wallStickers.group(1) == 'GET') return _json({'stickers': stickers});
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      stickClientIds.add(body['client_id'] as String);
      if (stickFailures > 0) {
        stickFailures--;
        throw http.ClientException('offline');
      }
      final st = {...body, 'id': stickers.length + 1, 'author_id': 'u1', 'z': stickers.length + 1, 'wall_id': int.parse(wallStickers.group(2)!)};
      stickers.add(st);
      return _json(st, 201);
    }
    if (RegExp(r'^POST /v1/walls/\d+/ticket$').hasMatch(path)) return _json({'ticket': 'tk'});
    switch (path) {
      case 'PUT /v1/me/flyby':
        flybyEnabled = (jsonDecode(req.body) as Map)['enabled'] as bool;
        return http.Response('', 204);
      case 'POST /v1/flyby/keys':
        uploadedKeys.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('', 204);
      case 'GET /v1/flyby/keys':
        return _json({'keys': flybyKeys});
      case 'POST /v1/flyby/waves':
        flybyWaves.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('', 202);
      case 'POST /v1/waves':
        if (waveStatus != 200) return http.Response('limit', waveStatus);
        return _json({'matched': waveMatches, if (waveMatches) 'kind': 'match', if (waveMatches) 'wall_id': 7});
      case 'GET /v1/matches':
        return _json({'matches': matchList});
      case 'POST /v1/reports':
        reports.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('', 204);
      case 'POST /v1/accounts':
        return _json({'user_id': 'u1', 'token': 't' * 43}, 201);
      case 'GET /v1/me':
        if (deleted) return http.Response('', 401);
        return _json({'user_id': 'u1', 'mood_consent': false, 'vl_enabled': false, 'has_profile': profile != null, 'has_photo': hasPhoto, 'profile': ?profile});
      case 'PUT /v1/me/profile':
        profile = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('', 204);
      case 'PUT /v1/me/photo':
        hasPhoto = true;
        return http.Response('', 204);
      case 'DELETE /v1/me':
        deleted = true;
        return http.Response('', 204);
      case 'POST /v1/checkins':
        return _json(checkinResult);
      case 'GET /v1/radar':
        return _json(radar);
      case 'GET /v1/places':
        return _json({'places': [{'place_id': 'stop:pid:N1040', 'kind': 'stop', 'name': 'Anděl'}]});
      case 'PUT /v1/me/places':
        myPlaces = [for (final p in (jsonDecode(req.body)['place_ids'] as List)) p as String];
        return http.Response('', 204);
      case 'GET /v1/me/location-data':
        return _json({'places': [for (final p in myPlaces) {'place_id': p, 'kind': 'stop', 'name': 'Anděl'}], 'active_encounter_keys': 0, 'venue_checkins': [], 'coordinates': []});
    }
    return http.Response('not found: $path', 404);
  });

  void _noForbiddenKeys(dynamic v) {
    if (v is Map) {
      for (final e in v.entries) {
        expect(_coordinateKeys.contains((e.key as String).toLowerCase()), isFalse, reason: 'coordinate in body: $v');
        expect(e.key, isNot('email'));
        _noForbiddenKeys(e.value);
      }
    } else if (v is List) {
      v.forEach(_noForbiddenKeys);
    }
  }

  http.Response _json(Object o, [int code = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json'});

  Api api() => Api(client: client, baseUrl: 'http://test');

  static Map<String, dynamic> sampleProfile() => {
        'generation': 'genz', 'status': 'single', 'region': 'CZ-PHA', 'intents': ['coffee'],
        'kids_flags': [], 'seek_generations': [], 'seek_statuses': [],
      };
}
