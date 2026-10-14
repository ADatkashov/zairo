/// Mirrors the backend's `ads.AdDtos.AdminBannerResponse` (camelCase keys).
class AdBanner {
  final String id;

  /// The business that bought the placement; null for a banner the platform runs itself.
  final String? providerId;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? videoUrl;

  /// Null = shown in every city.
  final String? cityCode;
  final DateTime startsAt;
  final DateTime endsAt;
  final int sortOrder;

  /// DRAFT / PENDING_REVIEW / ACTIVE / PAUSED / REJECTED.
  final String status;
  final String? rejectionReason;

  const AdBanner({
    required this.id,
    this.providerId,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.videoUrl,
    this.cityCode,
    required this.startsAt,
    required this.endsAt,
    required this.sortOrder,
    required this.status,
    this.rejectionReason,
  });

  factory AdBanner.fromJson(Map<String, dynamic> json) {
    return AdBanner(
      id: json['id'] as String,
      providerId: json['providerId'] as String?,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String,
      videoUrl: json['videoUrl'] as String?,
      cityCode: json['cityCode'] as String?,
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      sortOrder: (json['sortOrder'] as num? ?? 0).toInt(),
      status: json['status'] as String,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  bool get hasVideo => videoUrl != null;
  bool get isActive => status == 'ACTIVE';

  /// The moves the console offers from this status — the same lifecycle the
  /// backend enforces (anything else is a 409 there).
  bool get canPublish => status == 'DRAFT' || status == 'PENDING_REVIEW' || status == 'PAUSED';
  bool get canPause => status == 'ACTIVE';
  bool get canReject => status == 'PENDING_REVIEW' || status == 'ACTIVE' || status == 'PAUSED';
}
