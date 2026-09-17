/// Mirrors backend's LoyaltyAdminDtos.OverviewResponse -- six cheap
/// aggregate numbers for the Loyalty dashboard tile/screen. Every field is a
/// plain count, safe to poll/refresh on pull-to-refresh.
class LoyaltyOverview {
  final int totalMembers;
  final int activeMembers;
  final int totalPointsIssued;
  final int totalPointsRedeemed;
  final int outstandingPointsLiability;
  final int rewardsRedeemed;

  const LoyaltyOverview({
    required this.totalMembers,
    required this.activeMembers,
    required this.totalPointsIssued,
    required this.totalPointsRedeemed,
    required this.outstandingPointsLiability,
    required this.rewardsRedeemed,
  });

  factory LoyaltyOverview.fromJson(Map<String, dynamic> json) {
    return LoyaltyOverview(
      totalMembers: (json['totalMembers'] as num).toInt(),
      activeMembers: (json['activeMembers'] as num).toInt(),
      totalPointsIssued: (json['totalPointsIssued'] as num).toInt(),
      totalPointsRedeemed: (json['totalPointsRedeemed'] as num).toInt(),
      outstandingPointsLiability: (json['outstandingPointsLiability'] as num).toInt(),
      rewardsRedeemed: (json['rewardsRedeemed'] as num).toInt(),
    );
  }
}
