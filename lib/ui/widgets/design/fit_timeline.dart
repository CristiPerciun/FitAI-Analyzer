import 'package:flutter/material.dart';

enum FitTimelineStatus { done, current, pending }

class FitTimelineItem {
  const FitTimelineItem({
    required this.content,
    this.status = FitTimelineStatus.pending,
  });
  final Widget content;
  final FitTimelineStatus status;
}

/// Lista verticale con linea di connessione a sinistra e dot/check di stato.
/// Lo stato è codificato dalla FORMA (check / anello / dot), non dal colore,
/// requisito necessario in palette monocromatica.
class FitTimeline extends StatelessWidget {
  const FitTimeline({super.key, required this.items, this.itemSpacing = 16});

  final List<FitTimelineItem> items;
  final double itemSpacing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineColor = cs.outline.withValues(alpha: 0.25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      _Dot(status: items[i].status),
                      if (i != items.length - 1)
                        Expanded(child: Container(width: 2, color: lineColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == items.length - 1 ? 0 : itemSpacing,
                    ),
                    child: items[i].content,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.status});
  final FitTimelineStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final surface = theme.cardTheme.color ?? cs.surface;

    switch (status) {
      case FitTimelineStatus.done:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Icon(Icons.check, size: 14, color: cs.onPrimary),
        );
      case FitTimelineStatus.current:
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(color: cs.primary, width: 2),
          ),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      case FitTimelineStatus.pending:
        return Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
          ),
        );
    }
  }
}
