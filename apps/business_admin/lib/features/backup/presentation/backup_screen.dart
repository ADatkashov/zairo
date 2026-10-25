import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../salon/presentation/providers/salon_providers.dart';
import '../data/backup_sharer.dart';
import '../data/backup_workbook.dart';
import '../data/business_backup.dart';

/// One screen, one button: save a copy of the schedule, customers and prices as an Excel file the owner keeps
/// outside the app — what to work from if the app is ever unavailable. It says what the file holds and that it
/// holds customers' personal data, then does the whole job in a tap: fetch, build, hand over to the share sheet.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

enum _Stage { idle, working, done, loadFailed, shareFailed }

class _BackupScreenState extends ConsumerState<BackupScreen> {
  _Stage _stage = _Stage.idle;
  int _bookings = 0;
  int _customers = 0;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final labels = _labels(l10n);
    setState(() => _stage = _Stage.working);

    final List<BusinessBackup> backups;
    try {
      final user = await ref.read(authControllerProvider.future);
      if (user == null) throw StateError('signed out');
      final providers = await ref.read(myProvidersProvider(user.id).future);
      final api = ref.read(salonAdminApiProvider);
      backups = await Future.wait([for (final p in providers) api.fetchBackup(p.id, providerName: p.name)]);
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.loadFailed);
      return;
    }

    try {
      final bytes = buildBackupWorkbook(backups, labels);
      final fileName = 'zairo-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      final shared = await ref.read(backupSharerProvider)(bytes, fileName);
      if (!mounted) return;
      setState(() {
        _stage = shared ? _Stage.done : _Stage.idle;
        _bookings = backups.fold(0, (sum, b) => sum + b.bookings.length);
        _customers = backups.fold(0, (sum, b) => sum + b.customers.length);
      });
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.shareFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.factoryColors;
    final textTheme = Theme.of(context).textTheme;
    final working = _stage == _Stage.working;

    Widget included(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: FactorySpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: FactorySpacing.space3),
          Expanded(child: Text(text, style: textTheme.bodyMedium)),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: FactoryAppBar(title: l10n.backupTitle),
      body: ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          Text(l10n.backupIntro, style: textTheme.bodyLarge),
          const SizedBox(height: FactorySpacing.space4),
          FactoryCard(
            child: Column(
              children: [
                included(Icons.event_note_outlined, l10n.backupIncludesSchedule),
                included(Icons.groups_outlined, l10n.backupIncludesCustomers),
                included(Icons.sell_outlined, l10n.backupIncludesServices),
              ],
            ),
          ),
          const SizedBox(height: FactorySpacing.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: colors.textTertiary),
              const SizedBox(width: FactorySpacing.space2),
              Expanded(
                child: Text(l10n.backupPrivacyNote, style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: FactorySpacing.space5),
          FactoryButton(
            icon: Icons.download_rounded,
            label: l10n.backupButton,
            isLoading: working,
            onPressed: working ? null : _save,
          ),
          const SizedBox(height: FactorySpacing.space4),
          if (_stage == _Stage.done)
            _Notice(icon: Icons.check_circle_outline_rounded, color: colors.success, text: l10n.backupDone(_bookings, _customers)),
          if (_stage == _Stage.loadFailed)
            _Notice(icon: Icons.error_outline_rounded, color: colors.error, text: l10n.backupFailed),
          if (_stage == _Stage.shareFailed)
            _Notice(icon: Icons.error_outline_rounded, color: colors.error, text: l10n.backupShareFailed),
        ],
      ),
    );
  }

  BackupLabels _labels(AppLocalizations l10n) => BackupLabels(
    sheetSchedule: l10n.backupSheetSchedule,
    sheetCustomers: l10n.backupSheetCustomers,
    sheetServices: l10n.backupSheetServices,
    business: l10n.backupColBusiness,
    date: l10n.backupColDate,
    start: l10n.backupColStart,
    end: l10n.backupColEnd,
    service: l10n.backupColService,
    master: l10n.backupColMaster,
    customer: l10n.backupColCustomer,
    phone: l10n.backupColPhone,
    email: l10n.backupColEmail,
    status: l10n.backupColStatus,
    price: l10n.backupColPrice,
    currency: l10n.backupColCurrency,
    lastVisit: l10n.backupColLastVisit,
    visits: l10n.backupColVisits,
    spent: l10n.backupColSpent,
    noShows: l10n.backupColNoShows,
    duration: l10n.backupColDuration,
    active: l10n.backupColActive,
    yes: l10n.backupYes,
    no: l10n.backupNo,
    statusLabel: (status) => switch (status) {
      'CONFIRMED' => l10n.bookingStatusConfirmed,
      'COMPLETED' => l10n.bookingStatusCompleted,
      'CANCELLED' => l10n.bookingStatusCancelled,
      _ => status.isEmpty ? status : '${status[0]}${status.substring(1).toLowerCase()}',
    },
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: FactorySpacing.space2),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
