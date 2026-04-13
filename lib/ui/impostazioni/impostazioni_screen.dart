import 'dart:async';

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
import 'package:fitai_analyzer/services/ai_backend_preference_service.dart';
import 'package:fitai_analyzer/services/gemini_api_key_service.dart';
import 'package:fitai_analyzer/services/openrouter_service.dart';
import 'package:fitai_analyzer/services/user_ai_settings_sync_service.dart';
import 'package:fitai_analyzer/ui/widgets/deepseek_api_key_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/gemini_api_key_dialog.dart';
import 'package:fitai_analyzer/ui/widgets/openrouter_api_key_dialog.dart';
import 'package:fitai_analyzer/ui/profile/profile_hub_screen.dart';
import 'package:fitai_analyzer/ui/widgets/garmin_connect_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<AiBackend?> _pickFallbackAiBackend({
  required AiBackend exclude,
  required AiBackendPreferenceService prefs,
  required GeminiApiKeyService gemini,
}) async {
  for (final b in AiBackend.values) {
    if (b == exclude) continue;
    switch (b) {
      case AiBackend.gemini:
        if (await gemini.hasValidKey()) return b;
      case AiBackend.deepseek:
        if (await prefs.hasValidDeepSeekKey()) return b;
      case AiBackend.openrouter:
        if (await prefs.hasValidOpenRouterKey()) return b;
    }
  }
  return null;
}

Future<void> _applyAiBackend(WidgetRef ref, AiBackend backend) async {
  final prefs = ref.read(aiBackendPreferenceServiceProvider);
  await prefs.setBackend(backend);
  final uid = ref.read(authNotifierProvider).user?.uid;
  if (uid != null) {
    await ref
        .read(userAiSettingsSyncServiceProvider)
        .pushActiveBackend(uid, backend);
  }
  invalidateAiRouting(ref);
}

void _showAiBackendFallbackSnack() {
  scaffoldMessengerKey.currentState?.showSnackBar(
    const SnackBar(
      content: Text(
        'Configura la chiave di un altro backend prima di disattivare questo.',
      ),
    ),
  );
}

/// Impostazioni in stile gruppi iOS: integrazioni con switch, senza pulsante Sync dedicato.
class ImpostazioniScreen extends ConsumerWidget {
  const ImpostazioniScreen({super.key});

