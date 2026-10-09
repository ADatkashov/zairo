/// Every screen the app opens by URL. Use these instead of string literals:
/// `context.push(AppRoutes.provider(id), extra: result)`.
///
/// Detail screens are root-level routes (`parentNavigatorKey:
/// rootNavigatorKey`): they open full-screen above the tab shell, so the
/// floating bottom nav no longer sits on top of a screen's own bottom CTA
/// (booking, chat compose bar), and the tab underneath keeps its state.
abstract final class AppRoutes {
  static const citySelection = '/city-selection';

  /// The Search tab, optionally pre-filtered (`/search?category=beauty&q=…`).
  static String search({String? category, String? query}) {
    final params = <String, String>{
      if (category != null && category.isNotEmpty) 'category': category,
      if (query != null && query.isNotEmpty) 'q': query,
    };
    return Uri(
      path: '/search',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  /// The full category browser; pops with the picked category's `code`
  /// (`context.push<String>(AppRoutes.categories)`).
  static const categories = '/categories';

  /// "Who offers this catalog service" (ServiceCompareScreen).
  static String compare(String catalogServiceId, {required String serviceName}) =>
      _withName('/compare/$catalogServiceId', serviceName);

  static const bookings = '/bookings';
  static const editProfile = '/profile/edit';

  /// A business on a map. [distanceKm] is shown under the map when given.
  static String map({
    required String providerName,
    required double latitude,
    required double longitude,
    double? distanceKm,
  }) => Uri(
    path: '/map',
    queryParameters: {
      'name': providerName,
      'lat': '$latitude',
      'lng': '$longitude',
      if (distanceKm != null) 'distance': '$distanceKm',
    },
  ).toString();

  /// A master's portfolio (beauty vertical).
  static String portfolio(String masterId, {required String masterName}) =>
      _withName('/portfolio/$masterId', masterName);

  /// Needs a `BookingConfirmationArgs` as `extra`.
  static const bookingConfirmation = '/booking-confirmation';

  /// Pay for a booking that is still awaiting payment. Needs a
  /// `BookingPaymentArgs` as `extra`; pops with `true` once it is paid.
  static const bookingPayment = '/booking-payment';
  static const notifications = '/notifications';
  static const favorites = '/favorites';
  static const messages = '/messages';
  static const rewards = '/rewards';

  /// The staff member's own cabinet (appointments, accept/cancel, rating).
  static const staffCabinet = '/staff-cabinet';
  static const changeRequests = '/change-requests';
  static const redemptions = '/redemptions';
  static const vehicles = '/vehicles';
  static const support = '/support';
  static const about = '/about';
  static const settings = '/settings';
  static const securitySettings = '/settings/security';
  static const deleteAccount = '/settings/delete-account';

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
