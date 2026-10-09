import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';

/// Axis-less trend line for a metric tile. Cheap enough for lists: one
/// [CustomPaint], no animation. [values] needs at least two points; fewer
/// paints nothing. [fill] adds a soft gradient under the line.
class FactorySparkline extends StatelessWidget {
  const FactorySparkline({
    super.key,
    required this.values,
    this.color,
    this.fill = true,
    this.strokeWidth = 2,
    this.height = 32,
    this.semanticLabel,
  });

  final List<double> values;
  final Color? color;
  final bool fill;
  final double strokeWidth;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final line = color ?? context.factoryColors.primary;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparklinePainter(values, line, fill, strokeWidth)),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color, this.fill, this.strokeWidth);

  final List<double> values;
  final Color color;
  final bool fill;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1.0 : (hi - lo);
    final inset = strokeWidth;
    final h = size.height - inset * 2;
    final dx = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = inset + h - ((values[i] - lo) / span) * h;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color || old.fill != fill || old.strokeWidth != strokeWidth;
}
