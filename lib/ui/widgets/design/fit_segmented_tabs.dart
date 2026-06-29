import 'package:flutter/material.dart';

/// Controllo a pillole segmentate con thumb scorrevole animato.
/// Generalizza il pattern pill di date_filter_chips per switch a larghezza fissa
/// (2-4 voci). Stile riferimento "Connection / Statistics / Shop".
class FitSegmentedTabs extends StatelessWidget {
  const FitSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 44,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final count = labels.length;
    // In dark, cs.onSurfaceVariant (textMuted) sulla track ha contrasto ~2.9:1,
    // sotto la soglia 4.5:1: si rinforza l'etichetta non selezionata al buio.
    final unselectedColor = theme.brightness == Brightness.dark
        ? cs.onSurface.withValues(alpha: 0.7)
        : cs.onSurfaceVariant;

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final segWidth = c.maxWidth / count;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  count == 1 ? 0 : (selectedIndex / (count - 1)) * 2 - 1,
                  0,
                ),
                child: Container(
                  width: segWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: i == selectedIndex
                                  ? cs.onPrimary
                                  : unselectedColor,
                              fontWeight: i == selectedIndex
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
