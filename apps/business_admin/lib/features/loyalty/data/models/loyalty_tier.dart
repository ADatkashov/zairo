/// Mirrors backend's LoyaltyAdminDtos.TierResponse/TierRequest -- "reach N
/// lifetime points, you're in this tier". Same full-replace-ladder contract
/// as [LoyaltyMilestone]: no [id] on the way in, a fresh one comes back on
/// every save.
class LoyaltyTier {
  final String? id;
  final String name;
  final int minLifetimePoints;

  const LoyaltyTier({this.id, required this.name, required this.minLifetimePoints});

  factory LoyaltyTier.fromJson(Map<String, dynamic> json) {
    return LoyaltyTier(
      id: json['id'] as String,
      name: json['name'] as String,
      minLifetimePoints: (json['minLifetimePoints'] as num).toInt(),
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'name': name,
        'minLifetimePoints': minLifetimePoints,
      };

  LoyaltyTier copyWith({String? name, int? minLifetimePoints}) {
    return LoyaltyTier(id: id, name: name ?? this.name, minLifetimePoints: minLifetimePoints ?? this.minLifetimePoints);
  }
}
