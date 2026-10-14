/// Mirrors the backend's `WorkerDirectoryDtos.WorkerProfileResponse` — a
/// worker's public page.
class WorkerProfile {
  final String id;

  /// MASTER, MECHANIC, CLEANER or STAFF. Only a MASTER has a photo portfolio.
  final String kind;
  final String providerId;
  final String providerName;
  final String displayName;
  final String? photoUrl;

  /// Null until the worker has a review: absent, not zero.
  final double? averageRating;
  final int reviewCount;
  final List<WorkerService> services;

  const WorkerProfile({
    required this.id,
    required this.kind,
    required this.providerId,
    required this.providerName,
    required this.displayName,
    required this.photoUrl,
    required this.averageRating,
    required this.reviewCount,
    required this.services,
  });

  bool get hasPortfolio => kind == 'MASTER';

  factory WorkerProfile.fromJson(Map<String, dynamic> json) {
    return WorkerProfile(
      id: json['id'] as String,
      kind: json['kind'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      services: [
        for (final s in json['services'] as List<dynamic>) WorkerService.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}

class WorkerService {
  final String id;
  final String title;
  final int durationMinutes;
  final double price;
  final String currency;

  const WorkerService({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.price,
    required this.currency,
  });

  factory WorkerService.fromJson(Map<String, dynamic> json) {
    return WorkerService(
      id: json['id'] as String,
      title: json['title'] as String,
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
    );
  }
}
