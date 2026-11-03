/// Mirrors the backend's `RecommendationsDtos.RecommendedProvider`
/// (GET /api/v1/users/{userId}/recommendations): a business id, in the order it should be shown. The business
/// details are the ones search already loaded.
class RecommendedProvider {
  final String providerId;

  /// The category of the customer's own history this business matches.
  final String vertical;

  const RecommendedProvider({required this.providerId, required this.vertical});

  factory RecommendedProvider.fromJson(Map<String, dynamic> json) => RecommendedProvider(
    providerId: json['providerId'] as String,
    vertical: json['vertical'] as String,
  );
}