  static const Color _iosSwitchOn = Color(0xFF34C759);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final aiBackendAsync = ref.watch(aiBackendSettingsProvider);
    final stravaAsync = ref.watch(stravaConnectedProvider);
    final garminAsync = ref.watch(garminConnectedProvider);
    final syncStatus = ref.watch(stravaSyncStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenBg = theme.scaffoldBackgroundColor;
    final groupBg = theme.colorScheme.surfaceContainerHighest;
    final headerColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    final footerColor = theme.colorScheme.onSurfaceVariant;

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
      backgroundColor: screenBg,
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _IosSectionHeader(label: 'PROFILO', color: headerColor),
          _IosGroup(
            color: groupBg,
            isDark: isDark,
            child: _IosNavigationRow(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              title: 'Profilo',
              subtitle: authState.user?.email ?? 'Utente',
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileHubScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _IosSectionHeader(label: 'INTEGRAZIONI', color: headerColor),
          _IosGroup(
            color: groupBg,
            isDark: isDark,
            children: [
              _IosSwitchRow(
                leading: Container(
                  width: 29,
                  height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.stravaOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    Icons.directions_bike,
                    color: AppColors.stravaOrange,
                    size: 20,
                  ),
                ),
                title: 'Strava',
                value: isStravaConnected,
                activeColor: _iosSwitchOn,
                onChanged: isStravaLoading
                    ? null
                    : (v) => unawaited(
                        _onStravaSwitchChanged(context, ref, v),
                      ),
              ),
              _IosRowDivider(indent: _IosGroup.rowLabelInset),
              _IosSwitchRow(
                leading: Container(
                  width: 29,
                  height: 29,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.garminBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child:
                      Icon(Icons.watch, color: AppColors.garminBlue, size: 20),
                ),
                title: 'Garmin Connect',
                value: isGarminConnected,
                activeColor: _iosSwitchOn,
                onChanged: (v) =>
                    unawaited(_onGarminSwitchChanged(context, ref, v)),
              ),
            ],
          ),
          if (isStravaLoading && (syncStatus.message?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, right: 4),
              child: Text(
                syncStatus.message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: footerColor,
                  fontSize: 13,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, right: 4),
              child: Text(
                'Attiva Strava o Garmin per sincronizzare attività e dati. '
                'La prima sincronizzazione parte automaticamente dopo il collegamento.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: footerColor,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 20),
          _IosSectionHeader(label: 'APP', color: headerColor),
          _IosGroup(
            color: groupBg,
            isDark: isDark,
            child: const _ThemeModeIosRow(),
          ),
          const SizedBox(height: 10),
          _IosSectionHeader(label: 'INTELLIGENZA ARTIFICIALE', color: headerColor),
          aiBackendAsync.when(
            data: (snap) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IosGroup(
                  color: groupBg,
                  isDark: isDark,
                  children: [
                    _IosAiBackendSwitchRow(
                      leading: Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      title: 'Gemini',
                      subtitle: snap.hasGeminiKey
                          ? 'Sincronizzata tra i dispositivi (stesso account)'
                          : 'Chiave non impostata · attiva per inserirla',
                      value: snap.backend == AiBackend.gemini,
                      activeColor: _iosSwitchOn,
                      onChanged: (v) => unawaited(
                        _onGeminiBackendSwitch(context, ref, v),
                      ),
                    ),
                    _IosRowDivider(indent: _IosGroup.rowLabelInset),
                    _IosAiBackendSwitchRow(
                      leading: Icon(
                        Icons.psychology_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      title: 'DeepSeek',
                      subtitle: snap.hasDeepSeekKey
                          ? 'Sincronizzata tra i dispositivi (stesso account)'
                          : 'Chiave non impostata · attiva per inserirla',
                      value: snap.backend == AiBackend.deepseek,
                      activeColor: _iosSwitchOn,
                      onChanged: (v) => unawaited(
                        _onDeepSeekBackendSwitch(context, ref, v),
                      ),
                    ),
                    _IosRowDivider(indent: _IosGroup.rowLabelInset),
                    _IosAiBackendSwitchRow(
                      leading: Icon(
                        Icons.public_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      title: 'OpenRouter (Gemma 4 IT free)',
                      subtitle: snap.hasOpenRouterKey
                          ? 'Sincronizzata tra i dispositivi (stesso account)'
                          : 'Chiave non impostata · attiva per inserirla',
                      value: snap.backend == AiBackend.openrouter,
                      activeColor: _iosSwitchOn,
                      onChanged: (v) => unawaited(
                        _onOpenRouterBackendSwitch(context, ref, v),
                      ),
                    ),
                  ],
                ),
                if (snap.backend == AiBackend.openrouter) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.info_outline, size: 20),
                    label: const Text('Info crediti OpenRouter'),
                    onPressed: () => unawaited(
                      _showOpenRouterCreditsDialog(context, ref),
                    ),
                  ),
                ],
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, right: 4),
            child: Text(
              'Un solo backend attivo (Home, foto pasti, piani). '
              'Chiavi e scelta (Gemini, DeepSeek, OpenRouter) sono salvate su Firebase per lo stesso account: '
              'attiva lo switch per inserire la chiave; sull’altro dispositivo effettua l’accesso o riapri l’app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: footerColor,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _IosGroup(
            color: groupBg,
            isDark: isDark,
            child: _IosDestructiveRow(
              title: 'Esci',
              onTap: () =>
                  ref.read(authNotifierProvider.notifier).signOut(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onStravaSwitchChanged(
    BuildContext context,
    WidgetRef ref,
    bool turnOn,
  ) async {
    if (turnOn) {
      final connected = ref.read(stravaConnectedProvider).valueOrNull ?? false;
      if (connected) return;

      await ref.read(authNotifierProvider.notifier).startOAuth(
        'strava',
        onSuccess: () {
          ref.invalidate(activitiesStreamProvider);
          ref.read(selectedTabIndexProvider.notifier).state = 1;
          final uid = ref.read(authNotifierProvider).user?.uid;
          if (uid != null) {
            unawaited(_runStravaPostLoginSync(context, ref, uid));
          }
        },
      );
      return;
    }

    final connected = ref.read(stravaConnectedProvider).valueOrNull ?? false;
    if (!connected) return;

    final ok = await _showCupertinoConfirm(
      context,
      title: 'Disconnetti Strava?',
      message:
          'L’account Strava non sarà più usato da questa app finché non lo ricolleghi.',
      confirmLabel: 'Disconnetti',
      isDestructive: true,
    );
    if (ok == true && context.mounted) {
      await _onDisconnectStrava(context, ref);
    }
  }

  Future<void> _onGarminSwitchChanged(
    BuildContext context,
    WidgetRef ref,
    bool turnOn,
  ) async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) {
      if (context.mounted) {
        showErrorDialog(context, 'Utente non autenticato.');
      }
      return;
    }

    if (turnOn) {
      final already =
          ref.read(garminConnectedProvider).valueOrNull ?? false;
      if (already) return;

      final result = await showGarminConnectDialog(context, ref, uid: uid);
      if (result == true && context.mounted) {
        ref.invalidate(garminConnectedProvider);
        ref.invalidate(activitiesStreamProvider);
        ref.invalidate(dailyHealthStreamProvider);
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('✅ Garmin collegato!')),
        );
        await _runGarminPostLoginSync(context, ref, uid);
      }
      return;
    }

    final connected =
        ref.read(garminConnectedProvider).valueOrNull ?? false;
    if (!connected) return;

    final ok = await _showCupertinoConfirm(
      context,
      title: 'Disconnetti Garmin?',
      message:
          'L’integrazione Garmin verrà rimossa per questo account. '
          'Potrai riconnetterti in qualsiasi momento.',
      confirmLabel: 'Disconnetti',
      isDestructive: true,
    );
    if (ok == true && context.mounted) {
      await _performGarminDisconnect(context, ref, uid);
    }
  }

  Future<void> _onDisconnectStrava(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid != null) {
      await ref.read(garminServiceProvider).disconnectStravaOnServer(uid: uid);
    }
    await ref.read(stravaServiceProvider).clearTokens();
    ref.invalidate(stravaConnectedProvider);
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Strava disconnesso. Ricollega per sincronizzare.'),
      ),
    );
  }

  Future<void> _performGarminDisconnect(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
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

  Future<void> _runStravaPostLoginSync(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final ok = await ref
        .read(garminSyncNotifierProvider.notifier)
        .syncNow(uid: uid, trigger: 'settings_strava_post_login');
    ref.invalidate(activitiesStreamProvider);
    ref.invalidate(activitiesByDateProvider);
    if (!context.mounted) return;
    final messenger = scaffoldMessengerKey.currentState;
    if (ok) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Strava: dati aggiornati dal server.'),
        ),
      );
    } else {
      final err = ref.read(garminSyncNotifierProvider).error ??
          'Sincronizzazione non riuscita.';
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Strava: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _runGarminPostLoginSync(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final service = ref.read(garminServiceProvider);
    var result = await service.syncToday(uid: uid);
    if (result['success'] != true) {
      await Future<void>.delayed(const Duration(seconds: 2));
      result = await service.syncToday(uid: uid);
    }

    ref.invalidate(garminConnectedProvider);
    ref.invalidate(activitiesStreamProvider);
    ref.invalidate(dailyHealthStreamProvider);
    ref.invalidate(activitiesByDateProvider);
    ref.invalidate(longevityHomePackageProvider);

    if (!context.mounted) return;
    if (result['success'] == true) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Garmin: dati biometrici e attività aggiornati.'),
        ),
      );
    } else {
      final msg = result['message']?.toString() ?? 'Sync Garmin non riuscita.';
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Garmin sync: $msg'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _onGeminiBackendSwitch(
    BuildContext context,
    WidgetRef ref,
    bool turnOn,
  ) async {
    final prefs = ref.read(aiBackendPreferenceServiceProvider);
    final geminiKeys = ref.read(geminiApiKeyServiceProvider);

    if (turnOn) {
      if (!await geminiKeys.hasValidKey()) {
        if (!context.mounted) return;
        final saved = await showGeminiApiKeyDialog(context, ref);
        if (!saved || !await geminiKeys.hasValidKey()) {
          ref.invalidate(aiBackendSettingsProvider);
          return;
        }
      }
      await _applyAiBackend(ref, AiBackend.gemini);
      return;
    }

    final next = await _pickFallbackAiBackend(
      exclude: AiBackend.gemini,
      prefs: prefs,
      gemini: geminiKeys,
    );
    if (next == null) {
      _showAiBackendFallbackSnack();
      return;
    }
    await _applyAiBackend(ref, next);
  }

  Future<void> _onDeepSeekBackendSwitch(
    BuildContext context,
    WidgetRef ref,
    bool turnOn,
  ) async {
    final prefs = ref.read(aiBackendPreferenceServiceProvider);
    final geminiKeys = ref.read(geminiApiKeyServiceProvider);

    if (turnOn) {
      if (!await prefs.hasValidDeepSeekKey()) {
        if (!context.mounted) return;
        final saved = await showDeepSeekApiKeyDialog(context, ref);
        if (!saved || !await prefs.hasValidDeepSeekKey()) {
          ref.invalidate(aiBackendSettingsProvider);
          return;
        }
      }
      await _applyAiBackend(ref, AiBackend.deepseek);
      return;
    }

    final next = await _pickFallbackAiBackend(
      exclude: AiBackend.deepseek,
      prefs: prefs,
      gemini: geminiKeys,
    );
    if (next == null) {
      _showAiBackendFallbackSnack();
      return;
    }
    await _applyAiBackend(ref, next);
  }

  Future<void> _onOpenRouterBackendSwitch(
    BuildContext context,
    WidgetRef ref,
    bool turnOn,
  ) async {
    final prefs = ref.read(aiBackendPreferenceServiceProvider);
    final geminiKeys = ref.read(geminiApiKeyServiceProvider);

    if (turnOn) {
      if (!await prefs.hasValidOpenRouterKey()) {
        if (!context.mounted) return;
        final saved = await showOpenRouterApiKeyDialog(context, ref);
        if (!saved || !await prefs.hasValidOpenRouterKey()) {
          ref.invalidate(aiBackendSettingsProvider);
          return;
        }
      }
      await _applyAiBackend(ref, AiBackend.openrouter);
      return;
    }

    final next = await _pickFallbackAiBackend(
      exclude: AiBackend.openrouter,
      prefs: prefs,
      gemini: geminiKeys,
    );
    if (next == null) {
      _showAiBackendFallbackSnack();
      return;
    }
    await _applyAiBackend(ref, next);
  }

  Future<void> _showOpenRouterCreditsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Senza await: altrimenti si attende il pop prima di fetchKeyCredits → loader infinito.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Recupero stato chiave OpenRouter…',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );

    late final OpenRouterKeyCreditsResult result;
    try {
      result = await ref.read(openRouterServiceProvider).fetchKeyCredits();
    } finally {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OpenRouter · crediti'),
        content: SingleChildScrollView(
          child: result.isSuccess
              ? _openRouterCreditsBody(result.data!)
              : Text(
                  result.errorMessage ?? 'Errore sconosciuto',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _openRouterCreditsBody(OpenRouterKeyCredits c) {
    String fmtUsd(double? v, {required String ifNull}) {
      if (v == null) return ifNull;
      return '${v.toStringAsFixed(2)} USD';
    }

    final buf = StringBuffer()
      ..writeln(
        'OpenRouter non espone un numero fisso di “chiamate”: il saldo è in '
        'dollari (USD). Ogni richiesta consuma in base ai token e al modello '
        'effettivamente usato.',
      )
      ..writeln()
      ..writeln(
        'In questa app la catena di fallback può provare circa 5 modelli '
        'diversi se uno fallisce o va in rate limit; una sola azione utente '
        'può quindi generare più richieste.',
      )
      ..writeln();

    if (c.label != null && c.label!.trim().isNotEmpty) {
      buf.writeln('Etichetta chiave: ${c.label}');
    }
    if (c.isFreeTier != null) {
      buf.writeln('Free tier: ${c.isFreeTier! ? "sì" : "no"}');
    }
    buf
      ..writeln(
        'Limite chiave: ${fmtUsd(c.limitUsd, ifNull: "non indicato (spesso illimitato)")}',
      )
      ..writeln(
        'Credito residuo: ${fmtUsd(c.limitRemainingUsd, ifNull: "non applicabile o illimitato")}',
      )
      ..writeln(
        'Utilizzo totale (storico): ${fmtUsd(c.usageUsd, ifNull: "0,00 USD")}',
      );

    if (c.limitRemainingUsd != null && c.limitRemainingUsd! <= 0) {
      buf.writeln();
      buf.writeln('Attenzione: credito residuo pari o inferiore a zero.');
    }

    return Text(buf.toString());
  }

  Future<bool?> _showCupertinoConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message, textAlign: TextAlign.center),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

/// Allineamento etichetta dopo icona (padding 16 + 29 + 12 ≈ 57).
class _IosGroup extends StatelessWidget {
  const _IosGroup({
    required this.color,
    required this.isDark,
    this.child,
    this.children,
  }) : assert(
          (child != null) ^ (children != null),
          'Provide either child or children',
        );

  static const double rowLabelInset = 57;

  final Color color;
  final bool isDark;
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final content = child ??
        Column(mainAxisSize: MainAxisSize.min, children: children!);

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: isDark
            ? null
            : Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class _IosSectionHeader extends StatelessWidget {
  const _IosSectionHeader({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.08,
          color: color,
        ),
      ),
    );
  }
}

class _IosRowDivider extends StatelessWidget {
  const _IosRowDivider({this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).dividerColor.withValues(alpha: 0.35);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(height: 0.5, color: line),
    );
  }
}

