/// Shared initials formatter for [FactoryAvatar] fallbacks — used by the
/// profile header and by master/mechanic selection rows, so "AK" for
/// "Aigerim K." always comes out the same way regardless of which screen
/// is showing it.
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
