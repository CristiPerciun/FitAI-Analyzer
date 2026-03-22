import 'package:flutter/material.dart';

/// Dropdown con ricerca testuale (bottom sheet).
class DropdownWithSearch extends StatelessWidget {
  const DropdownWithSearch({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hint;

  Future<void> _openSheet(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DropdownSearchSheet(
        label: label,
        options: options,
        selected: value,
      ),
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value ?? hint ?? 'Seleziona…';
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
              color: value == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownSearchSheet extends StatefulWidget {
  const _DropdownSearchSheet({
    required this.label,
    required this.options,
    required this.selected,
  });

  final String label;
  final List<String> options;
  final String? selected;

  @override
  State<_DropdownSearchSheet> createState() => _DropdownSearchSheetState();
}

class _DropdownSearchSheetState extends State<_DropdownSearchSheet> {
  late final TextEditingController _controller;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      setState(() => _query = _controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _query.isEmpty
        ? widget.options
        : widget.options
            .where(
              (e) => e.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Cerca…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                autofocus: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final o = filtered[i];
                  return ListTile(
                    title: Text(o),
                    trailing: widget.selected == o
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(context, o),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
