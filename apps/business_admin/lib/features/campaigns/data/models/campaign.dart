/// Mirrors backend's Campaign Center DTOs (backend/campaign-center/...) —
/// the unified read/write surface over Smart Fill, Rebook and Reactivation
/// campaigns. Every field matches the backend JSON shape exactly; nullable
/// fields mean "not applicable to this campaign type" or "not known yet",
/// never a fabricated placeholder. The Flutter side never re-derives
/// [CampaignDto.status]/[CampaignDto.availableActions] from raw fields —
/// those are server-computed and rendered as given.
library;

/// The three campaign engines Campaign Center unifies behind one API.
enum CampaignType {
  smartFill,
  rebook,
  reactivation;

  static CampaignType fromWire(String value) => switch (value) {
        'SMART_FILL' => CampaignType.smartFill,
        'REBOOK' => CampaignType.rebook,
        'REACTIVATION' => CampaignType.reactivation,
        _ => throw ArgumentError('Unknown CampaignType: $value'),
      };

  String toWire() => switch (this) {
        CampaignType.smartFill => 'SMART_FILL',
        CampaignType.rebook => 'REBOOK',
        CampaignType.reactivation => 'REACTIVATION',
      };
}

/// The unified cross-type status ([CampaignDto.status]) -- what drives
/// filtering/display everywhere. [CampaignDto.rawStatus] is the underlying
/// engine's own status name and only ever shown as a secondary detail.
enum CampaignStatus {
  active,
  paused,
  completed,
  expired,
  failed,
  cancelled;

  static CampaignStatus fromWire(String value) => switch (value) {
        'ACTIVE' => CampaignStatus.active,
        'PAUSED' => CampaignStatus.paused,
        'COMPLETED' => CampaignStatus.completed,
        'EXPIRED' => CampaignStatus.expired,
        'FAILED' => CampaignStatus.failed,
        'CANCELLED' => CampaignStatus.cancelled,
        _ => throw ArgumentError('Unknown CampaignStatus: $value'),
      };

  String toWire() => switch (this) {
        CampaignStatus.active => 'ACTIVE',
        CampaignStatus.paused => 'PAUSED',
        CampaignStatus.completed => 'COMPLETED',
        CampaignStatus.expired => 'EXPIRED',
        CampaignStatus.failed => 'FAILED',
        CampaignStatus.cancelled => 'CANCELLED',
      };
}

enum CampaignOutcome {
  pending,
  recovered,
  notRecovered;

  static CampaignOutcome fromWire(String value) => switch (value) {
        'PENDING' => CampaignOutcome.pending,
        'RECOVERED' => CampaignOutcome.recovered,
        'NOT_RECOVERED' => CampaignOutcome.notRecovered,
        _ => throw ArgumentError('Unknown CampaignOutcome: $value'),
      };
}

/// Why a campaign failed to recover its slot. Only one wire value is
/// documented today (`NO_CANDIDATES_NOTIFIED`); [other] is a forward-compat
/// fallback so a future backend-added reason renders as a generic label
/// instead of crashing the whole detail screen.
enum CampaignFailureReason {
  noCandidatesNotified,
  other;

  static CampaignFailureReason fromWire(String value) => switch (value) {
        'NO_CANDIDATES_NOTIFIED' => CampaignFailureReason.noCandidatesNotified,
        _ => CampaignFailureReason.other,
      };
}

enum CampaignActionType {
  pause,
  resume,
  cancel,
  retry;

  static CampaignActionType fromWire(String value) => switch (value) {
        'PAUSE' => CampaignActionType.pause,
        'RESUME' => CampaignActionType.resume,
        'CANCEL' => CampaignActionType.cancel,
        'RETRY' => CampaignActionType.retry,
        _ => throw ArgumentError('Unknown CampaignActionType: $value'),
      };
}

enum CampaignNextAction {
  none,
  waitingForResponse,
  pausedByOwner,
  retryAvailable,
  viewRecoveredBooking;

  static CampaignNextAction fromWire(String value) => switch (value) {
        'NONE' => CampaignNextAction.none,
        'WAITING_FOR_RESPONSE' => CampaignNextAction.waitingForResponse,
        'PAUSED_BY_OWNER' => CampaignNextAction.pausedByOwner,
        'RETRY_AVAILABLE' => CampaignNextAction.retryAvailable,
        'VIEW_RECOVERED_BOOKING' => CampaignNextAction.viewRecoveredBooking,
        _ => throw ArgumentError('Unknown CampaignNextAction: $value'),
      };
}

