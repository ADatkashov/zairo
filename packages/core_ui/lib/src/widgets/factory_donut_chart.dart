import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/factory_colors.dart';
import '../theme/factory_spacing.dart';
import '../theme/factory_typography.dart';

/// One slice of a [FactoryDonutChart]. [valueLabel] is the already-formatted
/// figure shown in the legend (money, a count) — the chart only needs
/// [value] for proportions. A null [color] takes the next hue of the palette.
class FactoryChartSegment {
  const FactoryChartSegment({required this.label, required this.value, required this.valueLabel, this.color});

  final String label;
  final double value;
  final String valueLabel;
  final Color? color;
}

/// A ring chart with a total in the middle and a legend beside it (stacked
/// below it when [stacked] or when there is no room). Slices with a zero or
/// negative value are dropped; with nothing left it draws an empty track.
class FactoryDonutChart extends StatelessWidget {
  const FactoryDonutChart({
    super.key,
    required this.segments,
    required this.centerLabel,
    this.centerCaption,
    this.size = 132,
    this.stacked = false,
    this.semanticLabel,
  });

  final List<FactoryChartSegment> segments;

  /// Big text inside the ring (usually the formatted total).
  final String centerLabel;
  final String? centerCaption;
  final double size;
  final bool stacked;
  final String? semanticLabel;

  static List<Color> palette(FactoryColors colors) => [
    colors.primary,
    colors.accent,
    colors.lavender,
    colors.coral,
    colors.mint,
    colors.info,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final hues = palette(colors);
    final visible = [
      for (final s in segments)
        if (s.value > 0) s,
    ];
    final resolved = [for (var i = 0; i < visible.length; i++) visible[i].color ?? hues[i % hues.length]];

    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              values: [for (final s in visible) s.value],
              colors: resolved,
              track: colors.surfaceAlt,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size * 0.2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerLabel, style: FactoryTypography.mono(size: 16, weight: FontWeight.w600, color: colors.text)),
                  if (centerCaption != null)
                    Text(centerCaption!, style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: resolved[i], shape: BoxShape.circle)),
                const SizedBox(width: FactorySpacing.space2),
                Expanded(child: Text(visible[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall)),
                const SizedBox(width: FactorySpacing.space2),
                Text(
                  visible[i].valueLabel,
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );

    return Semantics(
      label: semanticLabel,
      container: semanticLabel != null,
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: ring), const SizedBox(height: FactorySpacing.space3), legend])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [ring, const SizedBox(width: FactorySpacing.space4), Expanded(child: legend)],
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colors, required this.track});

  final List<double> values;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.16;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.shortestSide - stroke) / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    // A hairline gap between slices; a lone slice is a full ring, no gap.
    final gap = values.length > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(rect, start + gap / 2, math.max(sweep - gap, 0.001), false, paint..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values || old.colors != colors || old.track != track;
}
