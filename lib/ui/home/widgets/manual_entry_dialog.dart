import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

enum _ManualEntryPresentation { dialog, sheet }

/// Apre l'input manuale del pasto.
///
/// Su web (incluso iPhone PWA) usa un bottom sheet ancorato in basso così la
/// tastiera non rompe il layout; su native resta un [AlertDialog].
Future<String?> showManualEntryDialog(BuildContext context) {
  if (kIsWeb) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const _ManualEntryWidget(
          presentation: _ManualEntryPresentation.sheet,
        ),
      ),
    );
  }

  return showDialog<String>(
    context: context,
    builder: (_) => const ManualEntryDialog(),
  );
}

/// Dialog nativo (Android/iOS/macOS/Windows). Su web preferire [showManualEntryDialog].
class ManualEntryDialog extends StatelessWidget {
  const ManualEntryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: const _ManualEntryWidget(
        presentation: _ManualEntryPresentation.dialog,
      ),
    );
  }
}

class _ManualEntryWidget extends StatefulWidget {
  const _ManualEntryWidget({required this.presentation});

  final _ManualEntryPresentation presentation;

  @override
  State<_ManualEntryWidget> createState() => _ManualEntryWidgetState();
}

class _ManualEntryWidgetState extends State<_ManualEntryWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool get _isSheet => widget.presentation == _ManualEntryPresentation.sheet;

  @override
  void initState() {
    super.initState();
    // Su web iOS la tastiera richiede un tap diretto: autofocus/requestFocus
    // lampeggiano e non aprono la tastiera.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _focusNode.requestFocus();
        });
      });
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _textField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: 3,
      autofocus: !kIsWeb,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      autocorrect: true,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: 'Es.: 1 scatoletta tonno Rio Mare e insalata valeriana',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _actions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text('Analizza', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const title = Text(
      'Cosa hai mangiato?',
      style: TextStyle(fontWeight: FontWeight.bold),
    );

    if (_isSheet) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 16),
            _textField(),
            const SizedBox(height: 16),
            _actions(),
          ],
        ),
      );
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: title,
      content: _textField(),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          child: const Text('Analizza', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
