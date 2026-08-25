/// Avatar diameter scale. [md] matches `FactoryAvatar`'s current default
/// (40) so adopting these tokens is a no-op for existing call sites; [lg]
/// and [xl] cover the bigger hero avatars a provider/profile header needs.
class FactoryAvatarSize {
  const FactoryAvatarSize._();

  static const double xs = 24;
  static const double sm = 32;
  static const double md = 40;
  static const double lg = 64;
  static const double xl = 96;
}
