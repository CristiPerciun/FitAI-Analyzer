import 'package:flutter/material.dart';

/// Una barra dell'equalizer: valore normalizzato 0..1 + etichetta + valore opzionale.
class FitSliderBar {
  const FitSliderBar(this.value, this.label, {this.valueLabel});
  final double value;
  final String label;

  /// Testo opzionale mostrato sopra la barra (es. "320" kcal).
  final String? valueLabel;
}

/// Grafico a barre stile "slider/equalizer": traccia sottile arrotondata con
/// porzione piena, pomello in cima e dot di base, come nella schermata
/// Statistics del riferimento. Reso con widget semplici (niente fl_chart).
class FitSliderBarChart extends StatelessWidget {
  const FitSliderBarChart({
    super.key,
    required this.bars,
    this.height = 200,
    this.trackWidth = 7,
    this.knobSize = 14,
    this.barColor,
    this.showValueLabels = true,
  });

  final List<FitSliderBar> bars;
  final double height;
  final double trackWidth;

  /// Diametro del pomello; <= 0 disattiva il pomello (utile con molte barre).
  final double knobSize;
  final Color? barColor;
  final bool showValueLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill = barColor ?? cs.primary;
    final track = cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.10);
    final knobFill = theme.cardTheme.color ?? cs.surface;
    final hasValueLabels =
        showValueLabels && bars.any((b) => b.valueLabel != null);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (hasValueLabels)
                    SizedBox(
                      height: 16,
                      child: Text(
                        bar.valueLabel ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final maxH = c.maxHeight;
                        final v = bar.value.clamp(0.0, 1.0);
                        return TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          tween: Tween(begin: 0, end: v),
                          builder: (context, t, _) {
                            final fillH = (maxH * t).clamp(trackWidth, maxH);
                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                // traccia di fondo
                                Container(
                                  width: trackWidth,
                                  decoration: BoxDecoration(
                                    color: track,
                                    borderRadius: BorderRadius.circular(
                                      trackWidth / 2,
                                    ),
                                  ),
                                ),
                                // porzione piena
                                Container(
                                  width: trackWidth,
                                  height: fillH,
                                  decoration: BoxDecoration(
                                    color: fill,
                                    borderRadius: BorderRadius.circular(
                                      trackWidth / 2,
                                    ),
                                  ),
                                ),
                                // dot di base (ancora)
                                Positioned(
                                  bottom: 0,
                                  child: Container(
                                    width: trackWidth + 2,
                                    height: trackWidth + 2,
                                    decoration: BoxDecoration(
                                      color: fill,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                // pomello stile slider
                                if (knobSize > 0 && v > 0.001)
                                  Positioned(
                                    bottom: (maxH * t - knobSize / 2).clamp(
                                      0.0,
                                      maxH - knobSize,
                                    ),
                                    child: Container(
                                      width: knobSize,
                                      height: knobSize,
                                      decoration: BoxDecoration(
                                        color: knobFill,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: fill,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bar.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
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
