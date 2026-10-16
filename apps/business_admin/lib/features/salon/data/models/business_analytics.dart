/// Mirrors backend's BusinessAnalyticsDtos
/// (backend/provider-insights/.../BusinessAnalyticsDtos.java) — the
/// Business Intelligence Dashboard's response shapes. Every field is real
/// data composed from Booking/Payment/AvailabilitySlot/Smart Fill/Revenue
/// Engine/Customer Intelligence; nullable fields (e.g. utilization,
/// currency) mean "not available for this period", never a placeholder.
library;

class BusinessAnalyticsOverview {
  final int totalBookings;
  final int completedBookings;
  final int upcomingBookings;
  final int cancelledBookings;
  final int noShowBookings;
  final double cancellationRate;
  final double noShowRate;
  final double totalRevenue;
  final double? averageBookingValue;
  final String? currency;
  final double? utilization;
  final double returningCustomerRate;
  final double revenueRecovered;
  final String? revenueRecoveredCurrency;

  const BusinessAnalyticsOverview({
    required this.totalBookings,
    required this.completedBookings,
    required this.upcomingBookings,
    required this.cancelledBookings,
    required this.noShowBookings,
    required this.cancellationRate,
    required this.noShowRate,
    required this.totalRevenue,
    this.averageBookingValue,
    this.currency,
    this.utilization,
    required this.returningCustomerRate,
    required this.revenueRecovered,
    this.revenueRecoveredCurrency,
  });

  factory BusinessAnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return BusinessAnalyticsOverview(
      totalBookings: json['totalBookings'] as int,
      completedBookings: json['completedBookings'] as int,
      upcomingBookings: json['upcomingBookings'] as int,
      cancelledBookings: json['cancelledBookings'] as int,
      noShowBookings: json['noShowBookings'] as int,
      cancellationRate: (json['cancellationRate'] as num).toDouble(),
      noShowRate: (json['noShowRate'] as num).toDouble(),
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      averageBookingValue: (json['averageBookingValue'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      utilization: (json['utilization'] as num?)?.toDouble(),
      returningCustomerRate: (json['returningCustomerRate'] as num).toDouble(),
      revenueRecovered: (json['revenueRecovered'] as num).toDouble(),
      revenueRecoveredCurrency: json['revenueRecoveredCurrency'] as String?,
    );
  }
}

class DailyAmount {
  final DateTime date;
  final double amount;

  const DailyAmount({required this.date, required this.amount});

  factory DailyAmount.fromJson(Map<String, dynamic> json) {
    return DailyAmount(date: DateTime.parse(json['date'] as String), amount: (json['amount'] as num).toDouble());
  }
}

class RevenueByService {
  final String serviceId;
  final String? title;
  final double amount;
  final int bookingCount;

  const RevenueByService({required this.serviceId, this.title, required this.amount, required this.bookingCount});

  factory RevenueByService.fromJson(Map<String, dynamic> json) {
    return RevenueByService(
      serviceId: json['serviceId'] as String,
      title: json['title'] as String?,
      amount: (json['amount'] as num).toDouble(),
      bookingCount: (json['bookingCount'] as num).toInt(),
    );
  }
}

class RevenueByStaff {
  final String? employeeId;
  final double amount;
  final int bookingCount;

  const RevenueByStaff({this.employeeId, required this.amount, required this.bookingCount});

  factory RevenueByStaff.fromJson(Map<String, dynamic> json) {
    return RevenueByStaff(
      employeeId: json['employeeId'] as String?,
      amount: (json['amount'] as num).toDouble(),
      bookingCount: (json['bookingCount'] as num).toInt(),
    );
  }
}

class BusinessAnalyticsRevenue {
  final double totalRevenue;
  final String? currency;
  final double? averageBookingValue;
  final List<DailyAmount> revenueByDay;
  final List<RevenueByService> revenueByService;
  final List<RevenueByStaff> revenueByStaff;
  final double revenueRecovered;
  final String? revenueRecoveredCurrency;

