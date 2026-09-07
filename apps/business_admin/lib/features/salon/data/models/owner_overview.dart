/// Aggregate of [DashboardMetrics] across every business an owner manages —
/// backs the Dashboard's gradient overview hero (Business Admin Redesign
/// board, 2026-09-05). Summed client-side from the existing per-provider
/// dashboard endpoint rather than a new backend aggregate, since an owner
/// manages at most a handful of businesses (see Subscription.limits).
class OwnerOverview {
  final double totalRevenue;
  final int totalBookings;
  final int totalCustomers;
  final int businessCount;
  final String? currency;

  const OwnerOverview({
    required this.totalRevenue,
    required this.totalBookings,
    required this.totalCustomers,
    required this.businessCount,
    this.currency,
  });
}
