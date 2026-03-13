import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/strava_sync_status_notifier.dart';
import 'package:fitai_analyzer/routes/app_router.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Colore Strava ufficiale
const _stravaOrange = Color(0xFFFC4C02);

/// Menu hamburger minimal elegante con opzioni di autenticazione.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    this.showLogout = false,
    this.onClose,
  });

  final bool showLogout;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final stravaAsync = ref.watch(stravaConnectedProvider);
    final syncStatus = ref.watch(stravaSyncStatusProvider);

    ref.listen(authNotifierProvider, (prev, next) {
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error &&
          context.mounted) {
        showErrorDialog(context, next.error!);
      }
    });

    final isStravaLoading =
        authState.isLoading && authState.currentService == 'strava';
    final isConnected = stravaAsync.valueOrNull ?? false;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'FitAI Analyzer',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _stravaOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.directions_bike,
                        color: _stravaOrange,
                        size: 24,
                      ),
                    ),
                    title: isConnected ? 'Strava connesso' : 'Connect Strava',
                    subtitle: isStravaLoading
                        ? (syncStatus.message ?? 'Connessione...')
                        : (isConnected ? 'Collegato' : 'Collega account Strava'),
                    enabled: !isStravaLoading,
                    onTap: isConnected
                        ? null
                        : () => _onConnectStrava(context, ref),
                  ),
                  if (isConnected)
                    _DrawerTile(
                      leading: Icon(
                        Icons.link_off,
                        color: Theme.of(context).colorScheme.outline,
                        size: 24,
                      ),
                      title: 'Disconnetti Strava',
                      subtitle: 'Scollega account',
                      onTap: () => _onDisconnectStrava(context, ref),
                    ),
                  const Divider(height: 24),
                  _DrawerTile(
                    leading: Icon(
                      Icons.key,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    title: 'Aggiungi chiave Gemini',
                    subtitle: 'API Key per analisi nutrizione',
                    onTap: () => _onAddGeminiKey(context, ref),
                  ),
                  if (showLogout) ...[
                    const Divider(height: 24),
                    _DrawerTile(
                      leading: Icon(
                        Icons.logout,
                        color: Theme.of(context).colorScheme.error,
                        size: 24,
                      ),
                      title: 'Esci',
                      subtitle: 'Disconnetti sessione',
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(authNotifierProvider.notifier).signOut();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onConnectStrava(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    onClose?.call();
    await ref.read(authNotifierProvider.notifier).startOAuth(
          'strava',
          onSuccess: () {
            ref.read(appRouterProvider).go('/dashboard');
          },
        );
  }

  Future<void> _onDisconnectStrava(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    onClose?.call();
    await ref.read(stravaServiceProvider).clearTokens();
    ref.invalidate(stravaConnectedProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strava disconnesso. Ricollega per sincronizzare.'),
        ),
      );
    }
  }

  Future<void> _onAddGeminiKey(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    onClose?.call();
    final saved = await showGeminiApiKeyDialog(context, ref);
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chiave Gemini salvata.'),
        ),
      );
    }
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.enabled = true,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            )
          : null,
      enabled: enabled,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
