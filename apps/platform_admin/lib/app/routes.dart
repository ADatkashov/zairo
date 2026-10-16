/// Every area of the console as a URL — a deep link on mobile / desktop and a
/// browser address on web. The order of [consoleBranchPaths] is the branch
/// order of the shell.
abstract final class ConsoleRoutes {
  static const login = '/login';
  static const splash = '/splash';
  static const dashboard = '/dashboard';

  /// A sub-page of the Dashboard area (it keeps Dashboard selected in the shell).
  static const reports = '/dashboard/reports';
  static const businesses = '/businesses';
  static const catalog = '/catalog';
  static const cities = '/cities';
  static const ads = '/ads';
  static const reviews = '/reviews';
  static const finance = '/finance';
  static const activity = '/activity';
  static const staff = '/staff';
  static const settings = '/settings';

  /// Phone-only: the list of areas that don't fit the bottom bar.
  static const more = '/more';
}

const consoleBranchPaths = [
  ConsoleRoutes.dashboard, // 0
  ConsoleRoutes.businesses, // 1
  ConsoleRoutes.catalog, // 2
  ConsoleRoutes.cities, // 3
  ConsoleRoutes.ads, // 4
  ConsoleRoutes.reviews, // 5
  ConsoleRoutes.finance, // 6
  ConsoleRoutes.activity, // 7
  ConsoleRoutes.staff, // 8
  ConsoleRoutes.settings, // 9
  ConsoleRoutes.more, // 10
];

/// Branch indexes the phone's bottom bar shows (two, the "+", two); the last
/// tab is "More". Catalog is reached through the "+" and "More".
const phoneTabBranches = [0, 1, 6, 10];

/// Areas a phone reaches through "More".
const moreBranches = {2, 3, 4, 5, 7, 8, 9};