  const BusinessAnalyticsRevenue({
    required this.totalRevenue,
    this.currency,
    this.averageBookingValue,
    required this.revenueByDay,
    required this.revenueByService,
    required this.revenueByStaff,
    required this.revenueRecovered,
    this.revenueRecoveredCurrency,
  });

  factory BusinessAnalyticsRevenue.fromJson(Map<String, dynamic> json) {
    return BusinessAnalyticsRevenue(
      totalRevenue: (json['totalRevenue'] as num).toDouble(),
      currency: json['currency'] as String?,
      averageBookingValue: (json['averageBookingValue'] as num?)?.toDouble(),
      revenueByDay: (json['revenueByDay'] as List<dynamic>)
          .map((e) => DailyAmount.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenueByService: (json['revenueByService'] as List<dynamic>)
          .map((e) => RevenueByService.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenueByStaff: (json['revenueByStaff'] as List<dynamic>)
          .map((e) => RevenueByStaff.fromJson(e as Map<String, dynamic>))
          .toList(),
      revenueRecovered: (json['revenueRecovered'] as num).toDouble(),
      revenueRecoveredCurrency: json['revenueRecoveredCurrency'] as String?,
    );
  }
}

class DailyBookingCount {
  final DateTime date;
  final int total;
  final int completed;
  final int cancelled;
  final int noShow;

  const DailyBookingCount({
    required this.date,
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.noShow,
  });

  factory DailyBookingCount.fromJson(Map<String, dynamic> json) {
    return DailyBookingCount(
      date: DateTime.parse(json['date'] as String),
      total: (json['total'] as num).toInt(),
      completed: (json['completed'] as num).toInt(),
      cancelled: (json['cancelled'] as num).toInt(),
      noShow: (json['noShow'] as num).toInt(),
    );
  }
}

class BusinessAnalyticsBookings {
  final int totalBookings;
  final int completedBookings;
  final int upcomingBookings;
  final int cancelledBookings;
  final int noShowBookings;
  final double cancellationRate;
  final double noShowRate;
  final double repeatBookingRate;
  final List<DailyBookingCount> trend;

  const BusinessAnalyticsBookings({
    required this.totalBookings,
    required this.completedBookings,
    required this.upcomingBookings,
    required this.cancelledBookings,
    required this.noShowBookings,
    required this.cancellationRate,
    required this.noShowRate,
    required this.repeatBookingRate,
    required this.trend,
  });

  factory BusinessAnalyticsBookings.fromJson(Map<String, dynamic> json) {
    return BusinessAnalyticsBookings(
      totalBookings: json['totalBookings'] as int,
      completedBookings: json['completedBookings'] as int,
      upcomingBookings: json['upcomingBookings'] as int,
      cancelledBookings: json['cancelledBookings'] as int,
      noShowBookings: json['noShowBookings'] as int,
      cancellationRate: (json['cancellationRate'] as num).toDouble(),
      noShowRate: (json['noShowRate'] as num).toDouble(),
      repeatBookingRate: (json['repeatBookingRate'] as num).toDouble(),
      trend: (json['trend'] as List<dynamic>).map((e) => DailyBookingCount.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class FavouriteService {
  final String serviceId;
  final String? title;
  final int customerCount;

  const FavouriteService({required this.serviceId, this.title, required this.customerCount});

  factory FavouriteService.fromJson(Map<String, dynamic> json) {
    return FavouriteService(
      serviceId: json['serviceId'] as String,
      title: json['title'] as String?,
      customerCount: (json['customerCount'] as num).toInt(),
    );
  }
}

class BusinessAnalyticsCustomers {
  final int totalCustomers;
  final int activeCustomers;
  final int returningCustomers;
  final int newCustomers;
  final int dueForRebooking;
  final int atRiskCustomers;
  final int inactiveCustomers;
  final double? averageVisitIntervalDays;
  final double? averageCustomerValue;
  final String? currency;
  final List<FavouriteService> favouriteServices;

  const BusinessAnalyticsCustomers({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.returningCustomers,
    required this.newCustomers,
    required this.dueForRebooking,
    required this.atRiskCustomers,
    required this.inactiveCustomers,
    this.averageVisitIntervalDays,
    this.averageCustomerValue,
    this.currency,
    required this.favouriteServices,
  });

  factory BusinessAnalyticsCustomers.fromJson(Map<String, dynamic> json) {
    return BusinessAnalyticsCustomers(
      totalCustomers: json['totalCustomers'] as int,
      activeCustomers: json['activeCustomers'] as int,
      returningCustomers: json['returningCustomers'] as int,
      newCustomers: json['newCustomers'] as int,
      dueForRebooking: json['dueForRebooking'] as int,
      atRiskCustomers: json['atRiskCustomers'] as int,
      inactiveCustomers: json['inactiveCustomers'] as int,
      averageVisitIntervalDays: (json['averageVisitIntervalDays'] as num?)?.toDouble(),
      averageCustomerValue: (json['averageCustomerValue'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      favouriteServices: (json['favouriteServices'] as List<dynamic>)
          .map((e) => FavouriteService.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Mirrors backend's SmartFillDtos.SmartFillPerformanceResponse
/// (backend/smart-fill/.../SmartFillDtos.java).
class SmartFillPerformance {
  final int slotsFreed;
  final int campaignsCreated;
  final int candidatesNotified;
  final int offersViewed;
  final int slotsRecovered;
  final double recoveryRate;
  final double recoveredRevenue;
  final String? currency;

  const SmartFillPerformance({
    required this.slotsFreed,
    required this.campaignsCreated,
    required this.candidatesNotified,
    required this.offersViewed,
    required this.slotsRecovered,
    required this.recoveryRate,
    required this.recoveredRevenue,
    this.currency,
  });

  factory SmartFillPerformance.fromJson(Map<String, dynamic> json) {
    return SmartFillPerformance(
      slotsFreed: (json['slotsFreed'] as num).toInt(),
      campaignsCreated: (json['campaignsCreated'] as num).toInt(),
      candidatesNotified: (json['candidatesNotified'] as num).toInt(),
      offersViewed: (json['offersViewed'] as num).toInt(),
      slotsRecovered: (json['slotsRecovered'] as num).toInt(),
      recoveryRate: (json['recoveryRate'] as num).toDouble(),
      recoveredRevenue: (json['recoveredRevenue'] as num).toDouble(),
      currency: json['currency'] as String?,
    );
  }
}

/// Matches backend's BusinessAnalyticsDtos.ActionItemType — deterministic,
/// rule-based signals only. The client owns the localized copy for each
/// type; the server sends a type and a count, never pre-baked text.
enum ActionItemType {
  smartFillOpportunity,
  rebookOpportunity,
  retentionRisk,
  lowUtilization;

  static ActionItemType fromWire(String value) {
    return switch (value) {
      'SMART_FILL_OPPORTUNITY' => ActionItemType.smartFillOpportunity,
      'REBOOK_OPPORTUNITY' => ActionItemType.rebookOpportunity,
      'RETENTION_RISK' => ActionItemType.retentionRisk,
      'LOW_UTILIZATION' => ActionItemType.lowUtilization,
      _ => throw ArgumentError('Unknown ActionItemType: $value'),
    };
  }
}

class ActionItem {
  final ActionItemType type;
  final int count;

  const ActionItem({required this.type, required this.count});

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(type: ActionItemType.fromWire(json['type'] as String), count: (json['count'] as num).toInt());
  }
}

class BusinessActionCenter {
  final List<ActionItem> actions;

  const BusinessActionCenter({required this.actions});

  factory BusinessActionCenter.fromJson(Map<String, dynamic> json) {
    return BusinessActionCenter(
      actions: (json['actions'] as List<dynamic>).map((e) => ActionItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Mirrors backend's SmartFillDtos.CampaignSummary, as returned by the
/// Action Center's Smart Fill drill-down
/// (`/analytics/smart-fill/active`) -- always one of CREATED/SEARCHING/
/// NOTIFYING there, but the raw status string is kept as-is so a future
/// caller reusing this model for a resolved campaign isn't surprised.
class SmartFillCampaignSummary {
  final String campaignId;
  final String status;
  final DateTime slotStartsAt;
  final int candidatesNotified;
  final String? recoveredBookingId;

  const SmartFillCampaignSummary({
    required this.campaignId,
    required this.status,
    required this.slotStartsAt,
    required this.candidatesNotified,
    this.recoveredBookingId,
  });

  factory SmartFillCampaignSummary.fromJson(Map<String, dynamic> json) {
    return SmartFillCampaignSummary(
      campaignId: json['campaignId'] as String,
      status: json['status'] as String,
      slotStartsAt: DateTime.parse(json['slotStartsAt'] as String),
      candidatesNotified: (json['candidatesNotified'] as num).toInt(),
      recoveredBookingId: json['recoveredBookingId'] as String?,
    );
  }
}

/// Matches backend's customerintelligence.RetentionStatus — how a
/// customer's visit pattern compares to their own established cadence.
enum CustomerRetentionStatus {
  newCustomer,
  active,
  dueForRebooking,
  atRisk,
  inactive;

  static CustomerRetentionStatus fromWire(String value) {
    return switch (value) {
      'NEW' => CustomerRetentionStatus.newCustomer,
      'ACTIVE' => CustomerRetentionStatus.active,
      'DUE_FOR_REBOOKING' => CustomerRetentionStatus.dueForRebooking,
      'AT_RISK' => CustomerRetentionStatus.atRisk,
      'INACTIVE' => CustomerRetentionStatus.inactive,
      _ => throw ArgumentError('Unknown RetentionStatus: $value'),
    };
  }

  String toWire() {
    return switch (this) {
      CustomerRetentionStatus.newCustomer => 'NEW',
      CustomerRetentionStatus.active => 'ACTIVE',
      CustomerRetentionStatus.dueForRebooking => 'DUE_FOR_REBOOKING',
      CustomerRetentionStatus.atRisk => 'AT_RISK',
      CustomerRetentionStatus.inactive => 'INACTIVE',
    };
  }
}

/// Mirrors backend's BusinessAnalyticsDtos.CustomerListItem, as returned by
/// the Action Center's rebook-opportunity/retention-risk drill-down
/// (`/analytics/customers/list`).
class CustomerListItem {
  final String userId;
  final String? displayName;
  final String? email;
  final CustomerRetentionStatus retentionStatus;
  final DateTime? lastVisitAt;
  final DateTime? nextExpectedVisitAt;
  final double totalSpent;
  final String? currency;
  final String? favouriteServiceTitle;
  final int noShows;

  const CustomerListItem({
    required this.userId,
    this.displayName,
    this.email,
    required this.retentionStatus,
    this.lastVisitAt,
    this.nextExpectedVisitAt,
    required this.totalSpent,
    this.currency,
    this.favouriteServiceTitle,
    this.noShows = 0,
  });

  factory CustomerListItem.fromJson(Map<String, dynamic> json) {
    return CustomerListItem(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      retentionStatus: CustomerRetentionStatus.fromWire(json['retentionStatus'] as String),
      lastVisitAt: json['lastVisitAt'] == null ? null : DateTime.parse(json['lastVisitAt'] as String),
      nextExpectedVisitAt:
          json['nextExpectedVisitAt'] == null ? null : DateTime.parse(json['nextExpectedVisitAt'] as String),
      totalSpent: (json['totalSpent'] as num).toDouble(),
      currency: json['currency'] as String?,
      favouriteServiceTitle: json['favouriteServiceTitle'] as String?,
      noShows: (json['noShows'] as num?)?.toInt() ?? 0,
    );
  }
}
