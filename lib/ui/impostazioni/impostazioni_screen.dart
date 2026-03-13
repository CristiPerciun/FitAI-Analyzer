import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/strava_sync_status_notifier.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/ui/theme/app_colors.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Schermata Impostazioni: Strava, chiave Gemini, logout.
class ImpostazioniScreen extends ConsumerWidget {
  const ImpostazioniScreen({super.key});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.stravaOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.directions_bike,
                  color: AppColors.stravaOrange, size: 24),
            ),
            title: isConnected ? 'Strava connesso' : 'Connect Strava',
            subtitle: isStravaLoading
                ? (syncStatus.message ?? 'Connessione...')
                : (isConnected ? 'Tocca per sincronizzare' : 'Collega account Strava'),
            enabled: !isStravaLoading,
            onTap: () => _onConnectStrava(context, ref),
          ),
          if (isConnected)
            _SettingsTile(
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
          _SettingsTile(
            leading: Icon(
              Icons.key,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            title: 'Aggiungi chiave Gemini',
            subtitle: 'API Key per analisi nutrizione',
            onTap: () => _onAddGeminiKey(context, ref),
          ),
          const Divider(height: 24),
          _SettingsTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            title: 'Esci',
            subtitle: 'Disconnetti sessione',
            onTap: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }

  Future<void> _onConnectStrava(BuildContext context, WidgetRef ref) async {
    await ref.read(authNotifierProvider.notifier).startOAuth(
      'strava',
      onSuccess: () {
        ref.invalidate(healthDataStreamProvider);
        ref.read(selectedTabIndexProvider.notifier).state = 1; // Allenamenti
      },
    );
  }

  Future<void> _onDisconnectStrava(BuildContext context, WidgetRef ref) async {
    await ref.read(stravaServiceProvider).clearTokens();
    ref.invalidate(stravaConnectedProvider);
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Strava disconnesso. Ricollega per sincronizzare.'),
      ),
    );
  }

  Future<void> _onAddGeminiKey(BuildContext context, WidgetRef ref) async {
    final saved = await showGeminiApiKeyDialog(context, ref);
    if (saved) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Chiave Gemini salvata.')),
      );
    }
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
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
