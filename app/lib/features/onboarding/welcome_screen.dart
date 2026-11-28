import 'package:flutter/material.dart';
import 'package:ol1n_telemetry/ol1n_telemetry.dart';

import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Consents first: 18+ (mandatory) and the separate, optional GDPR art. 9
/// consent for mood scoring from face and voice. No e-mail, no phone.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool adult = false;
  bool moodConsent = false;
  bool busy = false;
  bool failed = false;

  Future<void> _start() async {
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await AppScope.of(context).createAccount(moodConsent: moodConsent);
    } catch (_) {
      Telemetry.errorShown('network');
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            const Center(child: Text('👽', style: TextStyle(fontSize: 96))),
            const SizedBox(height: 16),
            Text(
              l.appTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l.tagline,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Space.dim),
            ),
            const SizedBox(height: 40),
            CheckboxListTile(
              key: const Key('adult'),
              value: adult,
              onChanged: (v) => setState(() => adult = v ?? false),
              title: Text(l.adultConfirm),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            SwitchListTile(
              key: const Key('moodConsent'),
              value: moodConsent,
              onChanged: (v) => setState(() => moodConsent = v),
              title: Text(l.moodConsentTitle),
              subtitle: Text(l.moodConsentBody),
            ),
            const SizedBox(height: 24),
            if (failed)
              Text(
                l.errorGeneric,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            FilledButton(
              key: const Key('start'),
              onPressed: adult && !busy ? _start : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l.start),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
