import 'package:fitai_analyzer/providers/caloric_deficit_chart_provider.dart';
import 'package:fitai_analyzer/providers/nutrition_chart_provider.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:fitai_analyzer/ui/widgets/design/design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Grafico settimanale: assunzione vs soglia dinamica (BMR + attività − deficit).
class CaloricDeficitBarChartCard extends ConsumerWidget {
  const CaloricDeficitBarChartCard({super.key});

  static const int _maxWeeksBack = 12;
  static const double _chartHeight = 200;
  static const double _leftAxisReserved = 34;
  static const double _bottomAxisReserved = 26;

  static String _weekTitle(int weekOffset) {
    if (weekOffset == 0) return 'Questa settimana';
    if (weekOffset == 1) return 'Settimana scorsa';
    return '$weekOffset settimane fa';
  }

  static double _maxY(CaloricDeficitWeekChartData data) {
    var m = 0.0;
    for (final p in data.points) {
      for (final v in [
        p.intakeKcal,
        p.thresholdKcal,
        p.dynamicTdeeKcal,
        p.moderateCeilingKcal,
        p.aggressiveCeilingKcal,
      ]) {
        if (v > m) m = v;
      }
    }
    return m <= 0 ? 2000 : (m * 1.15).clamp(400, double.infinity);
  }

