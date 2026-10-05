/// Every top-level area of the owner app, as a URL (works as a deep link and as
/// a browser address on web). The paths double as the branch order of the
/// owner shell — see `adminBranchPaths`.
abstract final class AdminRoutes {
  static const dashboard = '/dashboard';
  static const messages = '/messages';
  static const campaigns = '/campaigns';
  static const loyalty = '/loyalty';
  static const automation = '/automation';
  static const billing = '/billing';
  static const settings = '/settings';

  /// Phone-only: the list of areas that don't fit the bottom bar.
  static const more = '/more';
}

/// Branch order of the owner shell. Indexes 0–6 are the sidebar destinations
/// (desktop / tablet); [AdminRoutes.more] is last and only phones show it.
const adminBranchPaths = [
  AdminRoutes.dashboard,
  AdminRoutes.messages,
  AdminRoutes.campaigns,
  AdminRoutes.loyalty,
  AdminRoutes.automation,
  AdminRoutes.billing,
  AdminRoutes.settings,
  AdminRoutes.more,
];
