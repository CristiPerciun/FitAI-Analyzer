import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/theme/app_card_theme.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fitai_analyzer/ui/widgets/error_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modifica email (con verifica Firebase) e/o password.
///
/// Redesign: header "hero" charcoal con stato account, tab segmentate
/// Email / Password (stile design di riferimento) e input morbidi arrotondati.
/// La logica di auth è invariata: ogni tab mappa una singola operazione del
/// notifier (`verifyBeforeUpdateUserEmail` / `updatePasswordWithReauth`).
class AccountCredentialsScreen extends ConsumerStatefulWidget {
  const AccountCredentialsScreen({super.key});

  @override
  ConsumerState<AccountCredentialsScreen> createState() =>
      _AccountCredentialsScreenState();
}

class _AccountCredentialsScreenState
    extends ConsumerState<AccountCredentialsScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // La password attuale è condivisa: serve per la riautenticazione di entrambe
  // le operazioni, quindi un solo controller anche se compare in entrambi i tab.
  final _currentPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// 0 = cambio email, 1 = cambio password.
  int _tab = 0;

  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newEmailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final form = _emailFormKey.currentState;
    if (form == null || !form.validate()) return;

    final currentPw = _currentPasswordController.text;
    final newEmail = _newEmailController.text.trim();

    final currentEmail = ref
        .read(authNotifierProvider)
        .user
        ?.email
        ?.toLowerCase();
    if (currentEmail != null && newEmail.toLowerCase() == currentEmail) {
      showErrorDialog(context, 'La nuova email è uguale a quella attuale.');
      return;
    }

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .verifyBeforeUpdateUserEmail(
            currentPassword: currentPw,
            newEmail: newEmail,
          );
      if (!mounted) return;
      _newEmailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Controlla la casella della nuova email per confermare il cambio indirizzo.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      // Errore già mostrato tramite ref.listen su [authNotifierProvider].
    }
  }

  Future<void> _submitPassword() async {
    final form = _passwordFormKey.currentState;
    if (form == null || !form.validate()) return;

    final currentPw = _currentPasswordController.text;
    final newPw = _newPasswordController.text;

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .updatePasswordWithReauth(
            currentPassword: currentPw,
            newPassword: newPw,
          );
      if (!mounted) return;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password aggiornata.')));
    } catch (_) {
      // Errore già mostrato tramite ref.listen su [authNotifierProvider].
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final auth = ref.watch(authNotifierProvider);
    final email = auth.user?.email ?? '—';

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
        leadingWidth: 64,
        leading: _BackButton(),
        title: const SizedBox.shrink(),
      ),
      body: Theme(
        // Stile input morbido limitato a questa schermata: nessun impatto globale.
        data: theme.copyWith(
          inputDecorationTheme: softInputDecorationTheme(context),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(
              'Dati di accesso',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 30,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aggiorna l\'email o la password del tuo account.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _AccountHeroCard(email: email),
            const SizedBox(height: 20),
            FitSegmentedTabs(
              labels: const ['Email', 'Password'],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
              height: 52,
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(sizeFactor: anim, child: child),
              ),
              child: _tab == 0
                  ? _buildEmailSection(theme, cs, auth.isLoading)
                  : _buildPasswordSection(theme, cs, auth.isLoading),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailSection(ThemeData theme, ColorScheme cs, bool loading) {
    return FitSoftCard(
      key: const ValueKey('email-section'),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.alternate_email,
              title: 'Cambia email',
              subtitle: 'Riceverai un link di verifica al nuovo indirizzo.',
            ),
            const SizedBox(height: 20),
            _CurrentPasswordField(controller: _currentPasswordController),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newEmailController,
              decoration: const InputDecoration(
                labelText: 'Nuovo indirizzo email',
                hintText: 'nome@esempio.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Inserisci la nuova email';
                if (!_emailRegExp.hasMatch(value)) return 'Email non valida';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'L\'email dell\'account si aggiorna solo dopo la conferma dal link.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            _PillButton(
              label: 'Aggiorna email',
              loading: loading,
              onPressed: loading ? null : _submitEmail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection(ThemeData theme, ColorScheme cs, bool loading) {
    return FitSoftCard(
      key: const ValueKey('password-section'),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.lock_outline,
              title: 'Cambia password',
              subtitle: 'Almeno 6 caratteri. Conferma per sicurezza.',
            ),
            const SizedBox(height: 20),
            _CurrentPasswordField(controller: _currentPasswordController),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'Nuova password',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) {
                if (v == null || v.isEmpty)
                  return 'Inserisci la nuova password';
                if (v.length < 6) return 'Almeno 6 caratteri';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Conferma nuova password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Conferma la password';
                if (v != _newPasswordController.text) {
                  return 'Le password non coincidono';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            _PillButton(
              label: 'Aggiorna password',
              loading: loading,
              onPressed: loading ? null : _submitPassword,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo "password attuale" condiviso dalle due sezioni.
class _CurrentPasswordField extends StatelessWidget {
  const _CurrentPasswordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Password attuale',
        helperText: 'Richiesta per confermare la tua identità',
        prefixIcon: Icon(Icons.shield_outlined),
      ),
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Obbligatoria';
        return null;
      },
    );
  }
}

/// Card hero charcoal con avatar, email e badge "Account attivo".
class _AccountHeroCard extends StatelessWidget {
  const _AccountHeroCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = theme.extension<AppCardTheme>()!;
    final trimmed = email.trim();
    final initial = trimmed.isNotEmpty && trimmed != '—'
        ? trimmed[0].toUpperCase()
        : '?';

    return FitHeroCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: card.contentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: theme.textTheme.titleLarge?.copyWith(
                color: card.contentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: card.contentColorMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: card.contentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const FitBadgePill(
                  label: 'Account attivo',
                  leadingIcon: Icons.check_circle,
                  variant: FitBadgeVariant.solid,
                  onHeroSurface: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Intestazione di sezione: icona in badge + titolo + sottotitolo.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FitIconBadge(icon: icon, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pulsante primario a pillola (stadium) a tutta larghezza.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      child: loading
          ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}

/// Pulsante "indietro" circolare in AppBar (stile design di riferimento).
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: FitCircleIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Indietro',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
