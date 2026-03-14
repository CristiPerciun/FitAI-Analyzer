import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/ui/alimentazione/alimentazione_screen.dart';
import 'package:fitai_analyzer/ui/dashboard/dashboard_screen.dart';
import 'package:fitai_analyzer/ui/home/home_screen.dart';
import 'package:fitai_analyzer/ui/impostazioni/impostazioni_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shell principale con bottom navigation bar.
class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.directions_bike_outlined, label: 'Allenamenti'),
    (icon: Icons.restaurant_outlined, label: 'Alimentazione'),
    (icon: Icons.settings_outlined, label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabIndexProvider);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [
          HomeScreen(),
          DashboardScreen(),
          AlimentazioneScreen(),
          ImpostazioniScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(selectedTabIndexProvider.notifier).state = i,
        labelBehavior: isNarrow
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(_selectedIcon(t.icon)),
                label: t.label,
              ),
            )
            .toList(),
        ),
      ),
    );
  }

  IconData _selectedIcon(IconData outline) {
    switch (outline) {
      case Icons.home_outlined:
        return Icons.home;
      case Icons.directions_bike_outlined:
        return Icons.directions_bike;
      case Icons.restaurant_outlined:
        return Icons.restaurant;
      case Icons.settings_outlined:
        return Icons.settings;
      default:
        return outline;
    }
  }
}