enum CampaignTriggerReason {
  bookingCancelled,
  bookingCompleted,
  customerInactive;

  static CampaignTriggerReason fromWire(String value) => switch (value) {
        'BOOKING_CANCELLED' => CampaignTriggerReason.bookingCancelled,
        'BOOKING_COMPLETED' => CampaignTriggerReason.bookingCompleted,
        'CUSTOMER_INACTIVE' => CampaignTriggerReason.customerInactive,
        _ => throw ArgumentError('Unknown CampaignTriggerReason: $value'),
      };
}

enum CampaignTimelineEventType {
  campaignCreated,
  candidatesSelected,
  notificationSent,
  offerAccepted,
  bookingCreated,
  slotRecovered,
  campaignExpired,
  campaignCancelled,
  campaignCompleted;

  static CampaignTimelineEventType fromWire(String value) => switch (value) {
        'CAMPAIGN_CREATED' => CampaignTimelineEventType.campaignCreated,
        'CANDIDATES_SELECTED' => CampaignTimelineEventType.candidatesSelected,
        'NOTIFICATION_SENT' => CampaignTimelineEventType.notificationSent,
        'OFFER_ACCEPTED' => CampaignTimelineEventType.offerAccepted,
        'BOOKING_CREATED' => CampaignTimelineEventType.bookingCreated,
        'SLOT_RECOVERED' => CampaignTimelineEventType.slotRecovered,
        'CAMPAIGN_EXPIRED' => CampaignTimelineEventType.campaignExpired,
        'CAMPAIGN_CANCELLED' => CampaignTimelineEventType.campaignCancelled,
        'CAMPAIGN_COMPLETED' => CampaignTimelineEventType.campaignCompleted,
        _ => throw ArgumentError('Unknown CampaignTimelineEventType: $value'),
      };
}

enum SmartActionType {
  campaignExpiringSoon,
  failedCampaign,
  retriableCampaign,
  rebookingOpportunity,
  atRiskCustomer,
  longInactiveCustomer;

  static SmartActionType fromWire(String value) => switch (value) {
        'CAMPAIGN_EXPIRING_SOON' => SmartActionType.campaignExpiringSoon,
        'FAILED_CAMPAIGN' => SmartActionType.failedCampaign,
        'RETRIABLE_CAMPAIGN' => SmartActionType.retriableCampaign,
        'REBOOKING_OPPORTUNITY' => SmartActionType.rebookingOpportunity,
        'AT_RISK_CUSTOMER' => SmartActionType.atRiskCustomer,
        'LONG_INACTIVE_CUSTOMER' => SmartActionType.longInactiveCustomer,
        _ => throw ArgumentError('Unknown SmartActionType: $value'),
      };
}

enum SmartActionPriority {
  high,
  medium,
  low;

  static SmartActionPriority fromWire(String value) => switch (value) {
        'HIGH' => SmartActionPriority.high,
        'MEDIUM' => SmartActionPriority.medium,
        'LOW' => SmartActionPriority.low,
        _ => throw ArgumentError('Unknown SmartActionPriority: $value'),
      };
}

/// Mirrors backend's CampaignCenterDtos.CampaignDto -- one campaign,
/// regardless of engine. [slotStartsAt]/[slotEndsAt]/[employeeId]/
/// [employeeName] are Smart-Fill-only (null for Rebook/Reactivation, which
/// target a customer's next visit rather than a fixed slot).
class CampaignDto {
  final String id;
  final CampaignType type;
  final CampaignStatus status;
  final String rawStatus;
  final CampaignTriggerReason triggerReason;
  final String providerId;
  final String serviceId;
  final String? serviceTitle;
  final String? employeeId;
  final String? employeeName;
  final String? customerId;
  final DateTime? slotStartsAt;
  final DateTime? slotEndsAt;
  final int candidateCount;
  final int notifiedCount;
  final int viewedCount;
  final int acceptedCount;
  final String? recoveredBookingId;
  final double? recoveredRevenue;
  final String? currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final CampaignOutcome outcome;
  final CampaignFailureReason? failureReason;
  final CampaignNextAction nextAction;
  final List<CampaignActionType> availableActions;

