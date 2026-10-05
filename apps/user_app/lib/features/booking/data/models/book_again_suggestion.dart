import '../../../discovery/data/models/provider_search_result.dart';
import '../../../discovery/data/models/service_summary.dart';

/// Mirrors backend's BookAgainDtos.BookAgainSuggestion
/// (backend/search/.../BookAgainDtos.java) — returned by
/// GET /api/v1/users/{userId}/book-again.
class BookAgainSuggestion {
  final String providerId;
  final String providerName;
  final String vertical;
  final String serviceId;
  final String serviceTitle;
  final int durationMinutes;
  final double price;
  final String currency;
  final DateTime lastVisitAt;

  const BookAgainSuggestion({
    required this.providerId,
    required this.providerName,
    required this.vertical,
    required this.serviceId,
    required this.serviceTitle,
    required this.durationMinutes,
    required this.price,
    required this.currency,
    required this.lastVisitAt,
  });

  /// The minimal provider the detail screen needs to start booking this exact
  /// service again; the screen loads the rest (slots, staff) itself.
  ProviderSearchResult toProviderSearchResult() => ProviderSearchResult(
    id: providerId,
    name: providerName,
    vertical: vertical,
    status: 'ACTIVE',
    hasOpenAvailability: true,
    minPrice: price,
    services: [
      ServiceSummary(
        id: serviceId,
        title: serviceTitle,
        durationMinutes: durationMinutes,
        price: price,
        currency: currency,
      ),
    ],
  );

  factory BookAgainSuggestion.fromJson(Map<String, dynamic> json) {
    return BookAgainSuggestion(
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      vertical: json['vertical'] as String,
      serviceId: json['serviceId'] as String,
      serviceTitle: json['serviceTitle'] as String,
      durationMinutes: json['durationMinutes'] as int,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      lastVisitAt: DateTime.parse(json['lastVisitAt'] as String),
    );
  }
}
