import 'package:flutter/material.dart';

/// Opzione per [MultiSelectChipGroup].
class MultiSelectOption {
  const MultiSelectOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Gruppo di FilterChip a selezione multipla.
class MultiSelectChipGroup extends StatelessWidget {
  const MultiSelectChipGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<MultiSelectOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final isSel = selected.contains(o.id);
            return FilterChip(
              label: Text(o.label),
              selected: isSel,
              onSelected: (v) {
                final next = Set<String>.from(selected);
                if (v) {
                  next.add(o.id);
                } else {
                  next.remove(o.id);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
