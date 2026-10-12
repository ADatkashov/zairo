/// Mirrors backend's ReviewDtos.PublicReviewResponse — one row of the public
/// reviews list. The author is already abbreviated server-side ("Aisha K.").
class PublicReview {
  final String id;
  final String authorName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? businessReply;
  final DateTime? businessReplyAt;

  const PublicReview({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.businessReply,
    this.businessReplyAt,
  });

  factory PublicReview.fromJson(Map<String, dynamic> json) {
    final replyAt = json['businessReplyAt'] as String?;
    return PublicReview(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      businessReply: json['businessReply'] as String?,
      businessReplyAt: replyAt == null ? null : DateTime.parse(replyAt),
    );
  }
}

/// A page of [PublicReview]s plus whether more exist.
class PublicReviewsPage {
  final List<PublicReview> reviews;
  final bool hasMore;

  const PublicReviewsPage({required this.reviews, required this.hasMore});

  factory PublicReviewsPage.fromJson(Map<String, dynamic> json) {
    return PublicReviewsPage(
      reviews: (json['content'] as List<dynamic>)
          .map((e) => PublicReview.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: !(json['last'] as bool? ?? true),
    );
  }
}

/// Mirrors ReviewDtos.ReviewSummaryResponse. [distribution] has five entries,
/// index 0 = one star.
class ReviewSummary {
  final double? average;
  final int total;
  final List<int> distribution;

  const ReviewSummary({
    required this.average,
    required this.total,
    required this.distribution,
  });

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['distribution'] as List<dynamic>)
        .map((e) => (e as num).toInt())
        .toList();
    return ReviewSummary(
      average: (json['average'] as num?)?.toDouble(),
      total: (json['total'] as num).toInt(),
      distribution: [for (var i = 0; i < 5; i++) i < raw.length ? raw[i] : 0],
    );
  }
}

/// Wire values match the backend's `sort` parameter.
enum ReviewSort { newest, highest, lowest }
