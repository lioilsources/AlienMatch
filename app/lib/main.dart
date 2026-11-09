import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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

void main() {
  final state = AppState(
    api: Api(),
    tokens: SecureTokenStore(),
    flybyFactory: (api) => FlybyController(
      api: api,
      store: DeviceFlybyStore(),
      radio: NativeFlybyRadio(),
      motion: motionStream(),
    ),
  )..load();
  runApp(AlienMatchApp(state: state));
}

class AlienMatchApp extends StatelessWidget {
  const AlienMatchApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
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
    return switch (s.stage) {
      Stage.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      Stage.welcome => const WelcomeScreen(),
      Stage.onboarding => const OnboardingFlow(),
      Stage.home => const HomeScreen(),
    };
  }
}
