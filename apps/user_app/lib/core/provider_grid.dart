import 'package:flutter/widgets.dart';

/// Width / height of a provider card in a two-column grid. Taller on a narrow
/// phone (the cards get narrow, so their text wraps more) and with a larger
/// system font, so the card's content always fits instead of overflowing.
double providerGridAspectRatio(BuildContext context) {
  final media = MediaQuery.of(context);
  final base = media.size.width < 360 ? 0.64 : 0.78;
  return base / media.textScaler.scale(1).clamp(1.0, 2.0);
}

/// Columns for a grid of vertical provider cards at the current width: two on
/// a phone, more as the screen widens so cards keep a phone-like width.
int providerGridColumns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1200) return 4;
  if (width >= 768) return 3;
  return 2;
}

/// Grid delegate for vertical provider cards. On a phone the card's height
/// follows its width (see [providerGridAspectRatio]). On a wider screen a
/// width-driven height makes the cards grow ever taller while the photo stays
/// 128px, leaving the lower half of every card empty — so there the height is
/// fixed: the photo plus room for the text block, scaled with the system font.
SliverGridDelegate providerGridDelegate(
  BuildContext context, {
  required int crossAxisCount,
  required double spacing,
}) {
  final media = MediaQuery.of(context);
  if (media.size.width < 600) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: providerGridAspectRatio(context),
    );
  }
  const photoHeight = 128.0;
  const textBlockHeight = 104.0;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
    mainAxisExtent: photoHeight + textBlockHeight * media.textScaler.scale(1).clamp(1.0, 2.0),
  );
}
