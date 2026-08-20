/// Mirrors backend's MasterDtos.PortfolioItemResponse
/// (backend/vertical-beauty/.../MasterDtos.java).
class AdminPortfolioItem {
  final String id;
  final String masterId;
  final String imageUrl;
  final String? caption;

  const AdminPortfolioItem({
    required this.id,
    required this.masterId,
    required this.imageUrl,
    this.caption,
  });

  factory AdminPortfolioItem.fromJson(Map<String, dynamic> json) {
    return AdminPortfolioItem(
      id: json['id'] as String,
      masterId: json['masterId'] as String,
      imageUrl: json['imageUrl'] as String,
      caption: json['caption'] as String?,
    );
  }
}
