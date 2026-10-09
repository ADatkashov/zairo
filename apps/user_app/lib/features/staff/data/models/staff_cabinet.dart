// Mirrors backend's StaffPortalDtos (backend/staff/.../StaffPortalDtos.java).

/// One business the signed-in user works at.
class StaffMembership {
  final String staffId;
  final String providerId;
  final String providerName;
  final String displayName;
  final String? photoUrl;
  final bool active;

  /// Upcoming, paid appointments not yet accepted.
  final int pendingCount;
  final double? averageRating;
  final int reviewCount;

  const StaffMembership({
    required this.staffId,
    required this.providerId,
    required this.providerName,
    required this.displayName,
    required this.photoUrl,
    required this.active,
    required this.pendingCount,
    required this.averageRating,
    required this.reviewCount,
  });

  factory StaffMembership.fromJson(Map<String, dynamic> json) {
    return StaffMembership(
      staffId: json['staffId'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      active: json['active'] as bool,
      pendingCount: (json['pendingCount'] as num).toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
    );
  }
}

class StaffAppointment {
  final String bookingId;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? serviceTitle;
  final String? customerName;
  final String? customerPhone;
  final double totalPrice;
  final String currency;
  final double paidAmount;
  final String? cancellationReason;
  final DateTime? staffConfirmedAt;

  /// When the staff member told the owner they can't attend; null otherwise.
  final DateTime? staffDeclinedAt;
  final bool canAccept;
  final bool canDecline;
  final bool canComplete;
  final bool canMarkNoShow;

  const StaffAppointment({
    required this.bookingId,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.serviceTitle,
    required this.customerName,
    required this.customerPhone,
    required this.totalPrice,
    required this.currency,
    required this.paidAmount,
    required this.cancellationReason,
    required this.staffConfirmedAt,
    required this.staffDeclinedAt,
    required this.canAccept,
    required this.canDecline,
    required this.canComplete,
    required this.canMarkNoShow,
  });

  factory StaffAppointment.fromJson(Map<String, dynamic> json) {
    final confirmedAt = json['staffConfirmedAt'] as String?;
    final declinedAt = json['staffDeclinedAt'] as String?;
    return StaffAppointment(
      bookingId: json['bookingId'] as String,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      serviceTitle: json['serviceTitle'] as String?,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      totalPrice: (json['totalPrice'] as num).toDouble(),
      currency: json['currency'] as String,
      paidAmount: (json['paidAmount'] as num).toDouble(),
      cancellationReason: json['cancellationReason'] as String?,
      staffConfirmedAt: confirmedAt == null
          ? null
          : DateTime.parse(confirmedAt),
      staffDeclinedAt: declinedAt == null ? null : DateTime.parse(declinedAt),
      canAccept: json['canAccept'] as bool,
      canDecline: json['canDecline'] as bool,
      canComplete: json['canComplete'] as bool,
      canMarkNoShow: json['canMarkNoShow'] as bool,
    );
  }
}

class StaffReview {
  final String reviewId;
  final String bookingId;
  final String? customerName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? businessReply;

  const StaffReview({
    required this.reviewId,
    required this.bookingId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.businessReply,
  });

  factory StaffReview.fromJson(Map<String, dynamic> json) {
    return StaffReview(
      reviewId: json['reviewId'] as String,
      bookingId: json['bookingId'] as String,
      customerName: json['customerName'] as String?,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      businessReply: json['businessReply'] as String?,
    );
  }
}

class StaffRating {
  final double? averageRating;
  final int reviewCount;

  /// Review counts for 1..5 stars; index 0 is one star.
  final List<int> distribution;
  final List<StaffReview> reviews;

  const StaffRating({
    required this.averageRating,
    required this.reviewCount,
    required this.distribution,
    required this.reviews,
  });

  factory StaffRating.fromJson(Map<String, dynamic> json) {
    return StaffRating(
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      distribution: (json['distribution'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      reviews: (json['reviews'] as List<dynamic>)
          .map((e) => StaffReview.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
