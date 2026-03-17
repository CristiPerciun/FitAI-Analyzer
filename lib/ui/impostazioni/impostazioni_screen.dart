import 'package:fitai_analyzer/app.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:fitai_analyzer/providers/garmin_sync_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/services/garmin_service.dart';
import 'package:fitai_analyzer/providers/strava_sync_status_notifier.dart';
import 'package:fitai_analyzer/providers/theme_mode_provider.dart';
import 'package:fitai_analyzer/services/strava_service.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/garmin_connect_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Schermata Impostazioni: Strava, chiave Gemini, logout.
class ImpostazioniScreen extends ConsumerWidget {
  const ImpostazioniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final stravaAsync = ref.watch(stravaConnectedProvider);
    final garminAsync = ref.watch(garminConnectedProvider);
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
    final isStravaConnected = stravaAsync.valueOrNull ?? false;
    final isGarminConnected = garminAsync.valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _ProfileTile(userName: authState.user?.email ?? 'Utente'),
          const Divider(height: 24),
          _SettingsTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.stravaOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_bike,
                color: AppColors.stravaOrange,
                size: 24,
              ),
            ),
            title: isStravaConnected ? 'Strava connesso' : 'Connect Strava',
            subtitle: isStravaLoading
                ? (syncStatus.message ?? 'Connessione...')
                : (isStravaConnected
                      ? 'Tocca per sincronizzare'
                      : 'Collega account Strava'),
            enabled: !isStravaLoading,
            onTap: () => _onConnectStrava(context, ref),
          ),
          if (isStravaConnected)
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
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.garminBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.watch, color: AppColors.garminBlue, size: 24),
            ),
            title: isGarminConnected
                ? 'Garmin Connect collegato'
                : 'Connect Garmin',
            subtitle: isGarminConnected
                ? 'Account collegato. Sync automatica dal server.'
                : 'Collega account Garmin Connect',
            onTap: () => _onConnectGarmin(context, ref),
          ),
          if (isGarminConnected)
            _SettingsTile(
              leading: Icon(
                Icons.link_off,
                color: Theme.of(context).colorScheme.outline,
                size: 24,
              ),
              title: 'Disconnetti Garmin',
              subtitle: 'Scollega account e chiudi sessione sul server',
              onTap: () => _onDisconnectGarmin(context, ref),
            ),
          const Divider(height: 24),
          _ThemeModeTile(),
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
            onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }

  Future<void> _onConnectStrava(BuildContext context, WidgetRef ref) async {
    await ref
        .read(authNotifierProvider.notifier)
        .startOAuth(
          'strava',
          onSuccess: () {
            ref.invalidate(activitiesStreamProvider);
            ref.read(selectedTabIndexProvider.notifier).state =
                1; // Allenamenti
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

  Future<void> _onConnectGarmin(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) {
      if (context.mounted) {
        showErrorDialog(context, 'Utente non autenticato.');
      }
      return;
    }
    final result = await showGarminConnectDialog(context, ref, uid: uid);
    if (result == true && context.mounted) {
      ref.invalidate(garminConnectedProvider);
      ref.invalidate(activitiesStreamProvider);
      ref.invalidate(dailyHealthStreamProvider);
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('✅ Garmin collegato!')),
      );
      // Sync vitals anche al login (attivita + biometrici oggi/ieri)
      await ref.read(garminSyncNotifierProvider.notifier).syncNow(
            uid: uid,
            trigger: 'garmin_login',
          );
      if (context.mounted) {
        ref.invalidate(activitiesStreamProvider);
        ref.invalidate(dailyHealthStreamProvider);
        ref.invalidate(activitiesByDateProvider);
      }
    }
  }

  Future<void> _onDisconnectGarmin(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnetti Garmin'),
        content: const Text(
          'Vuoi scollegare l\'account Garmin? I token verranno eliminati dal server e la sessione chiusa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Scollega'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(garminServiceProvider).disconnect(uid: uid);
    if (context.mounted) {
      ref.invalidate(garminConnectedProvider);
      ref.invalidate(activitiesStreamProvider);
      ref.invalidate(dailyHealthStreamProvider);
      ref.invalidate(activitiesByDateProvider);
      ref.invalidate(longevityHomePackageProvider);
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true
                ? '✅ Garmin scollegato.'
                : '❌ ${result['message']}',
          ),
          backgroundColor: result['success'] == true
              ? null
              : Theme.of(context).colorScheme.error,
        ),
      );
    }
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          size: 24,
        ),
      ),
      title: const Text(
        'Profilo',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        userName,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  static String _label(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Chiaro';
      case ThemeMode.dark:
        return 'Scuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return ListTile(
      leading: Icon(
        themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
        color: Theme.of(context).colorScheme.primary,
        size: 24,
      ),
      title: const Text('Tema', style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        _label(themeMode),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      trailing: PopupMenuButton<ThemeMode>(
        icon: const Icon(Icons.arrow_drop_down),
        onSelected: (mode) => notifier.setThemeMode(mode),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: ThemeMode.light,
            child: Text(_label(ThemeMode.light)),
          ),
          PopupMenuItem(
            value: ThemeMode.dark,
            child: Text(_label(ThemeMode.dark)),
          ),
          PopupMenuItem(
            value: ThemeMode.system,
            child: Text(_label(ThemeMode.system)),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
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
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
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
