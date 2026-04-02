import 'package:fitai_analyzer/providers/dashboard_activity_providers.dart';
import 'package:fitai_analyzer/providers/data_sync_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _monthNames = [
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

/// Calendario mensile: giorni con almeno un'attività evidenziati; tap → filtro elenco allenamenti.
class ActivityCalendarCard extends ConsumerWidget {
  const ActivityCalendarCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focused = ref.watch(dashboardCalendarMonthProvider);
    final byDate = ref.watch(activitiesByDateProvider);
    final selectedFilter = ref.watch(selectedDateFilterProvider);
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);

    final first = DateTime(focused.year, focused.month, 1);
    final lastDay = DateTime(focused.year, focused.month + 1, 0).day;
    final leading = first.weekday - 1; // lun = 1 → 0 offset

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    final p = DateTime(focused.year, focused.month - 1);
                    ref.read(dashboardCalendarMonthProvider.notifier).state = p;
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[focused.month - 1]} ${focused.year}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final n = DateTime(focused.year, focused.month + 1);
                    ref.read(dashboardCalendarMonthProvider.notifier).state = n;
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: ['Lu', 'Ma', 'Me', 'Gi', 'Ve', 'Sa', 'Do']
                  .map(
                    (l) => Expanded(
                      child: Center(
                        child: Text(
                          l,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 40,
              ),
              itemCount: ((leading + lastDay + 6) ~/ 7) * 7,
              itemBuilder: (context, index) {
                final dayNum = index - leading + 1;
                if (dayNum < 1 || dayNum > lastDay) {
                  return const SizedBox.shrink();
                }
                final d = DateTime(focused.year, focused.month, dayNum);
                final key = activityDateKey(d);
                final hasAct = (byDate[key] ?? []).isNotEmpty;
                final isToday =
                    d.year == todayNorm.year &&
                    d.month == todayNorm.month &&
                    d.day == todayNorm.day;
                final isSelected = selectedFilter == key;

                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ref.read(selectedDateFilterProvider.notifier).state =
                            key;
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : hasAct
                                  ? theme.colorScheme.secondaryContainer
                                      .withValues(alpha: 0.45)
                                  : null,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 1.2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: hasAct || isSelected
                                      ? FontWeight.w700
                                      : null,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : null,
                                ),
                              ),
                              if (hasAct)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Tocca un giorno per filtrare l’elenco sotto.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
