import 'package:core_network/core_network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/campaign_center_api.dart';
import '../../data/models/campaign.dart';

final campaignCenterApiProvider = Provider<CampaignCenterApi>((ref) {
  return CampaignCenterApi(ref.watch(dioClientProvider));
});

/// The Campaign Center list screen's filter set -- everything
/// GET .../campaigns accepts besides pagination, which the screen tracks
/// separately as it accumulates pages. A plain class (not a bare record)
/// so the screen has one place to reach for `copyWith` when a chip/field
/// changes; `==`/`hashCode` are still structural, so it works as a
/// [FutureProvider] family key exactly like a record would.
class CampaignFilters {
  final CampaignType? type;
  final CampaignStatus? status;
  final String? serviceId;
  final String? employeeId;
  final DateTime? from;
  final DateTime? to;
  final String? search;
  final bool newestFirst;

  const CampaignFilters({
    this.type,
    this.status,
    this.serviceId,
    this.employeeId,
    this.from,
    this.to,
    this.search,
    this.newestFirst = true,
  });

  CampaignFilters copyWith({
    CampaignType? type,
    bool clearType = false,
    CampaignStatus? status,
    bool clearStatus = false,
    String? serviceId,
    bool clearServiceId = false,
    String? employeeId,
    bool clearEmployeeId = false,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
    String? search,
    bool clearSearch = false,
    bool? newestFirst,
  }) {
    return CampaignFilters(
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      serviceId: clearServiceId ? null : (serviceId ?? this.serviceId),
      employeeId: clearEmployeeId ? null : (employeeId ?? this.employeeId),
      from: clearRange ? null : (from ?? this.from),
      to: clearRange ? null : (to ?? this.to),
      search: clearSearch ? null : (search ?? this.search),
      newestFirst: newestFirst ?? this.newestFirst,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CampaignFilters &&
      other.type == type &&
      other.status == status &&
      other.serviceId == serviceId &&
      other.employeeId == employeeId &&
      other.from == from &&
      other.to == to &&
      other.search == search &&
      other.newestFirst == newestFirst;

  @override
  int get hashCode => Object.hash(type, status, serviceId, employeeId, from, to, search, newestFirst);
}

/// One page of the campaign list, keyed by (providerId, filters, page).
/// [CampaignCenterScreen] accumulates successive pages itself (see its
/// pagination handling) rather than this provider owning that state, so a
/// filter change cleanly invalidates only the pages it affects.
final campaignListProvider =
    FutureProvider.autoDispose.family<CampaignListResponse, (String providerId, CampaignFilters filters, int page)>((
  ref,
  key,
) {
  final (providerId, filters, page) = key;
  return ref.watch(campaignCenterApiProvider).fetchCampaigns(
        providerId,
        type: filters.type,
        status: filters.status,
        serviceId: filters.serviceId,
        employeeId: filters.employeeId,
        from: filters.from,
        to: filters.to,
        search: filters.search,
        page: page,
        newestFirst: filters.newestFirst,
      );
});

final campaignStatsProvider = FutureProvider.autoDispose.family<CampaignStatsResponse, String>((ref, providerId) {
  return ref.watch(campaignCenterApiProvider).fetchStats(providerId);
});

final smartActionsProvider = FutureProvider.autoDispose.family<SmartActionsResponse, String>((ref, providerId) {
  return ref.watch(campaignCenterApiProvider).fetchSmartActions(providerId);
});

/// A single campaign's identity across the detail screen's calls -- the
/// provider a campaign belongs to never changes for its lifetime, so this
/// doubles as the key for both [campaignDetailProvider] and
/// [campaignTimelineProvider].
typedef CampaignKey = (String providerId, CampaignType type, String campaignId);

final campaignDetailProvider = FutureProvider.autoDispose.family<CampaignDto, CampaignKey>((ref, key) {
  return ref.watch(campaignCenterApiProvider).fetchCampaignDetail(key.$1, key.$2, key.$3);
});

final campaignTimelineProvider = FutureProvider.autoDispose.family<CampaignTimelineResponse, CampaignKey>((
  ref,
  key,
) {
  return ref.watch(campaignCenterApiProvider).fetchTimeline(key.$1, key.$2, key.$3);
});

/// Invalidates every provider a campaign action (pause/resume/cancel/retry)
/// could have changed the answer to -- the detail screen's own key, plus
/// every cached list/stats/smart-actions page for this provider, so
/// navigating back to the list or the Smart Action Center never shows stale
/// data. Called by the detail screen after a successful mutation (see the
/// billing feature's write-then-invalidate pattern, which this mirrors).
void invalidateCampaignData(WidgetRef ref, CampaignKey key) {
  ref.invalidate(campaignDetailProvider(key));
  ref.invalidate(campaignTimelineProvider(key));
  ref.invalidate(campaignListProvider);
  ref.invalidate(campaignStatsProvider(key.$1));
  ref.invalidate(smartActionsProvider(key.$1));
}
