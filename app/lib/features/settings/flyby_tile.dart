import 'package:flutter/material.dart';

import '../../design/space.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';

/// Opt-in switch for layer B. Off deletes keys and encounters everywhere.
class FlybyTile extends StatefulWidget {
  const FlybyTile({super.key});

  @override
  State<FlybyTile> createState() => _FlybyTileState();
}

class _FlybyTileState extends State<FlybyTile> {
  bool busy = false;

  Future<void> _toggle(bool on) async {
    final f = AppScope.of(context).flyby!;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    try {
      await f.setEnabled(on);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = AppScope.of(context).flyby;
    if (f == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: f,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('flybySwitch'),
            value: f.enabled,
            onChanged: busy ? null : _toggle,
            secondary: const Text('☄️', style: TextStyle(fontSize: 28)),
            title: Text(l.flybyTitle),
            subtitle: Text(
              l.flybyBody,
              style: const TextStyle(color: Space.dim),
            ),
          ),
          if (f.enabled && !f.radioOn)
            ListTile(
              key: const Key('flybyRadioOff'),
              leading: const Icon(
                Icons.bluetooth_disabled,
                color: Colors.orangeAccent,
              ),
              title: Text(l.flybyRadioOff),
              trailing: TextButton(
                onPressed: busy ? null : () => _toggle(true),
                child: Text(l.retry),
              ),
            ),
        ],
      ),
    );
  }
}
