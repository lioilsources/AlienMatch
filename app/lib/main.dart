import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';
import 'package:path_provider/path_provider.dart';

import 'api/api.dart';
import 'flyby/controller.dart';
import 'flyby/motion.dart';
import 'flyby/radio.dart';
import 'flyby/store.dart';
import 'design/space.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/profile_steps.dart';
import 'features/onboarding/welcome_screen.dart';
import 'l10n/app_localizations.dart';
import 'state/app_state.dart';
import 'state/face_album.dart';
import 'telemetry/app_screens.dart';
import 'telemetry/telemetry_dictionary.dart';

void main() {
  // Must run before AppState.load(): reading the token uses a platform channel.
  WidgetsFlutterBinding.ensureInitialized();
  final tokens = SecureTokenStore();
  unawaited(_startTelemetry(tokens));
  final state = AppState(
    api: Api(),
    tokens: tokens,
    album: FaceAlbum(FileFaceStorage()),
    flybyFactory: (api) => FlybyController(
      api: api,
      store: DeviceFlybyStore(),
      radio: NativeFlybyRadio(),
      motion: motionStream(),
    ),
  )..load();
  runApp(AlienMatchApp(state: state));
}

/// Anonymous usage statistics (`docs/telemetry.md`). They go only to the
/// developer's own collector through `ol1n_telemetry`, never through the
/// AlienMatch API, and carry nothing linkable to the account. Without
/// TELEMETRY_KEY and TELEMETRY_HOST (local builds, tests) and on the web
/// nothing is recorded or sent.
Future<void> _startTelemetry(TokenStore tokens) async {
  try {
    final dir = kIsWeb ? '' : (await getApplicationSupportDirectory()).path;
    await Telemetry.init(
      app: 'alienmatch',
      appVersion: kAppVersion,
      dictionary: appDictionary,
      store: FileTelemetryStore('$dir/telemetry'),
      lang: _telemetryLang,
      // Only whether an account existed before measuring began: an existing
      // user is not a new install. The token itself never leaves this check.
      hadDataBefore: () async {
        try {
          return await tokens.read() != null;
        } catch (_) {
          return false;
        }
      },
    );
  } catch (_) {
    // Measuring must never affect the app.
  }
}

String _telemetryLang() {
  final locale = basicLocaleListResolution(
    WidgetsBinding.instance.platformDispatcher.locales,
    AppLocalizations.supportedLocales,
  );
  return telemetryLocaleId(locale);
}

class AlienMatchApp extends StatefulWidget {
  const AlienMatchApp({super.key, required this.state});
  final AppState state;

  @override
  State<AlienMatchApp> createState() => _AlienMatchAppState();
}

class _AlienMatchAppState extends State<AlienMatchApp> {
  final screens = AppScreens();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp(
        navigatorObservers: [screens],
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
        theme: Space.theme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    // Onboarding and home report their own screen (step or tab).
    if (s.stage == Stage.loading) AppScreens.root('loading');
    if (s.stage == Stage.welcome) AppScreens.root('welcome');
    return switch (s.stage) {
      Stage.loading when s.error != null => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📡', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).errorGeneric),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('startupRetry'),
                onPressed: s.refresh,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      ),
      Stage.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      Stage.welcome => const WelcomeScreen(),
      Stage.onboarding => const OnboardingFlow(),
      Stage.home => const HomeScreen(),
    };
  }
}
