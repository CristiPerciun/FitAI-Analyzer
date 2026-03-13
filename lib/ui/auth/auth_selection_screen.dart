import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/ui/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthSelectionScreen extends ConsumerWidget {
  const AuthSelectionScreen({super.key});

  void _onAllenamentiTap(BuildContext context, WidgetRef ref) async {
    final isConnected = await ref.read(stravaConnectedProvider.future);
    if (isConnected) {
      if (context.mounted) context.go('/dashboard');
    } else {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connetti Strava'),
          content: const Text(
            'Per vedere la dashboard con allenamenti e attività, connetti il tuo account Strava dal menu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Scaffold.of(context).openDrawer();
                  }
                });
              },
              child: const Text('Apri menu'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitAI Analyzer'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      drawer: const AppDrawer(showLogout: false),
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
                          title: 'Allenamenti e attività',
                          subtitle: 'Dashboard con dati Strava',
                          icon: Icons.directions_bike,
                          color: const Color(0xFFFC4C02),
                          width: cardWidth,
                          onTap: () => _onAllenamentiTap(context, ref),
                          isLoading: false,
                          loadingMessage: null,
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
