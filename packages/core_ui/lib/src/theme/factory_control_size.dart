/// Target heights for buttons and inputs. Not yet wired into
/// `factory_theme.dart` (its button/input styles currently derive height
/// from padding) — these are the values Phase 4's `FactoryButton` /
/// `FactoryTextField` components should build to, so every control lands on
/// the same three heights instead of each screen picking its own.
class FactoryButtonHeight {
  const FactoryButtonHeight._();

  static const double sm = 36;
  static const double md = 48;
  static const double lg = 56;
}

/// `md` matches [FactoryButtonHeight.md] so a text field sitting next to a
/// button in the same row lines up without extra alignment work.
class FactoryInputHeight {
  const FactoryInputHeight._();

  static const double sm = 40;
  static const double md = 48;
  static const double lg = 56;
}
