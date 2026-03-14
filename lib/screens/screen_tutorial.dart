// ignore_for_file: use_build_context_synchronously
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shape + Step model
// ─────────────────────────────────────────────────────────────────────────────
enum STShape { circle, roundedRect, none }

class STStep {
  final GlobalKey? targetKey;
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final STShape shape;
  final double pad;

  const STStep({
    this.targetKey,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    this.shape = STShape.roundedRect,
    this.pad = 12,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences helpers
// ─────────────────────────────────────────────────────────────────────────────
Future<bool> isSTDone(String key) async {
  final p = await SharedPreferences.getInstance();
  return p.getBool(key) ?? false;
}

Future<void> markSTDone(String key) async {
  final p = await SharedPreferences.getInstance();
  await p.setBool(key, true);
}

Future<void> resetST(String key) async {
  final p = await SharedPreferences.getInstance();
  await p.remove(key);
}

// ─────────────────────────────────────────────────────────────────────────────
// Launch helper — inserts Overlay entry on top of the current screen
// ─────────────────────────────────────────────────────────────────────────────
OverlayEntry? _activeSTEntry;

void showSTTutorial({
  required BuildContext context,
  required List<STStep> steps,
  required String prefKey,
}) {
  _activeSTEntry?.remove();
  _activeSTEntry = OverlayEntry(
    builder: (_) => _STWidget(
      steps: steps,
      prefKey: prefKey,
      onDone: () {
        _activeSTEntry?.remove();
        _activeSTEntry = null;
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(_activeSTEntry!);
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal widget — the animated overlay
// ─────────────────────────────────────────────────────────────────────────────
class _STWidget extends StatefulWidget {
  final List<STStep> steps;
  final String prefKey;
  final VoidCallback onDone;

  const _STWidget({
    required this.steps,
    required this.prefKey,
    required this.onDone,
  });

  @override
  State<_STWidget> createState() => _STWidgetState();
}

class _STWidgetState extends State<_STWidget> with TickerProviderStateMixin {
  int _step = 0;
  Rect? _target;

  late AnimationController _spotCtrl;
  late Animation<double> _spotAnim;

  late AnimationController _cardCtrl;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _spotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _spotAnim =
        CurvedAnimation(parent: _spotCtrl, curve: Curves.easeOutCubic);

    _cardCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(0));
  }

  @override
  void dispose() {
    _spotCtrl.dispose();
    _cardCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _goTo(int idx) {
    if (idx >= widget.steps.length) {
      _finish();
      return;
    }
    final rect = _measure(widget.steps[idx].targetKey);
    if (mounted) {
      setState(() {
        _step = idx;
        _target = rect;
      });
    }
    _spotCtrl.forward(from: 0);
    _cardCtrl.forward(from: 0);
  }

  Rect? _measure(GlobalKey? key) {
    if (key == null) return null;
    try {
      final obj = key.currentContext?.findRenderObject();
      if (obj is! RenderBox) return null;
      final pos = obj.localToGlobal(Offset.zero);
      return Rect.fromLTWH(pos.dx, pos.dy, obj.size.width, obj.size.height);
    } catch (_) {
      return null;
    }
  }

  Future<void> _finish() async {
    await markSTDone(widget.prefKey);
    widget.onDone();
  }

  void _next() => _goTo(_step + 1);
  void _prev() {
    if (_step > 0) _goTo(_step - 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final step = widget.steps[_step];
    final isLast = _step == widget.steps.length - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step > 0) {
          _prev();
        } else {
          await _finish();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // ── Transparent tap-outside-to-advance layer ────────────
              Positioned.fill(
                child: GestureDetector(
                  onTap: _next,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),

              // ── Dim overlay + spotlight cutout ───────────────────────
              AnimatedBuilder(
                animation: _spotAnim,
                builder: (_, __) => CustomPaint(
                  size: size,
                  painter: _STSpotPainter(
                    target: _target,
                    shape: step.shape,
                    pad: step.pad,
                    progress: _spotAnim.value,
                    accent: step.accent,
                    isDark: isDark,
                  ),
                ),
              ),

              // ── Pulse ring ───────────────────────────────────────────
              if (_target != null && step.shape != STShape.none)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => CustomPaint(
                    size: size,
                    painter: _STPulsePainter(
                      target: _target!,
                      shape: step.shape,
                      pad: step.pad,
                      pulse: _pulseAnim.value,
                      accent: step.accent,
                    ),
                  ),
                ),

              // ── Tooltip card ─────────────────────────────────────────
              FadeTransition(
                opacity: _cardFade,
                child: SlideTransition(
                  position: _cardSlide,
                  child: _STCard(
                    step: step,
                    stepIndex: _step,
                    totalSteps: widget.steps.length,
                    targetRect: _target,
                    screenSize: size,
                    isDark: isDark,
                    isLast: isLast,
                    onNext: _next,
                    onPrev: _step > 0 ? _prev : null,
                    onSkip: _finish,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spotlight painter
// ─────────────────────────────────────────────────────────────────────────────
class _STSpotPainter extends CustomPainter {
  final Rect? target;
  final STShape shape;
  final double pad;
  final double progress;
  final Color accent;
  final bool isDark;

  const _STSpotPainter({
    required this.target,
    required this.shape,
    required this.pad,
    required this.progress,
    required this.accent,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dimOpacity =
        isDark ? 0.78 * progress : 0.65 * progress;
    final overlayColor = Colors.black.withValues(alpha: dimOpacity);

    if (target == null || shape == STShape.none) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = overlayColor);
      return;
    }

    final animPad = pad * progress;
    final spot = target!.inflate(animPad);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (shape == STShape.circle) {
      final r = math.min(spot.width, spot.height) / 2;
      path.addOval(Rect.fromCircle(center: spot.center, radius: r));
    } else {
      final radius = math.min(20.0 * progress, 20.0);
      path.addRRect(
          RRect.fromRectAndRadius(spot, Radius.circular(radius)));
    }

    canvas.drawPath(
        path..fillType = PathFillType.evenOdd,
        Paint()..color = overlayColor);

    // Glowing border around the spotlight
    final borderPaint = Paint()
      ..color = accent.withValues(alpha: 0.65 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * progress;

    if (shape == STShape.circle) {
      final r = math.min(spot.width, spot.height) / 2;
      canvas.drawCircle(spot.center, r, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(spot, Radius.circular(20 * progress)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_STSpotPainter old) =>
      old.progress != progress ||
      old.target != target ||
      old.accent != accent;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulse ring painter
// ─────────────────────────────────────────────────────────────────────────────
class _STPulsePainter extends CustomPainter {
  final Rect target;
  final STShape shape;
  final double pad;
  final double pulse;
  final Color accent;

  const _STPulsePainter({
    required this.target,
    required this.shape,
    required this.pad,
    required this.pulse,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final extra = pad + 4 + pulse * 22;
    final spot = target.inflate(extra);
    final opacity = (1 - pulse * 0.75).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = accent.withValues(alpha: 0.45 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (shape == STShape.circle) {
      final r = math.min(spot.width, spot.height) / 2;
      canvas.drawCircle(spot.center, r, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            spot, Radius.circular(20 + extra * 0.3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_STPulsePainter old) =>
      old.pulse != pulse || old.target != target;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tooltip card — glass card positioned above/below the spotlight
// ─────────────────────────────────────────────────────────────────────────────
class _STCard extends StatelessWidget {
  final STStep step;
  final int stepIndex;
  final int totalSteps;
  final Rect? targetRect;
  final Size screenSize;
  final bool isDark;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback? onPrev;
  final Future<void> Function() onSkip;

  const _STCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.targetRect,
    required this.screenSize,
    required this.isDark,
    required this.isLast,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
  });

  // Figure out whether card goes above or below the spotlight
  Alignment _align() {
    if (targetRect == null || step.shape == STShape.none) {
      return Alignment.center;
    }
    
    // If the target is huge, just center it to avoid clipping issues.
    final spaceAbove = targetRect!.top;
    final spaceBelow = screenSize.height - targetRect!.bottom;
    if (spaceAbove < 250 && spaceBelow < 250) {
      return Alignment.center;
    }

    final mid = targetRect!.center.dy;
    return mid > screenSize.height * 0.52
        ? Alignment.topCenter
        : Alignment.bottomCenter;
  }

  EdgeInsets _padding() {
    if (targetRect == null || step.shape == STShape.none) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }
    
    // If we decided to center because of huge target
    final spaceAbove = targetRect!.top;
    final spaceBelow = screenSize.height - targetRect!.bottom;
    if (spaceAbove < 250 && spaceBelow < 250) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }

    final r = targetRect!;
    const gap = 20.0;
    if (_align() == Alignment.bottomCenter) {
      return EdgeInsets.fromLTRB(20, r.bottom + gap, 20, 0);
    } else {
      return EdgeInsets.fromLTRB(
          20, 0, 20, screenSize.height - r.top + gap);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = step.accent;

    return SafeArea(
      child: Align(
        alignment: _align(),
        child: Padding(
          padding: _padding(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1B2E).withValues(alpha: 0.97)
                      : Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon badge
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.65)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(step.icon,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        // Title + step dots
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E1B2E),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children:
                                    List.generate(totalSteps, (i) {
                                  final active = i == stepIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(
                                        milliseconds: 280),
                                    margin:
                                        const EdgeInsets.only(right: 4),
                                    width: active ? 16 : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(3),
                                      color: active
                                          ? accent
                                          : accent.withValues(
                                              alpha: 0.22),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                        // Skip
                        if (!isLast)
                          TextButton(
                            onPressed: () => onSkip(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.black38,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Body ────────────────────────────────────────────
                    Text(
                      step.body,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.82)
                            : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Actions ─────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onPrev != null) ...[
                          IconButton(
                            onPressed: onPrev,
                            icon: Icon(Icons.arrow_back_rounded,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.black38),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                          ),
                          const SizedBox(width: 8),
                        ],
                        FilledButton(
                          onPressed: onNext,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 10),
                          ),
                          child: Text(
                            isLast ? 'Got it! 🎉' : 'Next →',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
