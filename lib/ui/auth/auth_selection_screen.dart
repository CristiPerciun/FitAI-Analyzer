import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/strava_sync_status_notifier.dart';
import 'package:fitai_analyzer/routes/app_router.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthSelectionScreen extends ConsumerWidget {
  const AuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('FitAI Analyzer'),
        leading: const Icon(Icons.fitness_center, size: 28),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            tooltip: 'Disconnetti Strava',
            onPressed: () async {
              await ref.read(stravaServiceProvider).clearTokens();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Strava disconnesso. Ricollega per sincronizzare.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        _buildServiceCard(
                          context: context,
                          title: 'Alimentazione',
                          loadingMessage: null,
                          subtitle: 'Registra i tuoi pasti (foto piatto con Gemini)',
                          icon: Icons.restaurant,
                          color: const Color(0xFF2E7D32),
                          width: cardWidth,
                          onTap: () {
                            if (context.mounted) context.go('/alimentazione');
                          },
                          isLoading: false,
                        ),
                        const SizedBox(height: 24),
                        _buildServiceCard(
                          context: context,
                          title: 'Strava',
                          subtitle: 'Allenamenti e attività',
                          icon: Icons.directions_bike,
                          color: const Color(0xFFFC4C02),
                          width: cardWidth,
                          onTap: () {
                            ref.read(authNotifierProvider.notifier).startOAuth(
                                  'strava',
                                  onSuccess: () {
                                    ref.read(appRouterProvider).go('/dashboard');
                                  },
                                );
                          },
                          isLoading: authState.isLoading &&
                              authState.currentService == 'strava',
                          loadingMessage: authState.isLoading &&
                                  authState.currentService == 'strava'
                              ? ref.watch(stravaSyncStatusProvider).message
                              : null,
                        ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Center(
              child: Text(
                'I tuoi dati restano privati e al sicuro',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
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
    String? loadingMessage,
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
                  isLoading && loadingMessage != null
                      ? loadingMessage
                      : subtitle,
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
