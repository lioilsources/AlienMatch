import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Daily check-in. The self scale goes from a grey planet to a supernova,
/// wordless. Video/voice capture arrives with the mood worker on SPARK; until
/// then this sends mode "self" honestly.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  double value = 0.5;
  bool busy = false;
  bool failed = false;
  CheckinResult? result;

  Future<void> _send() async {
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final r = await AppScope.of(
        context,
      ).api.checkin(mode: 'self', self: value);
      if (mounted) setState(() => result = r);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final region = AppScope.of(context).me?.profile?.region ?? 'CZ-PHA';
    final r = result;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l.checkinTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 32),
        Center(child: _Planet(value: value)),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text('🌑', style: TextStyle(fontSize: 28)),
            Expanded(
              child: Slider(
                key: const Key('selfScale'),
                value: value,
                onChanged: busy ? null : (v) => setState(() => value = v),
              ),
            ),
            const Text('🌟', style: TextStyle(fontSize: 28)),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.checkinSelfOnly, style: const TextStyle(color: Space.dim)),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('sendSignal'),
          onPressed: busy ? null : _send,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l.checkinSend),
          ),
        ),
        if (failed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              l.errorGeneric,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (r != null) ...[
          const SizedBox(height: 24),
          Text(l.checkinDone, key: const Key('checkinDone')),
          if (r.askAgainSoon)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.askAgain, style: const TextStyle(color: Space.dim)),
            ),
          if (r.supportCard)
            Card(
              key: const Key('supportCard'),
              color: Space.nebula,
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.supportTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(l.supportBody(crisisLine(region))),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Planet extends StatelessWidget {
  const _Planet({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final glow = Color.lerp(
      const Color(0xFF5B5670),
      const Color(0xFFFFE27A),
      value,
    )!;
    final size = 90 + 70 * value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [glow, glow.withValues(alpha: 0.2)]),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.6 * value),
            blurRadius: 60 * value,
            spreadRadius: 10 * value,
          ),
        ],
      ),
    );
  }
}
