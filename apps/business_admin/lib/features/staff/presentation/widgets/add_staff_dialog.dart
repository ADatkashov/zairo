import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../providers/staff_admin_providers.dart';
import 'add_person_from_user_dialog.dart';

/// Returns true via Navigator.pop when the person was added. The person is an
/// existing registered user picked by phone — see [AddPersonFromUserDialog].
class AddStaffDialog extends ConsumerWidget {
  final String providerId;

  const AddStaffDialog({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AddPersonFromUserDialog(
      providerId: providerId,
      title: AppLocalizations.of(context)!.addStaffDialogTitle,
      onAdd: (userId) => ref.read(staffAdminApiProvider).createStaffFromUser(providerId: providerId, userId: userId),
    );
  }
}
