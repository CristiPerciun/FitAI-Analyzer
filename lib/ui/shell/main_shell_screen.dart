import 'dart:ui' show ImageFilter;

import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/providers/pending_meal_analysis_provider.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/sync_backfill_status_provider.dart';
import 'package:fitai_analyzer/ui/alimentazione/alimentazione_screen.dart';
import 'package:fitai_analyzer/utils/boot_log.dart';
import 'package:fitai_analyzer/ui/dashboard/dashboard_screen.dart';
import 'package:fitai_analyzer/ui/home/home_screen.dart';
import 'package:fitai_analyzer/ui/impostazioni/impostazioni_screen.dart';
import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:fitai_analyzer/ui/widgets/nature_icon.dart';
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
    (asset: NatureIcons.home, label: 'Home'),
    (asset: NatureIcons.activity, label: 'Allenamenti'),
    (asset: NatureIcons.nutrition, label: 'Alimentazione'),
    (asset: NatureIcons.settings, label: 'Impostazioni'),
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
    ref.listen<List<PendingMealAnalysis>>(pendingMealAnalysisProvider, (
      prev,
      next,
    ) {
      if (prev == null) return;
      for (final p in next) {
        if (p.errorMessage == null || p.analyzing) continue;
        final wasAnalyzing = prev.any(
          (x) => x.id == p.id && x.analyzing && x.errorMessage == null,
        );
        if (!wasAnalyzing) continue;
        final msg = p.errorMessage!;
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(msg.length > 120 ? '${msg.substring(0, 120)}…' : msg),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Alimentazione',
              onPressed: () =>
                  ref.read(selectedTabIndexProvider.notifier).state = 2,
            ),
          ),
        );
      }
    });

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
      bottomNavigationBar: _buildGlassNav(context, index, isNarrow),
    );
  }

  /// Bottom nav "in vetro": tint traslucido + blur del gradiente + bordo glass.
  /// Icone SVG line-art ([NatureIcon]); quella attiva ha il bagliore neon in dark.
  Widget _buildGlassNav(BuildContext context, int index, bool isNarrow) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = theme.extension<GlassTokens>()!;

    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.navTint,
        border: Border(top: BorderSide(color: tokens.borderColor, width: 1)),
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
                icon: NatureIcon(t.asset, color: cs.onSurfaceVariant),
                selectedIcon: NatureIcon(
                  t.asset,
                  color: cs.primary,
                  glow: true,
                ),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );

    if (tokens.useRealBlur) {
      bar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: tokens.blurSigma,
            sigmaY: tokens.blurSigma,
          ),
          child: bar,
        ),
      );
    }
    return bar;
  }
}
