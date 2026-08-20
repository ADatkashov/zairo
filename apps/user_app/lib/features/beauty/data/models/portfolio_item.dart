/// Mirrors backend's MasterDtos.PortfolioItemResponse
/// (backend/vertical-beauty/.../MasterDtos.java).
class PortfolioItem {
  final String id;
  final String masterId;
  final String imageUrl;
  final String? caption;

  const PortfolioItem({
    required this.id,
    required this.masterId,
    required this.imageUrl,
    this.caption,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'] as String,
      masterId: json['masterId'] as String,
      imageUrl: json['imageUrl'] as String,
      caption: json['caption'] as String?,
    );
  }
}
