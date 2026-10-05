import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../staff/presentation/widgets/add_person_from_user_dialog.dart';
import '../providers/auto_admin_providers.dart';

/// Returns true via Navigator.pop when the person was added. The person is an
/// existing registered user picked by phone — see [AddPersonFromUserDialog].
class AddMechanicDialog extends ConsumerWidget {
  final String providerId;

  const AddMechanicDialog({super.key, required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AddPersonFromUserDialog(
      providerId: providerId,
      title: AppLocalizations.of(context)!.addMechanicDialogTitle,
      onAdd: (userId) => ref.read(autoAdminApiProvider).createMechanicFromUser(providerId: providerId, userId: userId),
    );
  }
}
