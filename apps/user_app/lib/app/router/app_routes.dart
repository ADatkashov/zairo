/// Every screen the app opens by URL. Use these instead of string literals:
/// `context.push(AppRoutes.provider(id), extra: result)`.
///
/// Detail screens are root-level routes (`parentNavigatorKey:
/// rootNavigatorKey`): they open full-screen above the tab shell, so the
/// floating bottom nav no longer sits on top of a screen's own bottom CTA
/// (booking, chat compose bar), and the tab underneath keeps its state.
abstract final class AppRoutes {
  static const citySelection = '/city-selection';
  static const notifications = '/notifications';
  static const favorites = '/favorites';
  static const messages = '/messages';
  static const rewards = '/rewards';
  static const redemptions = '/redemptions';
  static const vehicles = '/vehicles';
  static const support = '/support';
  static const about = '/about';
  static const settings = '/settings';
  static const securitySettings = '/settings/security';

  /// [extra] may carry the already-loaded `ProviderSearchResult`; without it
  /// (deep link, web refresh) the screen looks the provider up by id.
  static String provider(String providerId) => '/provider/$providerId';

  static String chat(String providerId, {String? providerName}) =>
      _withName('/messages/$providerId', providerName);

  static String loyalty(String providerId, {String? providerName}) =>
      _withName('/loyalty/$providerId', providerName);

  // `Uri(queryParameters: {})` would leave a dangling `?`.
  static String _withName(String path, String? name) => Uri(
    path: path,
    queryParameters: name == null || name.isEmpty ? null : {'name': name},
  ).toString();
}
