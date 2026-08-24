import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';

/// The Factory "Module Mark": three filled blocks are Core + the first live
/// vertical (Beauty, in accent gold), the fourth is drawn open — the literal
/// next vertical slot, unbuilt on purpose. See the published "Factory
/// Logomark" design artifact for the full rationale. Built entirely from
/// [FactoryColors] tokens (primaryStrong/accent/primary/borderStrong/
/// surfaceAlt), so it adapts automatically across light/dark and any future
/// vertical's theme.
///
/// Below ~32 logical pixels the dashed open block anti-aliases into mush,
/// so this swaps to a flat "quiet" block automatically at that size —
/// matching the two variants the design artifact ships together, not a
/// missing feature in one of them. Pass [dashedFourthBlock] to override.
class FactoryLogomark extends StatelessWidget {
  const FactoryLogomark({super.key, this.size = 40, this.dashedFourthBlock});

  final double size;
  final bool? dashedFourthBlock;

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    return CustomPaint(
      size: Size.square(size),
      painter: _ModuleMarkPainter(
        colors: colors,
        dashed: dashedFourthBlock ?? size >= 32,
      ),
    );
  }
}

class _ModuleMarkPainter extends CustomPainter {
  const _ModuleMarkPainter({required this.colors, required this.dashed});

  final FactoryColors colors;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;

    void block(double x, double y, double w, double h, double rx, Color color) {
      final rect = Rect.fromLTWH(x * scale, y * scale, w * scale, h * scale);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rx * scale)), Paint()..color = color);
    }

    block(8, 8, 38, 38, 10, colors.primaryStrong);
    block(54, 8, 38, 38, 10, colors.accent);
    block(8, 54, 38, 38, 10, colors.primary);

    final fourthRect = Rect.fromLTWH(55.5 * scale, 55.5 * scale, 35 * scale, 35 * scale);
    final fourthRRect = RRect.fromRectAndRadius(fourthRect, Radius.circular(8.5 * scale));
    if (dashed) {
      _drawDashedRRect(canvas, fourthRRect, strokeWidth: 3 * scale, color: colors.borderStrong);
    } else {
      canvas.drawRRect(fourthRRect, Paint()..color = colors.surfaceAlt);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, {required double strokeWidth, required Color color}) {
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final dashWidth = 7 * (strokeWidth / 3);
    final dashGap = 6 * (strokeWidth / 3);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ModuleMarkPainter oldDelegate) =>
      colors != oldDelegate.colors || dashed != oldDelegate.dashed;
}
