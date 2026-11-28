import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import '../l10n/app_localizations.dart';

/// The app version this build reports; `test/telemetry_test.dart` keeps it
/// equal to `version:` in `pubspec.yaml`.
const kAppVersion = '1.0.0';

/// Route name → screen for the routes pushed on top of the root. The root
/// route (`/`) shows the stage or home tab of the moment: see
/// [kRootScreens] and `AppScreens`.
const kScreenRoutes = {
  '/wall': 'wall',
  '/ink': 'ink',
  '/faces': 'faces',
  '/capture': 'capture',
  '/stars': 'stars',
  '/liked': 'liked',
};

/// What the root route can show: the start-up stages and the five home tabs.
const kRootScreens = {
  'loading',
  'welcome',
  'onboarding',
  'capture',
  'radar',
  'walls',
  'checkin',
  'places',
  'settings',
};

/// Home tabs in the order of the navigation bar.
const kHomeTabs = ['radar', 'walls', 'checkin', 'places', 'settings'];

/// Result of a wave: `match` (mutual, a wall opened), `sent`, `limit` (daily
/// limit reached), `error`.
const kWaveResults = {'match', 'sent', 'limit', 'error'};

/// The one event dictionary of AlienMatch, mirrored in `docs/telemetry.md`.
///
/// Nothing here may be linkable to the account: no token, no id, no
/// nickname, region, generation, kids, mood or anything from the profile,
/// walls or check-ins. Only screens, features and flow results.
final appDictionary = TelemetryDictionary(
  appVersion: kAppVersion,
  languages: {
    for (final l in AppLocalizations.supportedLocales) telemetryLocaleId(l),
  },
  screens: {...kRootScreens, ...kScreenRoutes.values},
  features: {
    'filter',
    'album',
    'face_switch',
    'stars_rate',
    'liked',
    'places_search',
    'sticker_ink',
    'sticker_preset',
    'flyby',
    'report',
  },
  errorKinds: {'network', 'camera', 'permission', 'album_full'},
  events: {
    'account_create': {
      'result': const EnumProp({'ok', 'error'}),
    },
    ...TelemetryDictionary.flow('onboarding', end: {'step': const IntProp(7)}),
    ...TelemetryDictionary.flow(
      'photo',
      start: {
        'source': const EnumProp({'onboarding', 'album'}),
      },
    ),
    'wave_send': {
      'source': const EnumProp({'radar', 'liked', 'flyby'}),
      'result': const EnumProp(kWaveResults),
    },
    'checkin_send': {
      'result': const EnumProp({'ok', 'error'}),
    },
    'places_save': {
      'result': const EnumProp({'ok', 'error'}),
    },
    'account_delete': {
      'result': const EnumProp({'ok', 'cancel', 'error'}),
    },
  },
);
