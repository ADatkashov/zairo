/// Mirrors the backend's `ReviewDtos.ModerationReviewResponse` (camelCase keys): a review the business reported, or the
/// platform already hid.
class ReviewReport {
  final String id;
  final String providerId;
  final String providerName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? businessReply;

  /// Why the business reported it.
  final String? reportReason;
  final DateTime? reportedAt;

  /// OPEN (waiting for a decision), HIDDEN (kept out of every rating) or DISMISSED (looked at, stays).
  final String status;
  final String? hiddenReason;

  const ReviewReport({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.businessReply,
    required this.reportReason,
    required this.reportedAt,
    required this.status,
    required this.hiddenReason,
  });

  factory ReviewReport.fromJson(Map<String, dynamic> json) {
    final reported = json['reportedAt'] as String?;
    return ReviewReport(
      id: json['id'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      businessReply: json['businessReply'] as String?,
      reportReason: json['reportReason'] as String?,
      reportedAt: reported == null ? null : DateTime.parse(reported),
      status: json['status'] as String,
      hiddenReason: json['hiddenReason'] as String?,
    );
  }

  bool get isOpen => status == 'OPEN';
  bool get isHidden => status == 'HIDDEN';
  bool get isDismissed => status == 'DISMISSED';
}
