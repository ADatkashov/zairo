import 'package:flutter/widgets.dart';

/// Width / height of a provider card in a two-column grid. Taller on a narrow
/// phone (the cards get narrow, so their text wraps more) and with a larger
/// system font, so the card's content always fits instead of overflowing.
double providerGridAspectRatio(BuildContext context) {
  final media = MediaQuery.of(context);
  final base = media.size.width < 360 ? 0.64 : 0.78;
  return base / media.textScaler.scale(1).clamp(1.0, 2.0);
}
