import 'package:flutter/material.dart';

/// Un segmento della barra: valore relativo + etichetta.
class FitBarSegment {
  const FitBarSegment(this.value, this.label);
  final double value;
  final String label;
}

/// Barra orizzontale unica divisa in segmenti proporzionali + legenda.
/// In monocromatico i segmenti si distinguono per gradini di opacità di
/// [ColorScheme.onSurface] separati da hairline del colore card, e dalla
/// legenda testuale con percentuali (la forma non basta da sola).
class FitSegmentedProgressBar extends StatelessWidget {
  const FitSegmentedProgressBar({
    super.key,
    required this.segments,
    this.height = 14,
    this.showLegend = true,
    this.dividerColor,
    this.colors,
  });

  final List<FitBarSegment> segments;
  final double height;
  final bool showLegend;

  /// Colore della "cucitura" fra segmenti; default = colore card (taglio netto).
  final Color? dividerColor;

  /// Colori espliciti per segmento (ruolo semantico, es. macro P/C/G).
  /// Se null si usano i gradini di opacità monocromatici.
  final List<Color>? colors;

  static const List<double> _alphaSteps = [0.90, 0.55, 0.28, 0.16];

  Color _segmentColor(ColorScheme cs, int index) {
    if (colors != null && index < colors!.length) return colors![index];
    final a = _alphaSteps[index.clamp(0, _alphaSteps.length - 1)];
    return cs.onSurface.withValues(alpha: a);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    final seam = dividerColor ?? theme.cardTheme.color ?? cs.surface;

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final flex = total <= 0 ? 1 : (segments[i].value / total * 1000).round();
      if (i > 0) {
        children.add(Container(width: 1.5, color: seam));
      }
      children.add(
        Expanded(
          flex: flex <= 0 ? 1 : flex,
          child: ColoredBox(color: _segmentColor(cs, i)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Row(children: children),
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (var i = 0; i < segments.length; i++)
                _LegendItem(
                  color: _segmentColor(cs, i),
                  label: segments[i].label,
                  percent: total <= 0
                      ? '0%'
                      : '${(segments[i].value / total * 100).round()}%',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final String percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          percent,
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
