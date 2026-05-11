import 'package:fitai_analyzer/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Stesso key su più [LaunchScreen] nel bootstrap (AuthGateway): lo [State]
/// non viene distrutto quando cambia solo il parent (`Scaffold` / gate), così
/// l’animazione intro non riparte da zero a ogni transizione → niente icona „due volte“.
///
/// Vale solo dove lo passi esplicitamente: `LaunchScreen(key: launchScreenPreserveStateKey)`.
final GlobalKey<State<LaunchScreen>> launchScreenPreserveStateKey =
    GlobalKey<State<LaunchScreen>>(debugLabel: 'launchPreserve');

/// Schermata unica di avvio: logo, titolo e loader finché auth/profilo/dati Home non sono pronti.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  static const _logoSize = 120.0;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with TickerProviderStateMixin {
  static const double _logoSize = LaunchScreen._logoSize;

  late final AnimationController _intro;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  late final AnimationController _barSweep;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.44, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.34, 0.92, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.085),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.34, 0.92, curve: Curves.easeOutCubic),
      ),
    );

    _barSweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _intro.isCompleted) return;
      _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _barSweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  scheme.surface,
                  scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ]
              : [
                  AppColors.backgroundLight,
                  AppColors.backgroundLight.withValues(alpha: 0.92),
                ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    alignment: Alignment.center,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(
                              alpha: isDark ? 0.09 : 0.06,
                            ),
                            blurRadius: 36,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/branding/app_icon.png',
                          width: _logoSize,
                          height: _logoSize,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.health_and_safety_outlined,
                            size: _logoSize * 0.55,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Text(
                      'FitAI Analyzer',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Text(
                      'Caricamento in corso…',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: _minimalSweepBar(theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _minimalSweepBar(ThemeData theme) {
    final scheme = theme.colorScheme;
    final trackColor = scheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.1 : 0.08,
    );

    const barWidth = 152.0;
    const barHeight = 5.0;

    return SizedBox(
      width: barWidth,
      height: barHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: AnimatedBuilder(
          animation: _barSweep,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(
              (_barSweep.value * 2 <= 1
                  ? _barSweep.value * 2
                  : 2 - _barSweep.value * 2),
            );
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                ColoredBox(color: trackColor),
                Align(
                  alignment: Alignment(((t - 0.5) * 2 * 1.06).clamp(-1.0, 1.0), 0),
                  child: Container(
                    width: barWidth * 0.4,
                    height: barHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.15),
                          scheme.primary.withValues(alpha: 0.72),
                          scheme.primary.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
