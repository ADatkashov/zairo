import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../staff/presentation/widgets/add_person_from_user_dialog.dart';
import '../providers/cleaning_admin_providers.dart';

/// Returns true via Navigator.pop when the person was added. The person is an
/// existing registered user picked by phone — see [AddPersonFromUserDialog].
class AddCleanerDialog extends ConsumerWidget {
  final String providerId;

  const AddCleanerDialog({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AddPersonFromUserDialog(
      providerId: providerId,
      title: AppLocalizations.of(context)!.addCleanerDialogTitle,
      onAdd: (userId) => ref.read(cleaningAdminApiProvider).createCleanerFromUser(providerId: providerId, userId: userId),
    );
  }
}
