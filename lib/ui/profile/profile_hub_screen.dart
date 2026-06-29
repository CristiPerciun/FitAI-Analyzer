import 'package:fitai_analyzer/ui/profile/account_credentials_screen.dart';
import 'package:fitai_analyzer/ui/profile/combined_onboarding_edit_screen.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:flutter/material.dart';

/// Punto di ingresso da Impostazioni → Profilo: accesso ai dati login e modifica onboarding.
class ProfileHubScreen extends StatelessWidget {
  const ProfileHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 4),
          Text(
            'Gestisci account e questionari di onboarding.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FitSoftCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.lock_outline,
                  title: 'Dati di accesso',
                  subtitle: 'Email e password',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountCredentialsScreen(),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 72,
                  endIndent: 14,
                  color: theme.colorScheme.outline.withValues(alpha: 0.12),
                ),
                _ProfileRow(
                  icon: Icons.edit_note,
                  title: 'Modifica onboarding',
                  subtitle: 'Profilo e obiettivo mangiare, una sola pagina',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const CombinedOnboardingEditScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              FitIconBadge(icon: icon, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
