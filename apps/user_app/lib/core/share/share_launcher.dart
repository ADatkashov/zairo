import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/router/app_routes.dart';
import '../links/external_links.dart';

/// Opens the phone's own share sheet with [text]. A provider so tests can see what would be shared instead of
/// reaching for a platform channel (same idea as `checkoutLauncherProvider`).
final shareLauncherProvider = Provider<Future<void> Function(String text, {String? subject})>((ref) {
  return (text, {subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  };
});

/// What a customer sends a friend about a business: its name, the address, a map link anyone can tap (https works
/// in every messenger) and, last, the `zairo://` link that opens the business inside the app for those who have it.
String providerShareText({
  required String id,
  required String name,
  String? address,
  double? latitude,
  double? longitude,
}) {
  final lines = <String>[
    name,
    if (address != null && address.trim().isNotEmpty) address.trim(),
    if (latitude != null && longitude != null) ExternalLinks.showOnMap(latitude: latitude, longitude: longitude).toString(),
    'zairo://app${AppRoutes.provider(id)}',
  ];
  return lines.join('\n');
}
