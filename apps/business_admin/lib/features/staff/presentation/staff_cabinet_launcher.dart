import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';

/// The consumer app's deep link to the staff cabinet (see its AppRoutes).
final staffCabinetUri = Uri.parse('zairo://app/staff-cabinet');

/// Opens the consumer app's staff cabinet. A plain owner who also works as a
/// master keeps one account in both apps; the cabinet lives in the consumer
/// app so a regular master never needs this one.
Future<void> openStaffCabinet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(staffCabinetUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.staffCabinetLinkFailed)));
  }
}
