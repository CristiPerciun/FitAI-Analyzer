import 'dart:ui' show ImageFilter;

import 'package:fitai_analyzer/models/feedback_message_model.dart';
import 'package:fitai_analyzer/providers/async_action_notifier.dart';
import 'package:fitai_analyzer/providers/auth_notifier.dart';
import 'package:fitai_analyzer/providers/providers.dart';
import 'package:fitai_analyzer/providers/route_transition_provider.dart';
import 'package:fitai_analyzer/services/feedback_service.dart';
import 'package:fitai_analyzer/theme/glass_tokens.dart';
import 'package:fitai_analyzer/ui/widgets/design/fit_soft_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Chat feedback utente → amministratore (solo invio lato client).
///
/// Stile "NaturaVita": bolle in vetro smerigliato sul gradiente globale e
/// barra di composizione frosted con pulsante d'invio a gradiente accento.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final text = _textController.text.trim();
    if (text.isEmpty || ref.read(feedbackSendActionProvider).isLoading) return;

    final ok = await ref
        .read(feedbackSendActionProvider.notifier)
        .run(
          () => ref.read(feedbackServiceProvider).sendUserMessage(uid, text),
        );
    if (!mounted) return;
    if (ok) {
      _textController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(feedbackMessagesStreamProvider);

    ref.listen(feedbackMessagesStreamProvider, (prev, next) {
      final prevCount = prev?.asData?.value.length ?? 0;
      final nextCount = next.asData?.value.length ?? 0;
      if (nextCount > prevCount) _scrollToBottom();
    });

    ref.listen(feedbackSendActionProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invio non riuscito: ${next.error}')),
        );
      }
    });

    final sending = ref.watch(feedbackSendActionProvider).isLoading;
    // Blur off durante le transizioni di rotta (evita scatti su desktop).
    final transitionActive = ref.watch(routeTransitionActiveProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _CenteredCard(
                icon: Icons.error_outline,
                text: 'Errore nel caricamento: $e',
                color: theme.colorScheme.error,
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const _CenteredCard(
                    icon: Icons.forum_outlined,
                    text:
                        'Scrivi un messaggio all’amministratore. '
                        'Riceverai una risposta quando sarà disponibile.',
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(
                      message: messages[index],
                      transitionActive: transitionActive,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _textController,
            sending: sending,
            onSend: _send,
            transitionActive: transitionActive,
          ),
        ],
      ),
    );
  }
}

/// Card in vetro centrata per stati vuoto/errore.
class _CenteredCard extends StatelessWidget {
  const _CenteredCard({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: FitSoftCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: tint),
                const SizedBox(height: 14),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: tint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra di composizione in vetro smerigliato (frosted) con pulsante d'invio
/// circolare a gradiente accento.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.transitionActive,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;
  final bool transitionActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tokens = theme.extension<GlassTokens>()!;
    const radius = BorderRadius.vertical(top: Radius.circular(28));

    Widget bar = DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.navTint,
        border: Border(top: BorderSide(color: tokens.borderColor)),
        borderRadius: radius,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = !sending && value.text.trim().isNotEmpty;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: FeedbackMessage.maxTextLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Scrivi un messaggio…',
                        counterText: '',
                        filled: true,
                        fillColor: cs.surface.withValues(
                          alpha: isDark ? 0.40 : 0.70,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: tokens.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: cs.primary, width: 1.5),
                        ),
                      ),
                      onSubmitted: canSend ? (_) => onSend() : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(
                    enabled: canSend,
                    sending: sending,
                    onTap: onSend,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    if (tokens.useRealBlur && !transitionActive) {
      bar = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.blurSigma,
          sigmaY: tokens.blurSigma,
        ),
        child: bar,
      );
    }

    return ClipRRect(borderRadius: radius, child: bar);
  }
}

/// Pulsante d'invio circolare: gradiente accento quando attivo, spento altrimenti.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  final bool enabled;
  final bool sending;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: enabled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.secondary],
              )
            : null,
        color: enabled ? null : cs.onSurface.withValues(alpha: 0.10),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Center(
            child: sending
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    size: 22,
                    color: enabled
                        ? cs.onPrimary
                        : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.transitionActive});

  final FeedbackMessage message;
  final bool transitionActive;

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      return DateFormat.Hm().format(dt);
    }
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tokens = theme.extension<GlassTokens>()!;
    final fromUser = message.isFromUser;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(fromUser ? 20 : 6),
      bottomRight: Radius.circular(fromUser ? 6 : 20),
    );

    // Utente = vetro tinto accento; amministratore = vetro frosted neutro.
    final gradient = fromUser
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: isDark ? 0.34 : 0.26),
              cs.primary.withValues(alpha: isDark ? 0.20 : 0.14),
            ],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: tokens.tintColors,
          );

    Widget bubble = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        border: Border.all(color: tokens.borderColor, width: 1),
        borderRadius: radius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Text(
          message.text,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: cs.onSurface,
            fontSize: 16,
          ),
        ),
      ),
    );

    if (tokens.useRealBlur && !transitionActive) {
      bubble = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: tokens.blurSigma,
          sigmaY: tokens.blurSigma,
        ),
        child: bubble,
      );
    }

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: fromUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.28 : 0.08,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(borderRadius: radius, child: bubble),
                ),
              ),
              if (message.createdAt != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
