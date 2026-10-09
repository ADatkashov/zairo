import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/admin_booking.dart';
import '../../data/models/admin_payout.dart';
import '../../data/models/admin_provider.dart';
import '../../data/models/admin_service.dart';
import '../../data/models/admin_slot.dart';
import '../../data/models/business_analytics.dart';
import '../../data/models/dashboard_metrics.dart';
import '../../data/models/owner_overview.dart';
import '../../data/models/schedule_entry.dart';
import '../../data/salon_admin_api.dart';

final salonAdminApiProvider = Provider<SalonAdminApi>((ref) {
  return SalonAdminApi(ref.watch(dioClientProvider));
});

final myProvidersProvider = FutureProvider.autoDispose.family<List<AdminProvider>, String>((ref, ownerUserId) {
  return ref.watch(salonAdminApiProvider).listMyProviders(ownerUserId);
});

/// Keyed by (providerId, includeInactive) — Dart records give structural
/// equality for free, so this doesn't need a hand-rolled key class.
final providerServicesProvider =
    FutureProvider.autoDispose.family<List<AdminService>, (String providerId, bool includeInactive)>((ref, key) {
  return ref.watch(salonAdminApiProvider).listServices(key.$1, includeInactive: key.$2);
});

/// "Show removed" toggle for the services section, per salon.
final showInactiveServicesProvider = StateProvider.autoDispose.family<bool, String>((ref, providerId) => false);

final providerSlotsProvider = FutureProvider.autoDispose.family<List<AdminSlot>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listSlots(providerId);
});

final providerBookingsProvider = FutureProvider.autoDispose.family<List<AdminBooking>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listBookings(providerId);
});

/// Settlement visibility — see ADR-0007. Ordered most-recent first by the
/// backend; this provider does no re-sorting/filtering of its own.
final providerPayoutsProvider = FutureProvider.autoDispose.family<List<AdminPayout>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).listPayouts(providerId);
});

final providerDashboardMetricsProvider =
    FutureProvider.autoDispose.family<DashboardMetrics, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).fetchDashboardMetrics(providerId);
});

/// Sums [DashboardMetrics] across every business [ownerUserId] manages, for
/// the Dashboard's overview hero. Reuses [myProvidersProvider]'s cached list
/// rather than re-fetching it.
final ownerOverviewProvider = FutureProvider.autoDispose.family<OwnerOverview, String>((ref, ownerUserId) async {
  final api = ref.watch(salonAdminApiProvider);
  final providers = await ref.watch(myProvidersProvider(ownerUserId).future);
  final metrics = await Future.wait(providers.map((p) => api.fetchDashboardMetrics(p.id)));
  double totalRevenue = 0;
  int totalBookings = 0;
  int totalCustomers = 0;
  String? currency;
  for (final m in metrics) {
    totalRevenue += m.totalRevenue;
    totalBookings += m.totalBookings;
    totalCustomers += m.totalCustomers;
    currency ??= m.currency;
  }
  return OwnerOverview(
    totalRevenue: totalRevenue,
    totalBookings: totalBookings,
    totalCustomers: totalCustomers,
    businessCount: providers.length,
    currency: currency,
  );
});

/// A reporting period's bounds, in UTC — the Business Intelligence
/// Dashboard's single source of truth for "which window every section's
/// metrics are scoped to" (see BusinessAnalyticsScreen). Dart records give
/// structural equality for free, so this doubles as a family key.
typedef AnalyticsRange = (DateTime from, DateTime to);

/// Keyed by (providerId, range) -- every Business Analytics section below
/// re-fetches whenever either changes.
final businessAnalyticsOverviewProvider =
    FutureProvider.autoDispose.family<BusinessAnalyticsOverview, (String providerId, AnalyticsRange range)>((
  ref,
  key,
) {
  return ref.watch(salonAdminApiProvider).fetchAnalyticsOverview(key.$1, from: key.$2.$1, to: key.$2.$2);
});

