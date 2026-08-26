import 'package:flutter/widgets.dart';

/// Caps content width and centers it — the design system's own page
/// (the artifact itself) uses 1180px for the same reason: past a certain
/// width, a single column of cards/text reads as neglected-desktop rather
/// than considered, not as "more space used well". Wrap the scrollable
/// body of a screen in this once it needs to look right past mobile/tablet
/// width, not just survive it.
class FactoryPageWidth extends StatelessWidget {
  const FactoryPageWidth({super.key, required this.child, this.maxWidth = 1180});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
