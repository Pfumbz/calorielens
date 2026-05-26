import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Premium orbiting-particles loading animation shown while AI analyses a meal.
class AnalysisLoadingWidget extends StatefulWidget {
  const AnalysisLoadingWidget({super.key});

  @override
  State<AnalysisLoadingWidget> createState() => _AnalysisLoadingWidgetState();
}

class _AnalysisLoadingWidgetState extends State<AnalysisLoadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _orbitCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _messageCtrl;

  int _messageIndex = 0;

  static const _messages = [
    'Scanning your meal…',
    'Identifying ingredients…',
    'Estimating portions…',
    'Calculating calories…',
    'Analysing macros…',
    'Preparing your breakdown…',
  ];

  @override
  void initState() {
    super.initState();

    // Orbit rotation — continuous 3s loop
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Pulse for center icon — continuous 1.5s loop
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Message cycling — every 2.2s
    _messageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _messageCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
        _messageCtrl.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _pulseCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1714), Color(0xFF131110)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CLColors.accent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: CLColors.accent.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Orbiting particles around central icon
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: Listenable.merge([_orbitCtrl, _pulseCtrl]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _OrbitPainter(
                    orbitProgress: _orbitCtrl.value,
                    pulseProgress: _pulseCtrl.value,
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulseCtrl.value * 0.08);
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  CLColors.accent.withOpacity(0.3),
                                  CLColors.accent.withOpacity(0.05),
                                ],
                              ),
                              border: Border.all(
                                color: CLColors.accent.withOpacity(0.5 + _pulseCtrl.value * 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.auto_awesome,
                              color: CLColors.accent.withOpacity(0.8 + _pulseCtrl.value * 0.2),
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Animated status message
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: child,
                ),
              );
            },
            child: Text(
              _messages[_messageIndex],
              key: ValueKey<int>(_messageIndex),
              style: const TextStyle(
                color: CLColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Subtle progress dots
          _buildProgressDots(),
        ],
      ),
    );
  }

  Widget _buildProgressDots() {
    return AnimatedBuilder(
      animation: _orbitCtrl,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final phase = (_orbitCtrl.value * 3 + i) % 3;
            final opacity = phase < 1 ? 0.3 + 0.7 * phase : phase < 2 ? 1.0 : 1.0 - 0.7 * (phase - 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CLColors.accent.withOpacity(opacity.clamp(0.3, 1.0)),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Draws orbiting particles (dots) around a central point with trailing glow.
class _OrbitPainter extends CustomPainter {
  final double orbitProgress;
  final double pulseProgress;

  _OrbitPainter({required this.orbitProgress, required this.pulseProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Draw orbit ring (faint)
    final ringPaint = Paint()
      ..color = CLColors.accent.withOpacity(0.08 + pulseProgress * 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, ringPaint);

    // Draw 6 orbiting particles at different sizes and speeds
    const particleCount = 6;
    for (int i = 0; i < particleCount; i++) {
      final angle = (orbitProgress * 2 * math.pi) +
          (i * 2 * math.pi / particleCount) +
          (i.isEven ? orbitProgress * math.pi * 0.3 : 0); // Slight speed variation

      final particleRadius = radius - (i % 3) * 4; // Slightly different orbit radii
      final x = center.dx + particleRadius * math.cos(angle);
      final y = center.dy + particleRadius * math.sin(angle);

      // Particle size varies
      final dotSize = 2.5 + (i % 3) * 1.0;

      // Color alternates between accent (orange) and gold
      final color = i.isEven
          ? CLColors.accent.withOpacity(0.6 + pulseProgress * 0.4)
          : CLColors.gold.withOpacity(0.4 + pulseProgress * 0.3);

      // Glow
      final glowPaint = Paint()
        ..color = color.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), dotSize + 3, glowPaint);

      // Particle
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(x, y), dotSize, dotPaint);
    }

    // Draw subtle inner ring glow
    final innerGlow = Paint()
      ..color = CLColors.accent.withOpacity(0.04 + pulseProgress * 0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius * 0.6, innerGlow);
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) =>
      orbitProgress != oldDelegate.orbitProgress ||
      pulseProgress != oldDelegate.pulseProgress;
}
