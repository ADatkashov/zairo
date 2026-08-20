class ReviewException implements Exception {
  final String message;

  const ReviewException(this.message);

  @override
  String toString() => message;
}
