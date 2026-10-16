/// Mirrors the backend's `WorkerDirectoryDtos.FavoriteWorkerResponse` — one person on the customer's "My masters" list.
class FavoriteWorker {
  final String id;

  /// MASTER, MECHANIC, CLEANER or STAFF.
  final String kind;
  final String providerId;
  final String providerName;
  final String displayName;
  final String? photoUrl;

  /// Null until somebody has reviewed them.
  final double? averageRating;
  final int reviewCount;

  /// When their next open time starts; null when they have none (or work without a schedule of their own).
  final DateTime? nextFreeAt;

  const FavoriteWorker({
    required this.id,
    required this.kind,
    required this.providerId,
    required this.providerName,
    required this.displayName,
    required this.photoUrl,
    required this.averageRating,
    required this.reviewCount,
    this.nextFreeAt,
  });

  factory FavoriteWorker.fromJson(Map<String, dynamic> json) {
    return FavoriteWorker(
      id: json['id'] as String,
      kind: json['kind'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      nextFreeAt: json['nextFreeAt'] == null ? null : DateTime.parse(json['nextFreeAt'] as String),
    );
  }
}
