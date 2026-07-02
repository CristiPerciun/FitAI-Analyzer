import 'package:fitai_analyzer/ui/widgets/multi_select_chip.dart'
    show MultiSelectOption;
import 'package:flutter/material.dart';

/// Menu a tendina a selezione multipla (bottom sheet con checkbox).
///
/// Variante "multi" di [DropdownWithSearch]: il campo collassato mostra le
/// etichette selezionate separate da virgola (o un hint se vuoto); il tap apre
/// un bottom sheet con una [CheckboxListTile] per opzione. Le modifiche sono
/// applicate in tempo reale ([onChanged]), così chiudere/scorrere via non perde
/// nulla. Riusa [MultiSelectOption] (id/label) del gruppo a chip.
class MultiSelectDropdown extends StatelessWidget {
  const MultiSelectDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final List<MultiSelectOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String? hint;

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MultiSelectSheet(
        label: label,
        options: options,
        selected: selected,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = options
        .where((o) => selected.contains(o.id))
        .map((o) => o.label)
        .toList();
    final isEmpty = labels.isEmpty;
    final display = isEmpty ? (hint ?? 'Seleziona…') : labels.join(', ');
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            display,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<MultiSelectOption> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = {...widget.selected};
  }

  void _toggle(String id, bool checked) {
    setState(() {
      if (checked) {
        _sel.add(id);
      } else {
        _sel.remove(id);
      }
    });
    // Commit in tempo reale: chiudere o scorrere via non perde la selezione.
    widget.onChanged({..._sel});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fatto'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: widget.options.map((o) {
                  return CheckboxListTile(
                    value: _sel.contains(o.id),
                    title: Text(o.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => _toggle(o.id, v ?? false),
                  );
                }).toList(),
              ),
            ),
            SafeArea(top: false, child: const SizedBox(height: 8)),
          ],
        );
      },
    );
  }
}
