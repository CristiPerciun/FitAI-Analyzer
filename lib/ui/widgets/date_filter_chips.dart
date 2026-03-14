import 'package:fitai_analyzer/utils/date_utils.dart';
import 'package:flutter/material.dart';

/// Riga di chip per filtrare per data.
/// Ordine: Oggi, 5 gg indietro, Tutti. null = Oggi, [dateFilterAll] = Tutti.
class DateFilterChips extends StatelessWidget {
  const DateFilterChips({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.allLabel = 'Tutti',
    this.todayLabel = 'Oggi',
  });

  /// null = Oggi, dateFilterAll = Tutti, altrimenti data YYYY-MM-DD.
  final String? selectedDate;
  final void Function(String?) onDateSelected;
  final String allLabel;
  final String todayLabel;

  @override
  Widget build(BuildContext context) {
    final last6 = last6Days();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _DateChip(
              label: todayLabel,
              isSelected: selectedDate == null,
              onTap: () => onDateSelected(null),
            ),
          ),
          ...last6.skip(1).map((dateKey) {
            final label = formatDateForDisplay(dateKey);
            final isSelected = selectedDate == dateKey;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _DateChip(
                label: label,
                isSelected: isSelected,
                onTap: () => onDateSelected(isSelected ? null : dateKey),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _DateChip(
              label: allLabel,
              isSelected: selectedDate == dateFilterAll,
              onTap: () => onDateSelected(dateFilterAll),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
