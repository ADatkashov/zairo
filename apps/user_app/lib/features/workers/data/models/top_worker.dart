/// Mirrors the backend's `WorkerDirectoryDtos.TopWorkerResponse` — one master on
/// Home's "Best masters" rail.
class TopWorker {
  final String id;

  /// MASTER, MECHANIC, CLEANER or STAFF: which directory the worker lives in.
  final String kind;
  final String providerId;
  final String providerName;
  final String displayName;
  final String? photoUrl;
  final double averageRating;
  final int reviewCount;

  const TopWorker({
    required this.id,
    required this.kind,
    required this.providerId,
    required this.providerName,
    required this.displayName,
    required this.photoUrl,
    required this.averageRating,
    required this.reviewCount,
  });

  factory TopWorker.fromJson(Map<String, dynamic> json) {
    return TopWorker(
      id: json['id'] as String,
      kind: json['kind'] as String,
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      averageRating: (json['averageRating'] as num).toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
    );
  }
}