class _IosAiBackendSwitchRow extends StatelessWidget {
  const _IosAiBackendSwitchRow({
    required this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor = ImpostazioniScreen._iosSwitchOn,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 29, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: activeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosSwitchRow extends StatelessWidget {
  const _IosSwitchRow({
    required this.leading,
    required this.title,
    required this.value,
    required this.onChanged,
    this.activeColor = ImpostazioniScreen._iosSwitchOn,
  });

  final Widget leading;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onChanged == null
            ? null
            : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 17,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: activeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IosNavigationRow extends StatelessWidget {
  const _IosNavigationRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chevron = Icon(
      Icons.chevron_right,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      size: 22,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              leading is CircleAvatar
                  ? leading
                  : SizedBox(width: 29, child: Center(child: leading)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              chevron,
            ],
          ),
        ),
      ),
    );
  }
}

class _IosDestructiveRow extends StatelessWidget {
  const _IosDestructiveRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: red,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeModeIosRow extends ConsumerWidget {
  const _ThemeModeIosRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final label = _ThemeModeIosRow._label(themeMode);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final chosen = await showCupertinoModalPopup<ThemeMode>(
            context: context,
            builder: (ctx) => CupertinoActionSheet(
              title: const Text('Tema'),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(ctx, ThemeMode.light),
                  child: const Text('Chiaro'),
                ),
                CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(ctx, ThemeMode.dark),
                  child: const Text('Scuro'),
                ),
                CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(ctx, ThemeMode.system),
                  child: const Text('Sistema'),
                ),
              ],
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
            ),
          );
          if (chosen != null) {
            notifier.setThemeMode(chosen);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 29,
                child: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tema',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 17,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
}
