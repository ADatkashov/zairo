/// Mirrors backend's ReviewDtos.ReviewResponse
/// (backend/reviews/.../ReviewDtos.java).
class Review {
  final String id;
  final String bookingId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? businessReply;

  const Review({
    required this.id,
    required this.bookingId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.businessReply,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      businessReply: json['businessReply'] as String?,
    );
  }
}
