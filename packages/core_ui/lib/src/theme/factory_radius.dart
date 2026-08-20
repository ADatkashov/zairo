import 'package:flutter/material.dart';

/// Radius scale — deliberately modest (12–16 on cards) so the interface
/// reads as considered rather than bubbly. Pill is reserved for chips and
/// status, never cards or dialogs.
class FactoryRadius {
  const FactoryRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlRadius = BorderRadius.all(Radius.circular(xl));
  static const StadiumBorder pill = StadiumBorder();
}
