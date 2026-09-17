/// Mirrors backend's LoyaltyAdminDtos.MilestoneResponse/MilestoneRequest --
/// "reach N visits, get M points". [id] is null for a milestone the owner
/// just added locally and hasn't saved yet; the write endpoint is a full
/// replace of the whole ladder and never takes an id on the way in (see
/// [toRequestJson]), so a fresh [id] comes back from every successful save.
class LoyaltyMilestone {
  final String? id;
  final int visitsRequired;
  final int pointsAwarded;
  final String? label;

  const LoyaltyMilestone({this.id, required this.visitsRequired, required this.pointsAwarded, this.label});

  factory LoyaltyMilestone.fromJson(Map<String, dynamic> json) {
    return LoyaltyMilestone(
      id: json['id'] as String,
      visitsRequired: (json['visitsRequired'] as num).toInt(),
      pointsAwarded: (json['pointsAwarded'] as num).toInt(),
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'visitsRequired': visitsRequired,
        'pointsAwarded': pointsAwarded,
        'label': label,
      };

  LoyaltyMilestone copyWith({int? visitsRequired, int? pointsAwarded, String? label, bool clearLabel = false}) {
    return LoyaltyMilestone(
      id: id,
      visitsRequired: visitsRequired ?? this.visitsRequired,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded,
      label: clearLabel ? null : (label ?? this.label),
    );
  }
}
