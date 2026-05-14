import 'package:flutter/material.dart';

/// Cerchio di avanzamento con transizione (~2s), stesso comportamento della card nutrizione.
class AnimProgressRing extends StatefulWidget {
  const AnimProgressRing({
    super.key,
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color accentColor;
  final Color trackColor;

  @override
  State<AnimProgressRing> createState() => _AnimProgressRingState();
}

class _AnimProgressRingState extends State<AnimProgressRing> {
  static const Duration _duration = Duration(seconds: 2);

  late double _tweenBegin;
  late double _tweenEnd;

  @override
  void initState() {
    super.initState();
    final p = widget.progress.clamp(0.0, 1.0);
    _tweenBegin = p;
    _tweenEnd = p;
  }

  @override
  void didUpdateWidget(covariant AnimProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.progress.clamp(0.0, 1.0);
    if ((next - _tweenEnd).abs() < 0.0001) return;
    _tweenBegin = _tweenEnd;
    _tweenEnd = next;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: _duration,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: _tweenBegin, end: _tweenEnd),
      builder: (context, value, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: widget.strokeWidth,
            backgroundColor: widget.trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            strokeCap: StrokeCap.round,
          ),
        );
      },
    );
  }
}
