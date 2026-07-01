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
import 'package:fitai_analyzer/utils/ios_pwa_chrome.dart';
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
    // iOS PWA: la shell (e la bottom bar) monta dopo il login, spesso oltre la
    // finestra di nudge del boot. Ripetiamo il nudge appena la barra è visibile
    // così i suoi tap funzionano al lancio senza dover ruotare il device.
    WidgetsBinding.instance.addPostFrameCallback((_) => nudgeIosPwaViewport());
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
      // Il corpo si estende DIETRO la bottom bar: la pagina resta visibile
      // attorno/attraverso la barra in vetro flottante.
      extendBody: true,
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

  /// Bottom nav: **un'unica barra** in vetro flottante (glassmorphism marcato):
  /// leggermente trasparente + blur forte → la pagina sottostante resta visibile
  /// attorno e attraverso la barra. Estrusione soft (ombra neumorfica). La
  /// selezione ILLUMINA solo l'icona attiva, senza effetto-pulsante sul tab.
  Widget _buildGlassNav(BuildContext context, int index, bool isNarrow) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = theme.extension<GlassTokens>()!;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final radius = BorderRadius.circular(26);
    // blur marcato (più forte del blur standard delle card)
    final blurSigma = isDark ? 24.0 : 20.0;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // superficie TRANSLUCIDA (leggermente trasparente) con sheen soft:
        // la pagina dietro traspare, sfumata dal blur.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0x9E2E2E33), Color(0x85202024)]
              : const [Color(0xB3FFFFFF), Color(0x99FFFFFF)],
        ),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0xB3FFFFFF),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavTab(
                  asset: _tabs[i].asset,
                  label: _tabs[i].label,
                  selected: i == index,
                  showLabel: !isNarrow,
                  onTap: () =>
                      ref.read(selectedTabIndexProvider.notifier).state = i,
                ),
              ),
          ],
        ),
      ),
    );

    // Vetro smerigliato marcato: sfuma ciò che sta dietro la barra.
    surface = ClipRRect(
      borderRadius: radius,
      child: tokens.useRealBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: surface,
            )
          : surface,
    );

    // Barra flottante: margini attorno → la pagina si vede intorno alla barra;
    // l'ombra neumorfica sta fuori dal clip (estrusione soft).
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: tokens.softShadow,
          ),
          child: surface,
        ),
      ),
    );
  }
}

/// Tab dentro l'unica barra: nessun chrome/effetto-pulsante. Solo l'icona (e
/// l'etichetta): quando è selezionata si ILLUMINA (accento di tema + glow che
/// segue il tratto, visibile anche in tema chiaro).
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.asset,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = cs.primary;
    final iconColor = selected ? accent : cs.onSurfaceVariant;
    final labelColor = selected ? accent : cs.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: showLabel ? 6 : 10,
            horizontal: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NatureIcon(
                asset,
                color: iconColor,
                size: 24,
                glow: selected,
                glowColor: selected ? accent : null,
              ),
              if (showLabel) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: labelColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
