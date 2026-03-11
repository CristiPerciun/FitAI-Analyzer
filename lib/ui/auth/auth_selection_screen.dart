import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/health_sync_status_notifier.dart';
import 'package:fitai_analyzer/ui/auth/health_sync_status_card.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/utils/demo_fitness_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthSelectionScreen extends ConsumerWidget {
  const AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final healthSyncStatus = ref.watch(healthSyncStatusProvider);
    final showHealthSyncCard = authState.currentService == 'health' ||
        healthSyncStatus.phase == HealthSyncPhase.error;

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    ref.listen(healthSyncStatusProvider, (prev, next) {
      if (next.phase == HealthSyncPhase.error &&
          next.error != null &&
          prev?.phase != HealthSyncPhase.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitAI Analyzer'),
        leading: const Icon(Icons.fitness_center, size: 28),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Connetti i tuoi dati',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scegli la piattaforma per iniziare',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF37474F).withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth > 600
                      ? constraints.maxWidth * 0.45
                      : constraints.maxWidth * 0.85;

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildServiceCard(
                          context: context,
                          title: 'Garmin Connect',
                          subtitle: 'Passi, sonno, allenamenti, HR',
                          icon: Icons.watch_outlined,
                          color: const Color(0xFF37474F),
                          width: cardWidth,
                          onTap: () => ref
                              .read(authNotifierProvider.notifier)
                              .startOAuth('garmin'),
                          isLoading: authState.isLoading &&
                              authState.currentService == 'garmin',
                        ),
                        const SizedBox(height: 24),
                        _buildServiceCard(
                          context: context,
                          title: 'Apple Health',
                          subtitle:
                              'Passi • Sonno • Calorie • Attività (da Salute iOS)',
                          icon: Icons.favorite,
                          color: const Color(0xFFE53935),
                          width: cardWidth,
                          onTap: () async {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .startOAuth('health', onSuccess: () {
                              if (context.mounted) {
                                context.go(
                                    kUseDemoData ? '/dashboard' : '/onboarding');
                              }
                            });
                          },
                          isLoading: authState.isLoading &&
                              authState.currentService == 'health',
                        ),
                        if (showHealthSyncCard) ...[
                          const SizedBox(height: 16),
                          const HealthSyncStatusCard(),
                        ],
                        const SizedBox(height: 24),
                        _buildServiceCard(
                          context: context,
                          title: 'Modalità demo',
                          subtitle:
                              'Simula Apple Health (sviluppo su Windows)',
                          icon: Icons.science_outlined,
                          color: const Color(0xFF6B7280),
                          width: cardWidth,
                          onTap: () async {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .startDemoHealth(onSuccess: () {
                              if (context.mounted) {
                                context.go(
                                    kUseDemoData ? '/dashboard' : '/onboarding');
                              }
                            });
                          },
                          isLoading: authState.isLoading &&
                              authState.currentService == 'demo',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Text(
              'I tuoi dati restano privati e al sicuro',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Icon(icon, size: 48, color: color),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
