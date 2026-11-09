import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import 'recorder.dart';

/// Normative daily check-in: always the same two prompts, so days compare.
/// Video + voice, or voice only; then the user's own wordless rating, which
/// always weighs more than the model's. Without consent or without scoring
/// on the server, only the rating is sent (mode "self").
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key, this.recorderFactory, this.promptLength = const Duration(seconds: 7)});
  final CheckinRecorder Function()? recorderFactory;
  final Duration promptLength;

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

enum _Step { choose, recording, rate, done }

class _CheckinScreenState extends State<CheckinScreen> {
  _Step step = _Step.choose;
  bool? scoringAvailable;
  String mode = 'self';
  CheckinRecorder? rec;
  Recording? recording;
  int prompt = 0;
  double value = 0.5;
  bool busy = false, failed = false, noPermission = false, signal = false;
  CheckinResult? result;
  Timer? timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (scoringAvailable == null) {
      scoringAvailable = false;
      final app = AppScope.of(context);
      if (!kIsWeb && app.me?.moodConsent == true) {
        app.api.moodScoringAvailable().then((v) {
          if (mounted) setState(() => scoringAvailable = v);
        }, onError: (_) {});
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    rec?.dispose();
    super.dispose();
  }

  Future<void> _record(String m) async {
    setState(() {
      mode = m;
      noPermission = false;
      busy = true;
    });
    final r = (widget.recorderFactory ?? DeviceCheckinRecorder.new)();
    if (!await r.prepare(video: m == 'video')) {
      await r.dispose();
      if (mounted) {
        setState(() {
          noPermission = true;
          busy = false;
        });
      }
      return;
    }
    rec = r;
    await r.start();
    if (!mounted) return;
    setState(() {
      step = _Step.recording;
      prompt = 0;
      busy = false;
    });
    // Three key frames spread over both prompts.
    final p = widget.promptLength;
    for (final at in [p * 0.3, p * 1.0, p * 1.7]) {
      Future.delayed(at, () => step == _Step.recording && rec == r ? r.captureFrame() : null);
    }
    Future.delayed(p, () {
      if (mounted && step == _Step.recording) setState(() => prompt = 1);
    });
    timer = Timer(p * 2, _finishRecording);
  }

  Future<void> _finishRecording() async {
    final r = rec;
    if (r == null) return;
    final out = await r.stop();
    await r.dispose();
    rec = null;
    if (mounted) {
      setState(() {
        recording = out;
        step = _Step.rate;
      });
    }
  }

  Future<void> _send() async {
    final app = AppScope.of(context);
    final lang = Localizations.localeOf(context).toLanguageTag();
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final rec = recording;
      if (rec != null && mode != 'self') {
        final r = await app.api.checkinMedia(mode: mode, self: value, frames: mode == 'video' ? rec.frames : const [], audio: rec.audio, lang: lang);
        result = r.result;
        signal = r.signal;
      } else {
        result = await app.api.checkin(mode: 'self', self: value);
        signal = false;
      }
      recording = null; // drop media from memory
      if (mounted) setState(() => step = _Step.done);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l.checkinTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        ...switch (step) {
          _Step.choose => _choose(l),
          _Step.recording => _recordingView(l),
          _Step.rate => _rate(l),
          _Step.done => _done(l),
        },
      ],
    );
  }

  List<Widget> _choose(AppLocalizations l) {
    if (scoringAvailable != true) {
      return [Text(l.checkinSelfOnly, style: const TextStyle(color: Space.dim)), const SizedBox(height: 16), ..._rate(l)];
    }
    return [
      FilledButton.icon(
        key: const Key('modeVideo'),
        onPressed: busy ? null : () => _record('video'),
        icon: const Text('🎥', style: TextStyle(fontSize: 22)),
        label: Padding(padding: const EdgeInsets.all(12), child: Text(l.checkinVideo)),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('modeVoice'),
        onPressed: busy ? null : () => _record('voice'),
        icon: const Text('🎙️', style: TextStyle(fontSize: 22)),
        label: Padding(padding: const EdgeInsets.all(12), child: Text(l.checkinVoice)),
      ),
      const SizedBox(height: 12),
      TextButton(
        key: const Key('modeSelf'),
        onPressed: busy ? null : () => setState(() => step = _Step.rate),
        child: Text(l.checkinNoRecording),
      ),
      if (noPermission)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(l.checkinNoPermission, key: const Key('noPermission'), style: const TextStyle(color: Colors.orangeAccent)),
        ),
      const SizedBox(height: 16),
      Text(l.checkinMediaNote, style: const TextStyle(color: Space.dim)),
    ];
  }

  List<Widget> _recordingView(AppLocalizations l) {
    final cam = rec?.camera;
    return [
      if (cam != null && cam.value.isInitialized)
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(aspectRatio: 3 / 4, child: CameraPreview(cam)),
        )
      else
        const Center(child: Text('🎙️', style: TextStyle(fontSize: 96))),
      const SizedBox(height: 24),
      Text(prompt == 0 ? l.checkinPrompt1 : l.checkinPrompt2, key: Key('prompt$prompt'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      const LinearProgressIndicator(),
    ];
  }

  List<Widget> _rate(AppLocalizations l) => [
        if (recording != null) Text(l.checkinRateNow),
        const SizedBox(height: 16),
        Center(child: _Planet(value: value)),
        const SizedBox(height: 24),
        Row(children: [
          const Text('🌑', style: TextStyle(fontSize: 28)),
          Expanded(child: Slider(key: const Key('selfScale'), value: value, onChanged: busy ? null : (v) => setState(() => value = v))),
          const Text('🌟', style: TextStyle(fontSize: 28)),
        ]),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('sendSignal'),
          onPressed: busy ? null : _send,
          child: Padding(padding: const EdgeInsets.all(12), child: Text(l.checkinSend)),
        ),
        if (failed) Padding(padding: const EdgeInsets.only(top: 12), child: Text(l.errorGeneric, style: const TextStyle(color: Colors.redAccent))),
      ];

  List<Widget> _done(AppLocalizations l) {
    final r = result!;
    final region = AppScope.of(context).me?.profile?.region ?? 'CZ-PHA';
    return [
      Center(child: _Planet(value: value)),
      const SizedBox(height: 24),
      Text(l.checkinDone, key: const Key('checkinDone')),
      if (signal)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.checkinSignalUsed, key: const Key('signalUsed'), style: const TextStyle(color: Space.dim)),
        ),
      if (r.askAgainSoon) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.askAgain, style: const TextStyle(color: Space.dim))),
      if (r.supportCard)
        Card(
          key: const Key('supportCard'),
          color: Space.nebula,
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.supportTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(l.supportBody(crisisLine(region))),
            ]),
          ),
        ),
    ];
  }
}

class _Planet extends StatelessWidget {
  const _Planet({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final glow = Color.lerp(const Color(0xFF5B5670), const Color(0xFFFFE27A), value)!;
    final size = 90 + 70 * value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [glow, glow.withValues(alpha: 0.2)]),
        boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.6 * value), blurRadius: 60 * value, spreadRadius: 10 * value)],
      ),
    );
  }
}
