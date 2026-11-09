import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../checkin/checkin_screen.dart';
import '../places/places_screen.dart';
import '../radar/radar_screen.dart';
import '../settings/settings_screen.dart';
import '../walls/walls_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: const [RadarScreen(), WallsScreen(), CheckinScreen(), PlacesScreen(), SettingsScreen()]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.radar), label: l.navRadar),
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: l.navWalls),
          NavigationDestination(icon: const Icon(Icons.wb_sunny_outlined), label: l.navCheckin),
          NavigationDestination(icon: const Icon(Icons.star_outline), label: l.navPlaces),
          NavigationDestination(icon: const Icon(Icons.tune), label: l.navSettings),
        ],
      ),
    );
  }
}
