import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_motion.dart';

/// Circular progress for "9 of 12 slots" style metrics. [value] is 0..1.
/// Animates between values unless the platform asks for reduced motion.
class FactoryProgressRing extends StatelessWidget {
  const FactoryProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 7,
    this.color,
    this.trackColor,
    this.child,
    this.semanticLabel,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final target = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(target * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: FactoryMotion.resolve(context, FactoryMotion.slow),
        curve: FactoryMotion.standard,
        builder: (context, v, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(v, strokeWidth, color ?? colors.primary, trackColor ?? colors.primaryTint),
            child: child == null ? null : Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.strokeWidth, this.color, this.track);

  final double value;
  final double strokeWidth;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(strokeWidth / 2, strokeWidth / 2) & Size(size.width - strokeWidth, size.height - strokeWidth);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.strokeWidth != strokeWidth;
}