final businessAnalyticsRevenueProvider =
    FutureProvider.autoDispose.family<BusinessAnalyticsRevenue, (String providerId, AnalyticsRange range)>((
  ref,
  key,
) {
  return ref.watch(salonAdminApiProvider).fetchAnalyticsRevenue(key.$1, from: key.$2.$1, to: key.$2.$2);
});

final businessAnalyticsBookingsProvider =
    FutureProvider.autoDispose.family<BusinessAnalyticsBookings, (String providerId, AnalyticsRange range)>((
  ref,
  key,
) {
  return ref.watch(salonAdminApiProvider).fetchAnalyticsBookings(key.$1, from: key.$2.$1, to: key.$2.$2);
});

final businessAnalyticsSmartFillProvider =
    FutureProvider.autoDispose.family<SmartFillPerformance, (String providerId, AnalyticsRange range)>((ref, key) {
  return ref.watch(salonAdminApiProvider).fetchAnalyticsSmartFill(key.$1, from: key.$2.$1, to: key.$2.$2);
});

final businessAnalyticsCustomersProvider =
    FutureProvider.autoDispose.family<BusinessAnalyticsCustomers, (String providerId, AnalyticsRange range)>((
  ref,
  key,
) {
  return ref.watch(salonAdminApiProvider).fetchAnalyticsCustomers(key.$1, from: key.$2.$1, to: key.$2.$2);
});

/// Not range-scoped on the server -- "what needs attention right now".
final businessAnalyticsActionsProvider =
    FutureProvider.autoDispose.family<BusinessActionCenter, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).fetchAnalyticsActions(providerId);
});

/// The Action Center's Smart Fill drill-down screen's data source.
final activeSmartFillCampaignsProvider =
    FutureProvider.autoDispose.family<List<SmartFillCampaignSummary>, String>((ref, providerId) {
  return ref.watch(salonAdminApiProvider).fetchActiveSmartFillCampaigns(providerId);
});

/// The Action Center's rebook-opportunity/retention-risk drill-down
/// screen's data source, keyed by (providerId, retentionStatus filter).
final customerListProvider = FutureProvider.autoDispose
    .family<List<CustomerListItem>, (String providerId, CustomerRetentionStatus? retentionStatus)>((ref, key) {
  return ref.watch(salonAdminApiProvider).fetchCustomerList(key.$1, retentionStatus: key.$2);
});

/// Bookings across every business [ownerUserId] manages whose slot starts in
/// [from, to) (local wall-clock bounds, sent to the backend as UTC), soonest
/// first, cancelled ones left out.
Future<List<AgendaItem>> _loadAgenda(Ref ref, String ownerUserId, DateTime from, DateTime to) async {
  final api = ref.watch(salonAdminApiProvider);
  final providers = await ref.watch(myProvidersProvider(ownerUserId).future);

  final perProvider = await Future.wait(providers.map((p) async {
    final results = await Future.wait([
      api.fetchSchedule(p.id, from: from, to: to),
      api.listServices(p.id, includeInactive: true),
    ]);
    final titles = {for (final s in results[1] as List<AdminService>) s.id: s.title};
    return [
      for (final entry in results[0] as List<ScheduleEntry>)
        if (entry.status != 'CANCELLED')
          AgendaItem(entry: entry, providerId: p.id, providerName: p.name, serviceTitle: titles[entry.serviceId] ?? ''),
    ];
  }));

  return [for (final items in perProvider) ...items]..sort((a, b) => a.entry.startsAt.compareTo(b.entry.startsAt));
}

/// Today's bookings: the device's local calendar day.
final ownerTodayAgendaProvider = FutureProvider.autoDispose.family<List<AgendaItem>, String>((ref, ownerUserId) {
  final now = DateTime.now();
  return _loadAgenda(ref, ownerUserId, DateTime(now.year, now.month, now.day), DateTime(now.year, now.month, now.day + 1));
});

/// The 7 local days starting at [weekStart] (a local midnight).
final ownerWeekAgendaProvider =
    FutureProvider.autoDispose.family<List<AgendaItem>, (String ownerUserId, DateTime weekStart)>((ref, key) {
  final start = key.$2;
  return _loadAgenda(ref, key.$1, start, DateTime(start.year, start.month, start.day + 7));
});
