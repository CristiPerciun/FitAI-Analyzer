import 'package:fitai_analyzer/providers/nutrition_meal_edit_provider.dart';
import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Schermata a tutto schermo per rivedere l’analisi nutrizionale IA: riepilogo in alto, porzione (g) e valori scalati in proporzione.
class NutritionMealAnalysisScreen extends ConsumerStatefulWidget {
  const NutritionMealAnalysisScreen({
    super.key,
    required this.advice,
    required this.foods,
    required this.onSave,
    this.onDelete,
  });

  final String advice;
  final List<dynamic> foods;
  final Future<void> Function(Map<String, dynamic> modifiedNut) onSave;
  final Future<void> Function()? onDelete;

  @override
  ConsumerState<NutritionMealAnalysisScreen> createState() => _NutritionMealAnalysisScreenState();
}

class _NutritionMealAnalysisScreenState extends ConsumerState<NutritionMealAnalysisScreen> {
  /// Evita più `pop` programmati se `draft` diventa null e il widget si ribuilda più volte.
  bool _scheduledExitForNullDraft = false;

  Future<void> _saveAndPop() async {
    final d = ref.read(nutritionMealEditProvider);
    if (d == null || !mounted) return;
    final nut = d.toModifiedNut();
    Navigator.of(context).pop();
    // Dopo `pop` il navigator può restare `_debugLocked` nello stesso frame (soprattutto su web).
    await Future<void>.delayed(Duration.zero);
    await widget.onSave(nut);
  }

  Future<void> _confirmDelete() async {
    if (widget.onDelete == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminare il pasto?'),
        content: const Text('Verrà rimosso dal diario e i totali del giorno verranno aggiornati.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
              foregroundColor: Theme.of(c).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Il `pop` del dialogo può ancora tenere il navigator bloccato: rimandiamo il pop della route.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pop();
    await Future<void>.delayed(Duration.zero);
    await widget.onDelete!();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(nutritionMealEditProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (draft == null) {
      if (!_scheduledExitForNullDraft) {
        _scheduledExitForNullDraft = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Analisi nutrizionali')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final dishName = draft.sourceMap['dish_name']?.toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisi nutrizionali'),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Elimina pasto',
              icon: Icon(Icons.delete_outline, color: cs.error),
              onPressed: _confirmDelete,
            ),
          IconButton(
            tooltip: 'Salva',
            icon: Icon(Icons.save_outlined, color: AppColors.greenSave),
            onPressed: _saveAndPop,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (dishName != null && dishName.isNotEmpty) ...[
            Text(dishName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
          ],
          if (widget.foods.isNotEmpty) ...[
            Text('Alimenti', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...widget.foods.take(12).map((e) {
              if (e is! Map) return const Text('• ?');
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${e['name'] ?? '?'}', style: theme.textTheme.bodyMedium),
              );
            }),
          ],
          if (widget.advice.isNotEmpty) ...[
            if (widget.foods.isNotEmpty) const SizedBox(height: 16),
            Text('Consiglio', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(widget.advice, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          Divider(color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Porzione e valori nutrizionali',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Modifica i grammi totali stimati: calorie e macro si aggiornano in proporzione all’analisi iniziale.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _PortionRow(
            portionGrams: draft.portionGrams,
            basePortionGrams: draft.basePortionGrams,
            onDelta: (d) => ref.read(nutritionMealEditProvider.notifier).adjustPortionBy(d),
            onSetPortion: (g) => ref.read(nutritionMealEditProvider.notifier).setPortionGrams(g),
          ),
          const SizedBox(height: 24),
          _NutrientTile(label: 'Calorie', value: '${draft.calories}', unit: 'kcal'),
          _NutrientTile(label: 'Proteine', value: '${draft.protein}', unit: 'g'),
          _NutrientTile(label: 'Carboidrati', value: '${draft.carbs}', unit: 'g'),
          _NutrientTile(label: 'Grassi', value: '${draft.fat}', unit: 'g'),
          _NutrientTile(label: 'Zuccheri', value: '${draft.sugar}', unit: 'g'),
        ],
      ),
    );
  }
}

class _PortionRow extends StatefulWidget {
  const _PortionRow({
    required this.portionGrams,
    required this.basePortionGrams,
    required this.onDelta,
    required this.onSetPortion,
  });

  final int portionGrams;
  final double basePortionGrams;
  final void Function(int deltaGrams) onDelta;
  final void Function(int grams) onSetPortion;

  static const int _step = 10;

  @override
  State<_PortionRow> createState() => _PortionRowState();
}

class _PortionRowState extends State<_PortionRow> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.portionGrams.toString());
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _PortionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portionGrams != widget.portionGrams && !_focus.hasFocus) {
      final t = widget.portionGrams.toString();
      if (_controller.text != t) _controller.text = t;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _applyPortionFromField();
  }

  void _applyPortionFromField() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      _controller.text = widget.portionGrams.toString();
      return;
    }
    final v = int.tryParse(raw);
    if (v == null) {
      _controller.text = widget.portionGrams.toString();
      return;
    }
    widget.onSetPortion(v);
  }

  void _beforeStep() {
    if (_focus.hasFocus) _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quantità stimata (porzione totale)',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Riferimento IA: ${widget.basePortionGrams.round()} g',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filled(
                  onPressed: () {
                    _beforeStep();
                    widget.onDelta(-_PortionRow._step);
                  },
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Center( 
                        child: SizedBox(
                      width: 160, 
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          suffixText: 'g',
                          suffixStyle: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          isDense: true,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: cs.outlineVariant, width: 1),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: cs.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.only(left: 4, right: 4, top: 6, bottom: 8),
                        ),
                        onSubmitted: (_) => _focus.unfocus(),
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: () {
                    _beforeStep();
                    widget.onDelta(_PortionRow._step);
                  },
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientTile extends StatelessWidget {
  const _NutrientTile({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyLarge),
          ),
          Text(
            '$value $unit',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}
