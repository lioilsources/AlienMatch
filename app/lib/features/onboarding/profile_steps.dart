import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'capture_screen.dart';

/// Generated default nickname, e.g. "Zq-7".
String alienNickname([Random? rnd]) {
  final r = rnd ?? Random();
  const cons = 'BCDFGHJKLMNPQRSTVWXZ';
  const low = 'aeiouyqxz';
  return '${cons[r.nextInt(cons.length)]}${low[r.nextInt(low.length)]}-${r.nextInt(90) + 1}';
}

/// Icon-only profile steps, then the live photo. The nickname is the single
/// free-text field in the whole product.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.random});
  final Random? random;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int step = 0;
  String? generation;
  String? status;
  int? kidsCount;
  final kidsFlags = <String>{};
  final intents = <String>{};
  final seekGenerations = <String>{};
  final seekStatuses = <String>{};
  bool canBeBeacon = false, wantsEncouragement = false, beaconOnly = false;
  late final TextEditingController nick = TextEditingController(text: alienNickname(widget.random));
  bool saving = false, failed = false;
  bool profileSaved = false;

  static const steps = 7;

  @override
  void dispose() {
    nick.dispose();
    super.dispose();
  }

  bool get canNext => switch (step) {
        0 => generation != null,
        1 => status != null,
        3 => intents.isNotEmpty,
        6 => !saving,
        _ => true,
      };

  Future<void> _save() async {
    setState(() {
      saving = true;
      failed = false;
    });
    final app = AppScope.of(context);
    try {
      await app.api.saveProfile(Profile(
        nickname: nick.text.trim(),
        generation: generation!,
        status: status!,
        kidsCount: kidsCount,
        kidsFlags: kidsFlags.toList(),
        seekGenerations: seekGenerations.toList(),
        seekStatuses: seekStatuses.toList(),
        intents: intents.toList(),
        canBeBeacon: canBeBeacon || beaconOnly,
        wantsEncouragement: wantsEncouragement,
        beaconOnly: beaconOnly,
      ));
      if (mounted) setState(() => profileSaved = true);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _next() {
    if (step == steps - 1) {
      _save();
    } else {
      setState(() => step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Profile already on the server (photo missing): go straight to the camera.
    if (profileSaved || AppScope.of(context).me?.profile != null) return const CaptureScreen();
    final l = AppLocalizations.of(context);
    final (title, body) = switch (step) {
      0 => (l.generationTitle, _single(Glyphs.generations, generation, (v) => generation = v)),
      1 => (l.statusTitle, _single(Glyphs.statuses, status, (v) => status = v)),
      2 => (l.kidsTitle, _kids()),
      3 => (l.intentsTitle, _multi(Glyphs.intents, intents)),
      4 => (l.seekTitle, Column(children: [_multi(Glyphs.generations, seekGenerations), const SizedBox(height: 24), _multi(Glyphs.statuses, seekStatuses)])),
      5 => (l.modesTitle, _modes(l)),
      _ => (l.nicknameTitle, _nickname(l)),
    };
    return Scaffold(
      appBar: AppBar(
        leading: step > 0 ? IconButton(tooltip: l.back, icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => step--)) : null,
        title: LinearProgressIndicator(value: (step + 1) / (steps + 1)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            body,
            if (failed) Padding(padding: const EdgeInsets.only(top: 16), child: Text(l.errorGeneric, style: const TextStyle(color: Colors.redAccent))),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('next'),
            onPressed: canNext ? _next : null,
            child: Padding(padding: const EdgeInsets.all(12), child: Text(step == steps - 1 ? l.finish : l.next)),
          ),
        ),
      ),
    );
  }

  Widget _wrap(List<Widget> c) => Wrap(spacing: 12, runSpacing: 12, children: c);

  Widget _single(List<Glyph> set, String? current, void Function(String) pick) {
    final l = AppLocalizations.of(context);
    return _wrap([
      for (final g in set)
        GlyphTile(key: Key('g-${g.id}'), emoji: g.emoji, label: Glyphs.label(l, g.id), selected: current == g.id, onTap: () => setState(() => pick(g.id))),
    ]);
  }

  Widget _multi(List<Glyph> set, Set<String> sel) {
    final l = AppLocalizations.of(context);
    return _wrap([
      for (final g in set)
        GlyphTile(
          key: Key('m-${g.id}'),
          emoji: g.emoji,
          label: Glyphs.label(l, g.id),
          selected: sel.contains(g.id),
          onTap: () => setState(() => sel.contains(g.id) ? sel.remove(g.id) : sel.add(g.id)),
        ),
    ]);
  }

  Widget _kids() {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _wrap([
        for (var n = 0; n <= 5; n++)
          GlyphTile(
            emoji: n == 5 ? '5+' : '$n',
            label: '$n',
            selected: kidsCount == n,
            onTap: () => setState(() => kidsCount = kidsCount == n ? null : n),
          ),
      ]),
      const SizedBox(height: 24),
      _wrap([
        for (final g in Glyphs.kidsFlags)
          GlyphTile(
            emoji: g.emoji,
            label: Glyphs.label(l, g.id),
            selected: kidsFlags.contains(g.id),
            onTap: () => setState(() => kidsFlags.contains(g.id) ? kidsFlags.remove(g.id) : kidsFlags.add(g.id)),
          ),
      ]),
    ]);
  }

  Widget _modes(AppLocalizations l) => Column(children: [
        SwitchListTile(value: canBeBeacon || beaconOnly, onChanged: beaconOnly ? null : (v) => setState(() => canBeBeacon = v), secondary: const Text('🗼', style: TextStyle(fontSize: 28)), title: Text(l.beaconSwitch)),
        SwitchListTile(value: beaconOnly, onChanged: (v) => setState(() => beaconOnly = v), secondary: const Text('✨', style: TextStyle(fontSize: 28)), title: Text(l.beaconOnlySwitch)),
        SwitchListTile(value: wantsEncouragement, onChanged: (v) => setState(() => wantsEncouragement = v), secondary: const Text('💛', style: TextStyle(fontSize: 28)), title: Text(l.encourageSwitch)),
      ]);

  Widget _nickname(AppLocalizations l) => TextField(
        key: const Key('nickname'),
        controller: nick,
        maxLength: 12,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\p{L}\p{N}.\-]', unicode: true))],
        decoration: InputDecoration(helperText: l.nicknameHint),
        style: const TextStyle(fontSize: 28),
      );
}
