/// Mirrors backend's `ReviewDtos.ProviderReviewResponse` -- one row of the
/// owner-facing reviews list (`GET /providers/{id}/reviews`). [businessReply]
/// is null until the owner replies; [businessReplyAt] is only ever set once
/// [businessReply] is, same invariant the backend's own doc comment states.
class ProviderReview {
  final String id;
  final String bookingId;
  final String customerName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? businessReply;
  final DateTime? businessReplyAt;

  /// Where a report on this review stands: null = never reported, OPEN = waiting for the platform, HIDDEN = the
  /// platform took it out of every rating, DISMISSED = looked at, it stays.
  final String? moderationStatus;

  const ProviderReview({
    required this.id,
    required this.bookingId,
    required this.customerName,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.businessReply,
    this.businessReplyAt,
    this.moderationStatus,
  });

  bool get hasReply => businessReply != null;

  ProviderReview copyWithReply({required String businessReply, required DateTime businessReplyAt}) => ProviderReview(
        id: id,
        bookingId: bookingId,
        customerName: customerName,
        rating: rating,
        comment: comment,
        createdAt: createdAt,
        businessReply: businessReply,
        businessReplyAt: businessReplyAt,
        moderationStatus: moderationStatus,
      );

  ProviderReview copyWithModeration(String status) => ProviderReview(
        id: id,
        bookingId: bookingId,
        customerName: customerName,
        rating: rating,
        comment: comment,
        createdAt: createdAt,
        businessReply: businessReply,
        businessReplyAt: businessReplyAt,
        moderationStatus: status,
      );

  factory ProviderReview.fromJson(Map<String, dynamic> json) {
    return ProviderReview(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      customerName: json['customerName'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      businessReply: json['businessReply'] as String?,
      businessReplyAt: json['businessReplyAt'] == null ? null : DateTime.parse(json['businessReplyAt'] as String),
      moderationStatus: json['moderationStatus'] as String?,
    );
  }
}
