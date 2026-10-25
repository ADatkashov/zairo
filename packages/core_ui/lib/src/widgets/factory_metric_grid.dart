import 'package:flutter/material.dart';

import '../theme/factory_spacing.dart';

/// Lays dashboard cards out in as many equal columns as fit ([minTileWidth],
/// at most [maxColumns]) and widens the cards of an incomplete last row to fill
/// it — three cards on a two-column phone become two plus one full-width,
/// not two plus a hole.
///
/// With [equalHeight] the cards of a row are stretched to the tallest one, so a
/// row of chart cards with legends of different lengths still lines up. The
/// cards then must not contain a `LayoutBuilder` (a row's height is measured
/// before it is laid out).
class FactoryMetricGrid extends StatelessWidget {
  const FactoryMetricGrid({
    super.key,
    required this.children,
    this.minTileWidth = 150,
    this.maxColumns = 4,
    this.spacing = FactorySpacing.space3,
    this.equalHeight = false,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;
  final bool equalHeight;

  /// How many columns fit in [width]. Public so the rule can be tested without
  /// laying the grid out.
  static int columnsFor(double width, {required double minTileWidth, required int maxColumns, required double spacing}) {
    final fit = ((width + spacing) / (minTileWidth + spacing)).floor();
    return fit.clamp(1, maxColumns);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          minTileWidth: minTileWidth,
          maxColumns: maxColumns,
          spacing: spacing,
        );
        double widthFor(int cellsInRow) => (constraints.maxWidth - spacing * (cellsInRow - 1)) / cellsInRow;

        if (equalHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var start = 0; start < children.length; start += columns) ...[
                if (start > 0) SizedBox(height: spacing),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = start; i < start + columns && i < children.length; i++) ...[
                        if (i > start) SizedBox(width: spacing),
                        Expanded(child: children[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        }

        final lastRowCount = children.length % columns;
        final lastRowStart = lastRowCount == 0 ? children.length : children.length - lastRowCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < children.length; i++)
              SizedBox(width: widthFor(i >= lastRowStart ? lastRowCount : columns), child: children[i]),
          ],
        );
      },
    );
  }
}
