import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/sync_backfill_status_provider.dart';
import 'package:fitai_analyzer/ui/alimentazione/alimentazione_screen.dart';
import 'package:fitai_analyzer/utils/boot_log.dart';
import 'package:fitai_analyzer/ui/dashboard/dashboard_screen.dart';
import 'package:fitai_analyzer/ui/home/home_screen.dart';
import 'package:fitai_analyzer/ui/impostazioni/impostazioni_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shell principale con bottom navigation bar.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  static const _tabs = [
    (icon: Icons.home_outlined, label: 'Home'),
    (icon: Icons.directions_bike_outlined, label: 'Allenamenti'),
    (icon: Icons.restaurant_outlined, label: 'Alimentazione'),
    (icon: Icons.settings_outlined, label: 'Impostazioni'),
  ];

  @override
  void initState() {
    super.initState();
    bootLog(
      'MainShell: shell montata (IndexedStack; Home è il tab 0 e costruisce subito)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(selectedTabIndexProvider);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final backfillAsync = ref.watch(syncBackfillStatusStreamProvider);
    final backfill = backfillAsync.valueOrNull;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (backfill != null && backfill.isActive)
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backfill.message ??
                          'Sincronizzazione storico in corso sul server…',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (backfill.progress != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: backfill.progress),
                    ] else ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: const [
                HomeScreen(),
                DashboardScreen(),
                AlimentazioneScreen(),
                ImpostazioniScreen(),
              ],
            ),
          ),
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

  static IconData _selectedIcon(IconData outline) {
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
