import 'package:fitai_analyzer/providers/theme_mode_provider.dart';
import 'package:fitai_analyzer/ui/impostazioni/feedback_screen.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Verde "switch acceso" stile iOS, condiviso dalle righe impostazioni.
const Color kIosSwitchOn = Color(0xFF34C759);

/// Gruppo (card arrotondata) di righe stile iOS.
class IosGroup extends StatelessWidget {
  const IosGroup({
    super.key,
    required this.color,
    required this.isDark,
    this.child,
    this.children,
  }) : assert(
         (child != null) ^ (children != null),
         'Provide either child or children',
       );

  /// Allineamento etichetta dopo icona (padding 16 + 29 + 12 ≈ 57).
  static const double rowLabelInset = 64;

  final Color color;
  final bool isDark;
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final content =
        child ?? Column(mainAxisSize: MainAxisSize.min, children: children!);

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? null
            : Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.12),
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

class IosSectionHeader extends StatelessWidget {
  const IosSectionHeader({super.key, required this.label, required this.color});

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

class IosRowDivider extends StatelessWidget {
  const IosRowDivider({super.key, this.indent = 0});

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

class IosAiBackendSwitchRow extends StatelessWidget {
  const IosAiBackendSwitchRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor = kIosSwitchOn,
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
              leading,
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

class IosSwitchRow extends StatelessWidget {
  const IosSwitchRow({
    super.key,
    required this.leading,
    required this.title,
    required this.value,
    required this.onChanged,
    this.activeColor = kIosSwitchOn,
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
        onTap: onChanged == null ? null : () => onChanged!(!value),
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

class IosNavigationRow extends StatelessWidget {
  const IosNavigationRow({
    super.key,
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
              leading,
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

class IosDestructiveRow extends StatelessWidget {
  const IosDestructiveRow({
    super.key,
    required this.title,
    required this.onTap,
  });

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

class FeedbackNavigationRow extends StatelessWidget {
  const FeedbackNavigationRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const FitIconBadge(
                icon: Icons.chat_bubble_outline,
                size: 38,
                radius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Lascia un feedback',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 17,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeModeIosRow extends ConsumerWidget {
  const ThemeModeIosRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);
    final label = _label(themeMode);

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
              FitIconBadge(
                icon: themeMode == ThemeMode.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                size: 38,
                radius: 10,
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
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
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
