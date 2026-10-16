/// One Home-carousel banner — mirrors the backend's `ads.AdDtos.BannerResponse`.
/// [videoUrl] is an https link to an external host (the backend refuses
/// anything else); null means the banner is only an announcement.
class AdBanner {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? videoUrl;

  /// Where a tap opens inside the app when there is no video: `REWARDS` or `SEARCH`.
  /// Null (or a value this app version doesn't know yet) = the banner opens nothing.
  final String? linkTarget;

  /// Bought by a business (as opposed to run by the platform itself): the
  /// card carries an "Ad" label.
  final bool sponsored;

  const AdBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.videoUrl,
    this.linkTarget,
    required this.sponsored,
  });

  factory AdBanner.fromJson(Map<String, dynamic> json) {
    return AdBanner(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String,
      videoUrl: json['videoUrl'] as String?,
      linkTarget: json['linkTarget'] as String?,
      sponsored: json['sponsored'] as bool? ?? false,
    );
  }

  bool get hasVideo => videoUrl != null;

  /// The in-app destination of a tap on a banner without a video, or null.
  AdLinkTarget? get link => switch (linkTarget) {
    'REWARDS' => AdLinkTarget.rewards,
    'SEARCH' => AdLinkTarget.search,
    _ => null,
  };
}

/// The screens a banner can send the customer to (a closed list: never a free URL).
enum AdLinkTarget { rewards, search }
