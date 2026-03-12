import 'dart:convert';

import 'package:fitai_analyzer/providers/health_sync_status_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Card che mostra le fasi del sync Health per debug su iPhone.
class HealthSyncStatusCard extends ConsumerWidget {
  const HealthSyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(healthSyncStatusProvider);

    if (status.phase == HealthSyncPhase.idle) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sync Health - Debug',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PhaseRow(
              phase: HealthSyncPhase.configuring,
              current: status.phase,
              label: '0. Configurazione plugin',
            ),
            _PhaseRow(
              phase: HealthSyncPhase.requestingPermissions,
              current: status.phase,
              label: '1. Richiesta permessi',
            ),
            _PhaseRow(
              phase: HealthSyncPhase.permissionsResult,
              current: status.phase,
              label: '2. Risposta permessi',
              detail: status.phase == HealthSyncPhase.permissionsResult
                  ? status.rawResponse?.toString()
                  : null,
            ),
            _PhaseRow(
              phase: HealthSyncPhase.fetchingData,
              current: status.phase,
              label: '3. Chiamata getHealthDataFromTypes',
            ),
            _PhaseRow(
              phase: HealthSyncPhase.dataReceived,
              current: status.phase,
              label: '4. Risposta raw (non processata)',
              detail: status.phase == HealthSyncPhase.dataReceived &&
                      status.rawResponse != null
                  ? _formatRawResponse(status.rawResponse)
                  : null,
            ),
            _PhaseRow(
              phase: HealthSyncPhase.savingToFirestore,
              current: status.phase,
              label: '5. Salvataggio Firestore',
            ),
            _PhaseRow(
              phase: HealthSyncPhase.complete,
              current: status.phase,
              label: '6. Completato',
            ),
            if (status.phase == HealthSyncPhase.error) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: SelectableText(
                    status.error ?? 'Errore',
                    style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatRawResponse(Object? raw) {
    if (raw == null) return '';
    try {
      if (raw is List) {
        return const JsonEncoder.withIndent('  ').convert(
          raw.map((e) => e is Map ? e : e.toString()).toList(),
        );
      }
      return raw.toString();
    } catch (_) {
      return raw.toString();
    }
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.phase,
    required this.current,
    required this.label,
    this.detail,
  });

  final HealthSyncPhase phase;
  final HealthSyncPhase current;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final isActive = current == phase;
    final isPast = _phaseIndex(current) > _phaseIndex(phase);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPast
                    ? Icons.check_circle
                    : isActive
                        ? Icons.hourglass_empty
                        : Icons.radio_button_unchecked,
                size: 16,
                color: isPast
                    ? Colors.green
                    : isActive
                        ? Colors.orange
                        : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? Colors.blue.shade900 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(left: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: SelectableText(
                  detail!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _phaseIndex(HealthSyncPhase p) {
    const order = [
      HealthSyncPhase.configuring,
      HealthSyncPhase.requestingPermissions,
      HealthSyncPhase.permissionsResult,
      HealthSyncPhase.fetchingData,
      HealthSyncPhase.dataReceived,
      HealthSyncPhase.savingToFirestore,
      HealthSyncPhase.complete,
    ];
    final i = order.indexOf(p);
    return i >= 0 ? i : -1;
  }
}