  const CampaignDto({
    required this.id,
    required this.type,
    required this.status,
    required this.rawStatus,
    required this.triggerReason,
    required this.providerId,
    required this.serviceId,
    this.serviceTitle,
    this.employeeId,
    this.employeeName,
    this.customerId,
    this.slotStartsAt,
    this.slotEndsAt,
    required this.candidateCount,
    required this.notifiedCount,
    required this.viewedCount,
    required this.acceptedCount,
    this.recoveredBookingId,
    this.recoveredRevenue,
    this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    required this.outcome,
    this.failureReason,
    required this.nextAction,
    required this.availableActions,
  });

  factory CampaignDto.fromJson(Map<String, dynamic> json) {
    return CampaignDto(
      id: json['id'] as String,
      type: CampaignType.fromWire(json['type'] as String),
      status: CampaignStatus.fromWire(json['status'] as String),
      rawStatus: json['rawStatus'] as String,
      triggerReason: CampaignTriggerReason.fromWire(json['triggerReason'] as String),
      providerId: json['providerId'] as String,
      serviceId: json['serviceId'] as String,
      serviceTitle: json['serviceTitle'] as String?,
      employeeId: json['employeeId'] as String?,
      employeeName: json['employeeName'] as String?,
      customerId: json['customerId'] as String?,
      slotStartsAt: json['slotStartsAt'] == null ? null : DateTime.parse(json['slotStartsAt'] as String),
      slotEndsAt: json['slotEndsAt'] == null ? null : DateTime.parse(json['slotEndsAt'] as String),
      candidateCount: (json['candidateCount'] as num).toInt(),
      notifiedCount: (json['notifiedCount'] as num).toInt(),
      viewedCount: (json['viewedCount'] as num).toInt(),
      acceptedCount: (json['acceptedCount'] as num).toInt(),
      recoveredBookingId: json['recoveredBookingId'] as String?,
      recoveredRevenue: (json['recoveredRevenue'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
      outcome: CampaignOutcome.fromWire(json['outcome'] as String),
      failureReason:
          json['failureReason'] == null ? null : CampaignFailureReason.fromWire(json['failureReason'] as String),
      nextAction: CampaignNextAction.fromWire(json['nextAction'] as String),
      availableActions: (json['availableActions'] as List<dynamic>)
          .map((e) => CampaignActionType.fromWire(e as String))
          .toList(),
    );
  }
}

class CampaignListResponse {
  final List<CampaignDto> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  const CampaignListResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  factory CampaignListResponse.fromJson(Map<String, dynamic> json) {
    return CampaignListResponse(
      items: (json['items'] as List<dynamic>).map((e) => CampaignDto.fromJson(e as Map<String, dynamic>)).toList(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['pageSize'] as num).toInt(),
      totalItems: (json['totalItems'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
    );
  }
}

/// Mirrors backend's CampaignCenterDtos.CampaignStatsResponse.
/// [currency]/[averageCompletionMinutes] are `null` when there's no data
/// yet -- render "—", never a fabricated 0.
class CampaignStatsResponse {
  final String providerId;
  final int activeCampaigns;
  final int completedCampaigns;
  final int failedCampaigns;
  final int expiredCampaigns;
  final int cancelledCampaigns;
  final int recoveredSlots;
  final double totalRecoveredRevenue;
  final String? currency;
  final double conversionRate;
  final int notificationsSent;
  final int offersAccepted;
  final double? averageCompletionMinutes;
  final int campaignsRequiringAttention;

  const CampaignStatsResponse({
    required this.providerId,
    required this.activeCampaigns,
    required this.completedCampaigns,
    required this.failedCampaigns,
    required this.expiredCampaigns,
    required this.cancelledCampaigns,
    required this.recoveredSlots,
    required this.totalRecoveredRevenue,
    this.currency,
    required this.conversionRate,
    required this.notificationsSent,
    required this.offersAccepted,
    this.averageCompletionMinutes,
    required this.campaignsRequiringAttention,
  });

  factory CampaignStatsResponse.fromJson(Map<String, dynamic> json) {
    return CampaignStatsResponse(
      providerId: json['providerId'] as String,
      activeCampaigns: (json['activeCampaigns'] as num).toInt(),
      completedCampaigns: (json['completedCampaigns'] as num).toInt(),
      failedCampaigns: (json['failedCampaigns'] as num).toInt(),
      expiredCampaigns: (json['expiredCampaigns'] as num).toInt(),
      cancelledCampaigns: (json['cancelledCampaigns'] as num).toInt(),
      recoveredSlots: (json['recoveredSlots'] as num).toInt(),
      totalRecoveredRevenue: (json['totalRecoveredRevenue'] as num).toDouble(),
      currency: json['currency'] as String?,
      conversionRate: (json['conversionRate'] as num).toDouble(),
      notificationsSent: (json['notificationsSent'] as num).toInt(),
      offersAccepted: (json['offersAccepted'] as num).toInt(),
      averageCompletionMinutes: (json['averageCompletionMinutes'] as num?)?.toDouble(),
      campaignsRequiringAttention: (json['campaignsRequiringAttention'] as num).toInt(),
    );
  }
}

class CampaignTimelineEvent {
  final CampaignTimelineEventType type;
  final DateTime occurredAt;
  final String? relatedUserId;

  const CampaignTimelineEvent({required this.type, required this.occurredAt, this.relatedUserId});

  factory CampaignTimelineEvent.fromJson(Map<String, dynamic> json) {
    return CampaignTimelineEvent(
      type: CampaignTimelineEventType.fromWire(json['type'] as String),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      relatedUserId: json['relatedUserId'] as String?,
    );
  }
}

class CampaignTimelineResponse {
  final String providerId;
  final CampaignType type;
  final String campaignId;
  final List<CampaignTimelineEvent> events;

  const CampaignTimelineResponse({
    required this.providerId,
    required this.type,
    required this.campaignId,
    required this.events,
  });

  factory CampaignTimelineResponse.fromJson(Map<String, dynamic> json) {
    return CampaignTimelineResponse(
      providerId: json['providerId'] as String,
      type: CampaignType.fromWire(json['type'] as String),
      campaignId: json['campaignId'] as String,
      events: (json['events'] as List<dynamic>)
          .map((e) => CampaignTimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Mirrors backend's CampaignCenterDtos.SmartActionItem -- one item names
/// exactly one real related entity. Campaign-type items carry
/// [campaignType]+[campaignId]; customer-type items carry [customerId].
/// [recommendedActions] is empty for customer-type items (no backend
/// command exists for them yet).
class SmartActionItem {
  final SmartActionType type;
  final SmartActionPriority priority;
  final String providerId;
  final CampaignType? campaignType;
  final String? campaignId;
  final String? customerId;
  final String? serviceId;
  final String? employeeId;
  final String? bookingId;
  final DateTime? relatedAt;
  final DateTime observedAt;
  final List<CampaignActionType> recommendedActions;

  const SmartActionItem({
    required this.type,
    required this.priority,
    required this.providerId,
    this.campaignType,
    this.campaignId,
    this.customerId,
    this.serviceId,
    this.employeeId,
    this.bookingId,
    this.relatedAt,
    required this.observedAt,
    required this.recommendedActions,
  });

  factory SmartActionItem.fromJson(Map<String, dynamic> json) {
    return SmartActionItem(
      type: SmartActionType.fromWire(json['type'] as String),
      priority: SmartActionPriority.fromWire(json['priority'] as String),
      providerId: json['providerId'] as String,
      campaignType: json['campaignType'] == null ? null : CampaignType.fromWire(json['campaignType'] as String),
      campaignId: json['campaignId'] as String?,
      customerId: json['customerId'] as String?,
      serviceId: json['serviceId'] as String?,
      employeeId: json['employeeId'] as String?,
      bookingId: json['bookingId'] as String?,
      relatedAt: json['relatedAt'] == null ? null : DateTime.parse(json['relatedAt'] as String),
      observedAt: DateTime.parse(json['observedAt'] as String),
      recommendedActions: (json['recommendedActions'] as List<dynamic>)
          .map((e) => CampaignActionType.fromWire(e as String))
          .toList(),
    );
  }
}

class SmartActionsResponse {
  final String providerId;
  final List<SmartActionItem> items;

  const SmartActionsResponse({required this.providerId, required this.items});

  factory SmartActionsResponse.fromJson(Map<String, dynamic> json) {
    return SmartActionsResponse(
      providerId: json['providerId'] as String,
      items: (json['items'] as List<dynamic>).map((e) => SmartActionItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
