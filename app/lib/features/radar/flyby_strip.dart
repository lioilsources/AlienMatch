import 'package:flutter/material.dart';

import '../../design/space.dart';
import '../../flyby/controller.dart';
import '../../flyby/protocol.dart';
import '../../l10n/app_localizations.dart';

String contactEmoji(String kind) => switch (kind) {
  'vehicle' => '🚋',
  'stop' => '🚏',
  _ => '☕',
};

String contactLabel(AppLocalizations l, String kind) => switch (kind) {
  'vehicle' => l.flybyVehicle,
  'stop' => l.flybyStop,
  _ => l.flybyVenue,
};

/// Local fly-bys from the last days: no identity, no time, no place.
/// Waving tells the server "I'd like to meet the holder of that key".
class FlybyStrip extends StatelessWidget {
  const FlybyStrip({super.key, required this.flyby});
  final FlybyController flyby;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: flyby,
      builder: (context, _) {
        if (!flyby.enabled || flyby.encounters.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              Center(
                child: Text(
                  '☄️ ${l.flybyStrip}',
                  style: const TextStyle(color: Space.dim),
                ),
              ),
              for (final e in flyby.encounters)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    key: Key('flyby-${e.id}'),
                    avatar: Text(contactEmoji(e.kind.name)),
                    label: Text(
                      '${contactLabel(l, e.kind.name)} · ${l.flybyMinutes(e.minutes)}  👋',
                    ),
                    onPressed: () => flyby.wave(e),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Exposed for tests.
String kindName(ContactKind k) => k.name;