  static void _showInfoDialog(
    BuildContext context,
    CaloricDeficitWeekChartData data,
  ) {
    final deficitPct = data.staticTdeeKcal > 0
        ? ((data.deficitKcal / data.staticTdeeKcal) * 100).round()
        : 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bilancio calorico'),
        content: SingleChildScrollView(
          child: Text(
            'A cosa serve\n\n'
            'Questo grafico ti aiuta a capire se, giorno per giorno, stai mangiando '
            'abbastanza per perdere grasso con calma e in sicurezza — oppure se stai '
            'andando oltre il limite che ti sei dato.\n\n'
            'Come leggerlo\n\n'
            '• Barre gialle: tutto ciò che hai mangiato e registrato (foto pasti, diario).\n'
            '• Barre grigie: quanto puoi mangiare quel giorno secondo il tuo obiettivo '
            'AI/profilo di dimagrimento. Se ti alleni, il limite sale perché bruci di più '
            '(come nell\'anello Calorie sopra).\n'
            '• Linea chiara continua: il tuo fabbisogno stimato del giorno '
            '(TDEE medio + allenamenti da Garmin/Strava).\n'
            '• Linea viola tratteggiata: limite «moderato» — il taglio consigliato per '
            'perdere peso senza perdere troppa massa magra.\n'
            '• Linea rossa tratteggiata: limite «aggressivo» — solo per periodi brevi, '
            'non come obiettivo quotidiano.\n\n'
            'Regola semplice: se il giallo resta sotto il grigio, sei in linea. '
            'Se supera il grigio, quel giorno hai mangiato più del previsto.\n\n'
            'Da dove viene questo metodo\n\n'
            'Ci siamo ispirati alla nutrizione sportiva di Project inVictus '
            '(projectinvictus.it): guide su definizione muscolare, alimentazione '
            'e percorsi formativi (es. inVictus Nutrition). L\'idea è allenarsi '
            'e mangiare «con la testa» — dati concreti, non sensazioni a caso.\n\n'
            'Per i numeri usiamo:\n'
            '• il calcolo del metabolismo a riposo più usato in ambito clinico '
            '(Mifflin–St Jeor);\n'
            '• il tuo livello di attività (giorni di allenamento che hai indicato);\n'
            '• un taglio calorico che dipende da obiettivo e velocità (lenta, media, aggressiva), '
            'in linea con le raccomandazioni per un deficit sostenibile (circa 15–20% '
            'per un percorso moderato; 25–30% solo come riferimento «aggressivo», '
            'come nelle linee guida nutrizionali diffuse anche in ambito UK/NHS).\n\n'
            'I tuoi valori oggi\n'
            'Energia a riposo ≈ ${data.bmrKcal.round()} kcal al giorno\n'
            'Fabbisogno medio ≈ ${data.staticTdeeKcal.round()} kcal\n'
            'Obiettivo AI/profilo ≈ ${data.calorieTargetKcal.round()} kcal'
            '${data.showDeficitBands ? '\nTaglio impostato ≈ $deficitPct% rispetto al fabbisogno' : ''}.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weekOffset = ref.watch(nutritionDiaryWeekOffsetProvider);
    final diaryAsync = ref.watch(nutritionDiaryWeekChartDataProvider);
    final data = ref.watch(caloricDeficitWeekChartProvider);

    if (diaryAsync.isLoading && !diaryAsync.hasValue) {
      return const FitSoftCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (diaryAsync.hasError && !diaryAsync.hasValue) {
      return FitSoftCard(child: Text('Errore grafico: ${diaryAsync.error}'));
    }

    return FitSoftCard(
      padding: EdgeInsets.zero,
      child: _ChartBody(
        data: data,
        weekOffset: weekOffset,
        maxY: _maxY(data),
        theme: theme,
        onInfoTap: () =>
            CaloricDeficitBarChartCard._showInfoDialog(context, data),
      ),
    );
  }
}

class _ChartBody extends ConsumerWidget {
  const _ChartBody({
    required this.data,
    required this.weekOffset,
    required this.maxY,
    required this.theme,
    required this.onInfoTap,
  });

  final CaloricDeficitWeekChartData data;
  final int weekOffset;
  final double maxY;
  final ThemeData theme;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = theme.colorScheme;
    final points = data.points;
    final gridInterval = maxY / 4;

    final lineBars = <LineChartBarData>[
      LineChartBarData(
        spots: List.generate(
          7,
          (i) => FlSpot(i.toDouble(), points[i].dynamicTdeeKcal),
        ),
        isCurved: false,
        color: cs.onSurface.withValues(alpha: 0.7),
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ),
    ];
    if (data.showDeficitBands) {
      lineBars.addAll([
        LineChartBarData(
          spots: List.generate(
            7,
            (i) => FlSpot(i.toDouble(), points[i].moderateCeilingKcal),
          ),
          isCurved: false,
          color: AppColors.garminBlue,
          barWidth: 2.5,
          dashArray: [5, 5],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        LineChartBarData(
          spots: List.generate(
            7,
            (i) => FlSpot(i.toDouble(), points[i].aggressiveCeilingKcal),
          ),
          isCurved: false,
          color: cs.error.withValues(alpha: 0.6),
          barWidth: 1.5,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                tooltip: 'Info grafico',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
                onPressed: onInfoTap,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bilancio calorico',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Giallo = mangiato · Grigio = quanto puoi mangiare oggi',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: weekOffset < CaloricDeficitBarChartCard._maxWeeksBack
                      ? FitCircleIconButton(
                          icon: Icons.chevron_left,
                          tooltip: 'Settimana precedente',
                          iconColor: cs.primary,
                          onPressed: () => ref
                              .read(nutritionDiaryWeekOffsetProvider.notifier)
                              .setWeeksAgo(weekOffset + 1),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Text(
                    CaloricDeficitBarChartCard._weekTitle(weekOffset),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: weekOffset > 0
                      ? FitCircleIconButton(
                          icon: Icons.chevron_right,
                          tooltip: 'Settimana successiva',
                          iconColor: cs.primary,
                          onPressed: () => ref
                              .read(nutritionDiaryWeekOffsetProvider.notifier)
                              .setWeeksAgo(weekOffset - 1),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: CaloricDeficitBarChartCard._chartHeight,
            child: Stack(
              children: [
                BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            cs.inverseSurface.withValues(alpha: 0.92),
                        getTooltipItem: (group, _, rod, _) {
                          final i = group.x;
                          if (i < 0 || i >= points.length) return null;
                          final p = points[i];
                          final status = p.isInDeficit
                              ? 'In deficit'
                              : (p.intakeKcal > 0
                                    ? 'Sopra soglia'
                                    : 'Nessun pasto');
                          final bands = data.showDeficitBands
                              ? '\nModerato: ${p.moderateCeilingKcal.round()} · '
                                    'Aggressivo: ${p.aggressiveCeilingKcal.round()}'
                              : '';
                          return BarTooltipItem(
                            '${p.label}\n'
                            'Assunte: ${p.intakeKcal.round()} kcal\n'
                            'Obiettivo: ${p.thresholdKcal.round()} kcal\n'
                            'Spesa din.: ${p.dynamicTdeeKcal.round()} kcal'
                            '$bands\n'
                            '$status',
                            TextStyle(
                              color: cs.onInverseSurface,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize:
                              CaloricDeficitBarChartCard._bottomAxisReserved,
                          interval: 1,
                          getTitlesWidget: (value, _) {
                            final i = value.toInt();
                            if (i < 0 || i >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                points[i].label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize:
                              CaloricDeficitBarChartCard._leftAxisReserved,
                          interval: gridInterval,
                          getTitlesWidget: (value, _) => Text(
                            value.round().toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: gridInterval,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: cs.outline.withValues(alpha: 0.2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: _buildBarGroups(points),
                  ),
                  duration: const Duration(milliseconds: 250),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: CaloricDeficitBarChartCard._leftAxisReserved,
                    right: 4,
                    bottom: CaloricDeficitBarChartCard._bottomAxisReserved,
                    top: 4,
                  ),
                  child: LineChart(
                    LineChartData(
                      minX: -0.35,
                      maxX: 6.35,
                      minY: 0,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      lineBarsData: lineBars,
                    ),
                    duration: const Duration(milliseconds: 250),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Legend(showDeficitBands: data.showDeficitBands, theme: theme),
          if (data.todayStatusText != null) ...[
            const SizedBox(height: 8),
            Text(
              data.todayStatusText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<CaloricDeficitDayPoint> points) {
    return List.generate(7, (i) {
      final p = points[i];
      final intake = p.intakeKcal;
      final threshold = p.thresholdKcal;
      final surplus = p.surplusKcal;
      final rodToY = intake > 0 ? intake : 0.0;

      List<BarChartRodStackItem> stackItems = [];
      if (intake > 0) {
        if (surplus > 0) {
          final base = threshold.clamp(0.0, intake).toDouble();
          stackItems = [
            BarChartRodStackItem(0, base, AppColors.caloricIntakeBar),
            BarChartRodStackItem(base, intake, AppColors.caloricSurplusBar),
          ];
        } else {
          stackItems = [
            BarChartRodStackItem(0, intake, AppColors.caloricIntakeBar),
          ];
        }
      }

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: rodToY,
            width: 14,
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(7),
              bottom: Radius.circular(3),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: threshold > 0,
              toY: threshold,
              color: AppColors.caloricDeficitGoalBar.withValues(alpha: 0.85),
            ),
            rodStackItems: stackItems,
          ),
        ],
      );
    });
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.showDeficitBands, required this.theme});

  final bool showDeficitBands;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget item(Color color, String label, {bool dashed = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dashed)
            SizedBox(
              width: 14,
              height: 2,
              child: CustomPaint(painter: _DashLinePainter(color: color)),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted,
              fontSize: 9,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        item(AppColors.caloricIntakeBar, 'Assunte'),
        item(AppColors.caloricDeficitGoalBar, 'Tuo obiettivo'),
        item(theme.colorScheme.onSurface.withValues(alpha: 0.75), 'Spesa din.'),
        if (showDeficitBands) ...[
          item(AppColors.garminBlue, 'Moderato (15–20%)', dashed: true),
          item(
            theme.colorScheme.error.withValues(alpha: 0.7),
            'Aggressivo (25–30%)',
            dashed: true,
          ),
        ],
      ],
    );
  }
}

class _DashLinePainter extends CustomPainter {
  _DashLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
