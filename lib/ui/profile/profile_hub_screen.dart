import 'package:fitai_analyzer/ui/profile/account_credentials_screen.dart';
import 'package:fitai_analyzer/ui/profile/combined_onboarding_edit_screen.dart';
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
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Gestisci account e questionari di onboarding.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.lock_outline,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Dati di accesso'),
                  subtitle: const Text('Email e password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountCredentialsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.edit_note,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Modifica onboarding'),
                  subtitle: const Text(
                    'Profilo e obiettivo mangiare, una sola pagina',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CombinedOnboardingEditScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
