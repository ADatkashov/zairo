/// One Home-carousel banner — mirrors the backend's `ads.AdDtos.BannerResponse`.
/// [videoUrl] is an https link to an external host (the backend refuses
/// anything else); null means the banner is only an announcement.
class AdBanner {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? videoUrl;

  /// Bought by a business (as opposed to run by the platform itself): the
  /// card carries an "Ad" label.
  final bool sponsored;

  const AdBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.videoUrl,
    required this.sponsored,
  });

  factory AdBanner.fromJson(Map<String, dynamic> json) {
    return AdBanner(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String,
      videoUrl: json['videoUrl'] as String?,
      sponsored: json['sponsored'] as bool? ?? false,
    );
  }

  bool get hasVideo => videoUrl != null;
}
