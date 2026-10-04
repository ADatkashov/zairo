import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/formatting/month_day_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/models/business_type.dart';
import '../../../catalog/data/models/category.dart';
import '../../../catalog/data/models/subsphere.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../../../salon/data/models/admin_provider.dart';
import '../../data/models/platform_admin_session.dart';
import '../providers/platform_admin_providers.dart';
import '../widgets/platform_change_avatar_dialog.dart';

/// The whole point of the "don't hardcode categories" instruction, made
/// operable: a PLATFORM_ADMIN creates Category -> Sphere (BusinessType) ->
/// Subsphere -> Service rows here, and they show up across both apps (the
/// customer app's category grid, this app's business-creation picker)
/// immediately — no release. Deliberately plain (a list per level, one
/// create dialog, a status toggle) rather than a polished CMS: this is an
/// internal ops tool, not a customer- or business-owner-facing surface.
class PlatformAdminTaxonomyScreen extends ConsumerWidget {
  const PlatformAdminTaxonomyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(platformAdminControllerProvider).value;
    if (session == null) {
      // Logged out mid-session (e.g. a second browser tab) — nothing
      // useful to show; the login screen is one pop away.
      return const SizedBox.shrink();
    }

    final tabs = [
      const Tab(text: 'Businesses'),
      const Tab(text: 'Categories'),
      const Tab(text: 'Spheres'),
      const Tab(text: 'Subspheres'),
      const Tab(text: 'Services'),
      const Tab(text: 'Audit Log'),
      if (session.isPlatformAdmin) const Tab(text: 'Staff'),
    ];
    final tabViews = [
      _BusinessesTab(session: session),
      _CategoriesTab(platformToken: session.accessToken),
      _SpheresTab(platformToken: session.accessToken),
      _SubspheresTab(platformToken: session.accessToken),
      _ServicesTab(platformToken: session.accessToken),
      _AuditLogTab(platformToken: session.accessToken),
      if (session.isPlatformAdmin) _StaffTab(session: session),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.all(FactorySpacing.space2),
            child: GestureDetector(
              onTap: () => showPlatformChangeAvatarDialog(context, hasCurrentAvatar: session.avatarUrl != null),
              child: FactoryAvatar(
                initials: _initialsFor(session.displayName),
                size: 32,
                image: session.avatarUrl != null ? NetworkImage(session.avatarUrl!) : null,
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(session.email, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: FactorySpacing.space2),
              FactoryBadge(label: session.role, variant: FactoryBadgeVariant.neutral),
            ],
          ),
          bottom: TabBar(isScrollable: true, tabs: tabs),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                ref.read(platformAdminControllerProvider.notifier).logout();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }
}

String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// The Control Center's own path to business moderation — same Provider
/// resource ModerationScreen's ADMIN-role login already moderates (see
/// ProviderAdminController), now reachable by PLATFORM_ADMIN and
/// PLATFORM_MODERATOR without a second login or a direct database change.
/// PLATFORM_SUPPORT still sees the list (any platform role can read it) but
/// gets no action buttons — it stays read-only by design.
class _BusinessesTab extends ConsumerWidget {
  const _BusinessesTab({required this.session});

  final PlatformAdminSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessesAsync = ref.watch(platformBusinessesProvider(session.accessToken));
    Future<void> refresh() => ref.refresh(platformBusinessesProvider(session.accessToken).future);
    return Scaffold(
      body: businessesAsync.when(
        data: (businesses) {
          if (businesses.isEmpty) {
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text('No businesses yet.')),
                  ),
                ],
              ),
            );
          }
          final sorted = [...businesses]..sort((a, b) => a.status == b.status ? 0 : (a.status == 'PENDING' ? -1 : 1));
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
            padding: const EdgeInsets.all(FactorySpacing.space4),
            children: [
              for (final business in sorted)
                Padding(
                  padding: const EdgeInsets.only(bottom: FactorySpacing.space3),
                  child: FactorySelectableTile(
                    title: business.name,
                    subtitle: Text('${business.vertical} · ${business.status}'),
                    trailing: session.canModerateBusinesses
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (business.status != 'SUSPENDED')
                                IconButton(
                                  tooltip: 'Suspend',
                                  icon: const Icon(Icons.block),
                                  onPressed: () => _changeStatus(context, ref, business, 'SUSPENDED'),
                                ),
                              if (business.status != 'ACTIVE')
                                IconButton(
                                  tooltip: 'Approve',
                                  icon: const Icon(Icons.check_circle_outline),
                                  onPressed: () => _changeStatus(context, ref, business, 'ACTIVE'),
                                ),
                            ],
                          )
                        : _StatusBadge(status: business.status),
                  ),
                ),
            ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    AdminProvider business,
    String nextStatus,
  ) async {
    // Suspending hides a business from customer search and cancels its
    // ability to take bookings — never a single tap, unlike approving a
    // still-invisible PENDING business into view.
    if (nextStatus == 'SUSPENDED') {
      final confirmed = await showFactoryDialog<bool>(
        context: context,
        title: 'Suspend ${business.name}?',
        message: 'This hides the business from customer search immediately. It can be reinstated later.',
        actions: [
          FactoryButton(
            label: 'Cancel',
            variant: FactoryButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FactoryButton(label: 'Suspend', onPressed: () => Navigator.of(context).pop(true)),
        ],
      );
      if (confirmed != true) return;
    }
    await ref.read(platformBusinessApiProvider).setStatus(session.accessToken, business.id, nextStatus);
    ref.invalidate(platformBusinessesProvider(session.accessToken));
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return FactoryBadge(
      label: status,
      variant: status == 'ACTIVE' ? FactoryBadgeVariant.available : FactoryBadgeVariant.neutral,
    );
  }
}

/// Every platform-admin mutation, newest first — any authenticated platform
/// role can read this (PLATFORM_SUPPORT included), matching how a real
/// corporate admin console (Google Workspace Admin, Microsoft 365 admin
/// center) always ships an activity/audit log alongside role management.
class _AuditLogTab extends ConsumerWidget {
  const _AuditLogTab({required this.platformToken});

  final String platformToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(platformAuditLogProvider(platformToken));
    Future<void> refresh() => ref.refresh(platformAuditLogProvider(platformToken).future);
    return Scaffold(
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 400,
                    child: Center(child: Text('No activity recorded yet.')),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: FactorySpacing.space2),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final subtitleParts = <String>[
                  entry.actorEmail,
                  if (entry.previousValue != null || entry.newValue != null)
                    '${entry.previousValue ?? '—'} → ${entry.newValue ?? '—'}',
                  if (entry.reason != null && entry.reason!.isNotEmpty) entry.reason!,
                ];
                return FactorySelectableTile(
                  title: entry.action,
                  subtitle: Text(subtitleParts.join(' · ')),
                  trailing: Text(
                    formatMonthDayTime(AppLocalizations.of(context)!, entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
    );
  }
}

/// The Control Center's staff directory — PLATFORM_ADMIN-only, the one role
/// that can create or deactivate another platform account (see
/// PlatformCurrentAdmin.requirePlatformAdmin). Modeled on the same shape
/// every major admin console uses (Google Workspace, Microsoft 365, AWS
/// IAM): a role per person, an invite/create flow, and a revoke action —
/// deliberately not more than that until an actual need shows up (see
/// PlatformRole's own doc comment on why there are only three roles).
class _StaffTab extends ConsumerWidget {
  const _StaffTab({required this.session});

  final PlatformAdminSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminsAsync = ref.watch(platformAdminsProvider(session.accessToken));
    void refresh() => ref.invalidate(platformAdminsProvider(session.accessToken));

    return Scaffold(
      body: adminsAsync.when(
        data: (admins) => RefreshIndicator(
          onRefresh: () => ref.refresh(platformAdminsProvider(session.accessToken).future),
          child: ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            for (final admin in admins)
              Padding(
                padding: const EdgeInsets.only(bottom: FactorySpacing.space2),
                child: FactorySelectableTile(
                  leading: FactoryAvatar(
                    initials: _initialsFor(admin.displayName),
                    image: admin.avatarUrl != null ? NetworkImage(admin.avatarUrl!) : null,
                  ),
                  title: admin.displayName,
                  titleColor: admin.active ? null : Theme.of(context).disabledColor,
                  subtitle: Text('${admin.email} · ${admin.role}'),
                  trailing: admin.email == session.email
                      ? const FactoryBadge(label: 'You', variant: FactoryBadgeVariant.neutral)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FactoryBadge(
                              label: admin.active ? 'Active' : 'Deactivated',
                              variant: admin.active ? FactoryBadgeVariant.available : FactoryBadgeVariant.neutral,
                            ),
                            IconButton(
                              tooltip: admin.active ? 'Deactivate' : 'Reactivate',
                              icon: Icon(admin.active ? Icons.block : Icons.check_circle_outline),
                              onPressed: () async {
                                if (admin.active) {
                                  await ref.read(platformAdminApiProvider).deactivateAdmin(
                                        session.accessToken,
                                        admin.id,
                                      );
                                } else {
                                  await ref.read(platformAdminApiProvider).reactivateAdmin(
                                        session.accessToken,
                                        admin.id,
                                      );
                                }
                                refresh();
                              },
                            ),
                          ],
                        ),
                ),
              ),
          ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => _CreateAdminDialog(platformToken: session.accessToken),
          );
          if (created == true) refresh();
        },
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

class _CreateAdminDialog extends ConsumerStatefulWidget {
  const _CreateAdminDialog({required this.platformToken});

  final String platformToken;

  @override
  ConsumerState<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends ConsumerState<_CreateAdminDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _reasonController = TextEditingController();
  String _role = 'PLATFORM_SUPPORT';
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: 'Add staff account',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryTextField(controller: _displayNameController, enabled: !_isSubmitting, label: 'Full name'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _emailController, enabled: !_isSubmitting, label: 'Email'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _passwordController, enabled: !_isSubmitting, label: 'Temporary password', obscureText: true),
            const SizedBox(height: FactorySpacing.space3),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'PLATFORM_ADMIN', child: Text('Platform admin — full access')),
                DropdownMenuItem(value: 'PLATFORM_MODERATOR', child: Text('Moderator — business approval only')),
                DropdownMenuItem(value: 'PLATFORM_SUPPORT', child: Text('Support — read-only')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _role = value);
              },
            ),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _reasonController, enabled: !_isSubmitting, label: 'Reason (optional, for the audit log)'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: FactorySpacing.space2),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(label: l10n.createButton, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
      ],
    );
  }

  Future<void> _submit() async {
    if (_displayNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().length < 8) {
      setState(() => _error = 'Name and email are required; password needs at least 8 characters.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(platformAdminApiProvider).createAdmin(
            widget.platformToken,
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            displayName: _displayNameController.text.trim(),
            role: _role,
            reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isSubmitting = false;
      });
    }
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({required this.platformToken});

  final String platformToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(platformAllCategoriesProvider(platformToken));
    return Scaffold(
      body: categoriesAsync.when(
        data: (categories) => ListView(
          padding: const EdgeInsets.all(FactorySpacing.space4),
          children: [
            for (final category in categories)
              FactorySelectableTile(
                title: '${category.icon ?? ''} ${category.nameEn}'.trim(),
                subtitle: Text(category.code),
                trailing: _StatusToggle(
                  status: category.status,
                  onToggle: (next) async {
                    await ref.read(catalogApiProvider).setCategoryStatus(platformToken, category.id, next);
                    ref.invalidate(platformAllCategoriesProvider(platformToken));
                  },
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await showDialog<bool>(
            context: context,
            builder: (_) => _CreateCategoryDialog(platformToken: platformToken),
          );
          if (created == true) ref.invalidate(platformAllCategoriesProvider(platformToken));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SpheresTab extends ConsumerStatefulWidget {
  const _SpheresTab({required this.platformToken});

  final String platformToken;

  @override
  ConsumerState<_SpheresTab> createState() => _SpheresTabState();
}

class _SpheresTabState extends ConsumerState<_SpheresTab> {
  Category? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(platformAllCategoriesProvider(widget.platformToken));
    return Scaffold(
      body: categoriesAsync.when(
        data: (categories) {
          final selected = _selectedCategory ?? (categories.isEmpty ? null : categories.first);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                child: DropdownButtonFormField<Category>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(value: category, child: Text(category.nameEn)),
                  ],
                  onChanged: (value) => setState(() => _selectedCategory = value),
                ),
              ),
              if (selected != null)
                Expanded(
                  child: _SpheresList(category: selected, platformToken: widget.platformToken),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
      floatingActionButton: (_selectedCategory ?? categoriesAsync.value?.firstOrNull) == null
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final category = _selectedCategory ?? categoriesAsync.value!.first;
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CreateBusinessTypeDialog(platformToken: widget.platformToken, category: category),
                );
                if (created == true) {
                  ref.invalidate(platformAllBusinessTypesProvider((widget.platformToken, category.id)));
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _SpheresList extends ConsumerWidget {
  const _SpheresList({required this.category, required this.platformToken});

  final Category category;
  final String platformToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessTypesAsync = ref.watch(platformAllBusinessTypesProvider((platformToken, category.id)));
    return businessTypesAsync.when(
      data: (businessTypes) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          for (final businessType in businessTypes)
            FactorySelectableTile(
              title: businessType.nameEn,
              subtitle: Text(businessType.code),
              trailing: _StatusToggle(
                status: businessType.status,
                onToggle: (next) async {
                  await ref.read(catalogApiProvider).setBusinessTypeStatus(platformToken, businessType.id, next);
                  ref.invalidate(platformAllBusinessTypesProvider((platformToken, category.id)));
                },
              ),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _SubspheresTab extends ConsumerStatefulWidget {
  const _SubspheresTab({required this.platformToken});

  final String platformToken;

  @override
  ConsumerState<_SubspheresTab> createState() => _SubspheresTabState();
}

class _SubspheresTabState extends ConsumerState<_SubspheresTab> {
  Category? _selectedCategory;
  BusinessType? _selectedBusinessType;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(platformAllCategoriesProvider(widget.platformToken));
    return Scaffold(
      body: categoriesAsync.when(
        data: (categories) {
          final selectedCategory = _selectedCategory ?? (categories.isEmpty ? null : categories.first);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                child: DropdownButtonFormField<Category>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(value: category, child: Text(category.nameEn)),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedCategory = value;
                    _selectedBusinessType = null;
                  }),
                ),
              ),
              if (selectedCategory != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final businessTypesAsync =
                          ref.watch(platformAllBusinessTypesProvider((widget.platformToken, selectedCategory.id)));
                      return businessTypesAsync.when(
                        data: (businessTypes) {
                          final selectedBusinessType =
                              _selectedBusinessType ?? (businessTypes.isEmpty ? null : businessTypes.first);
                          return DropdownButtonFormField<BusinessType>(
                            initialValue: selectedBusinessType,
                            decoration: const InputDecoration(labelText: 'Sphere'),
                            items: [
                              for (final businessType in businessTypes)
                                DropdownMenuItem(value: businessType, child: Text(businessType.nameEn)),
                            ],
                            onChanged: (value) => setState(() => _selectedBusinessType = value),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => Text('$error'),
                      );
                    },
                  ),
                ),
              if (_selectedBusinessType != null)
                Expanded(child: _SubspheresList(businessType: _selectedBusinessType!, platformToken: widget.platformToken)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
      floatingActionButton: _selectedBusinessType == null
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final businessType = _selectedBusinessType!;
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CreateSubsphereDialog(platformToken: widget.platformToken, businessType: businessType),
                );
                if (created == true) {
                  ref.invalidate(platformAllSubspheresProvider((widget.platformToken, businessType.id)));
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _SubspheresList extends ConsumerWidget {
  const _SubspheresList({required this.businessType, required this.platformToken});

  final BusinessType businessType;
  final String platformToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subspheresAsync = ref.watch(platformAllSubspheresProvider((platformToken, businessType.id)));
    return subspheresAsync.when(
      data: (subspheres) => subspheres.isEmpty
          ? const Center(child: Text('No subspheres yet — this sphere has no drill-down level below it.'))
          : ListView(
              padding: const EdgeInsets.all(FactorySpacing.space4),
              children: [
                for (final subsphere in subspheres)
                  FactorySelectableTile(
                    title: subsphere.nameEn,
                    subtitle: Text(subsphere.code),
                    trailing: _StatusToggle(
                      status: subsphere.status,
                      onToggle: (next) async {
                        await ref.read(catalogApiProvider).setSubsphereStatus(platformToken, subsphere.id, next);
                        ref.invalidate(platformAllSubspheresProvider((platformToken, businessType.id)));
                      },
                    ),
                  ),
              ],
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

class _ServicesTab extends ConsumerStatefulWidget {
  const _ServicesTab({required this.platformToken});

  final String platformToken;

  @override
  ConsumerState<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends ConsumerState<_ServicesTab> {
  Category? _selectedCategory;
  BusinessType? _selectedBusinessType;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(platformAllCategoriesProvider(widget.platformToken));
    return Scaffold(
      body: categoriesAsync.when(
        data: (categories) {
          final selectedCategory = _selectedCategory ?? (categories.isEmpty ? null : categories.first);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(FactorySpacing.space4),
                child: DropdownButtonFormField<Category>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(value: category, child: Text(category.nameEn)),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedCategory = value;
                    _selectedBusinessType = null;
                  }),
                ),
              ),
              if (selectedCategory != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: FactorySpacing.space4),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final businessTypesAsync =
                          ref.watch(platformAllBusinessTypesProvider((widget.platformToken, selectedCategory.id)));
                      return businessTypesAsync.when(
                        data: (businessTypes) {
                          final selectedBusinessType =
                              _selectedBusinessType ?? (businessTypes.isEmpty ? null : businessTypes.first);
                          return DropdownButtonFormField<BusinessType>(
                            initialValue: selectedBusinessType,
                            decoration: const InputDecoration(labelText: 'Sphere'),
                            items: [
                              for (final businessType in businessTypes)
                                DropdownMenuItem(value: businessType, child: Text(businessType.nameEn)),
                            ],
                            onChanged: (value) => setState(() => _selectedBusinessType = value),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stackTrace) => Text('$error'),
                      );
                    },
                  ),
                ),
              if (_selectedBusinessType != null)
                Expanded(child: _ServicesList(businessType: _selectedBusinessType!, platformToken: widget.platformToken)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
      ),
      floatingActionButton: _selectedBusinessType == null
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final businessType = _selectedBusinessType!;
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CreateCatalogServiceDialog(platformToken: widget.platformToken, businessType: businessType),
                );
                if (created == true) {
                  ref.invalidate(platformAllCatalogServicesProvider((widget.platformToken, businessType.id)));
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ServicesList extends ConsumerWidget {
  const _ServicesList({required this.businessType, required this.platformToken});

  final BusinessType businessType;
  final String platformToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(platformAllCatalogServicesProvider((platformToken, businessType.id)));
    return servicesAsync.when(
      data: (services) => ListView(
        padding: const EdgeInsets.all(FactorySpacing.space4),
        children: [
          for (final service in services)
            FactorySelectableTile(
              title: service.nameEn,
              trailing: _StatusToggle(
                status: service.status,
                onToggle: (next) async {
                  await ref.read(catalogApiProvider).setCatalogServiceStatus(platformToken, service.id, next);
                  ref.invalidate(platformAllCatalogServicesProvider((platformToken, businessType.id)));
                },
              ),
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
    );
  }
}

/// Tap to flip ACTIVE <-> INACTIVE — ARCHIVED (the third TaxonomyStatus
/// value) isn't reachable from here since nothing in this tool needs to set
/// it; it stays a valid backend state, just not one this simple toggle
/// offers. Deactivating asks for confirmation first: this is the taxonomy
/// tree businesses select from, so switching a category/sphere/subsphere/
/// service off is never a single accidental tap here — reactivating stays
/// instant since it's the safe direction.
class _StatusToggle extends StatelessWidget {
  const _StatusToggle({required this.status, required this.onToggle});

  final String status;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusBadge(status: status),
        IconButton(
          icon: Icon(status == 'ACTIVE' ? Icons.toggle_on : Icons.toggle_off_outlined),
          onPressed: () => _toggle(context),
        ),
      ],
    );
  }

  Future<void> _toggle(BuildContext context) async {
    if (status != 'ACTIVE') {
      onToggle('ACTIVE');
      return;
    }
    final confirmed = await showFactoryDialog<bool>(
      context: context,
      title: 'Deactivate this?',
      message: 'It disappears from the customer and business-owner apps immediately, along with everything '
          'nested under it. It can be turned back on any time.',
      actions: [
        FactoryButton(
          label: 'Cancel',
          variant: FactoryButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        FactoryButton(label: 'Deactivate', onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
    if (confirmed == true) onToggle('INACTIVE');
  }
}

class _CreateCategoryDialog extends ConsumerStatefulWidget {
  const _CreateCategoryDialog({required this.platformToken});

  final String platformToken;

  @override
  ConsumerState<_CreateCategoryDialog> createState() => _CreateCategoryDialogState();
}

class _CreateCategoryDialogState extends ConsumerState<_CreateCategoryDialog> {
  final _codeController = TextEditingController();
  final _nameKkController = TextEditingController();
  final _nameRuController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _iconController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameKkController.dispose();
    _nameRuController.dispose();
    _nameEnController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: 'New category',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryTextField(controller: _codeController, enabled: !_isSubmitting, label: 'Code (e.g. wellness)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _iconController, enabled: !_isSubmitting, label: 'Emoji icon (optional)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameEnController, enabled: !_isSubmitting, label: 'Name (English)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameRuController, enabled: !_isSubmitting, label: 'Name (Russian)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameKkController, enabled: !_isSubmitting, label: 'Name (Kazakh)'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: FactorySpacing.space2),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(label: l10n.createButton, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
      ],
    );
  }

  Future<void> _submit() async {
    if (_codeController.text.trim().isEmpty ||
        _nameEnController.text.trim().isEmpty ||
        _nameRuController.text.trim().isEmpty ||
        _nameKkController.text.trim().isEmpty) {
      setState(() => _error = 'All fields except icon are required.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(catalogApiProvider).createCategory(
            widget.platformToken,
            code: _codeController.text.trim(),
            nameKk: _nameKkController.text.trim(),
            nameRu: _nameRuController.text.trim(),
            nameEn: _nameEnController.text.trim(),
            icon: _iconController.text.trim().isEmpty ? null : _iconController.text.trim(),
            sortOrder: 100,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isSubmitting = false;
      });
    }
  }
}

class _CreateBusinessTypeDialog extends ConsumerStatefulWidget {
  const _CreateBusinessTypeDialog({required this.platformToken, required this.category});

  final String platformToken;
  final Category category;

  @override
  ConsumerState<_CreateBusinessTypeDialog> createState() => _CreateBusinessTypeDialogState();
}

class _CreateBusinessTypeDialogState extends ConsumerState<_CreateBusinessTypeDialog> {
  final _codeController = TextEditingController();
  final _nameKkController = TextEditingController();
  final _nameRuController = TextEditingController();
  final _nameEnController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameKkController.dispose();
    _nameRuController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: 'New sphere under ${widget.category.nameEn}',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryTextField(controller: _codeController, enabled: !_isSubmitting, label: 'Code (e.g. yoga_studio)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameEnController, enabled: !_isSubmitting, label: 'Name (English)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameRuController, enabled: !_isSubmitting, label: 'Name (Russian)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameKkController, enabled: !_isSubmitting, label: 'Name (Kazakh)'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: FactorySpacing.space2),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(label: l10n.createButton, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
      ],
    );
  }

  Future<void> _submit() async {
    if (_codeController.text.trim().isEmpty ||
        _nameEnController.text.trim().isEmpty ||
        _nameRuController.text.trim().isEmpty ||
        _nameKkController.text.trim().isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(catalogApiProvider).createBusinessType(
            widget.platformToken,
            categoryId: widget.category.id,
            code: _codeController.text.trim(),
            nameKk: _nameKkController.text.trim(),
            nameRu: _nameRuController.text.trim(),
            nameEn: _nameEnController.text.trim(),
            sortOrder: 100,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isSubmitting = false;
      });
    }
  }
}

class _CreateSubsphereDialog extends ConsumerStatefulWidget {
  const _CreateSubsphereDialog({required this.platformToken, required this.businessType});

  final String platformToken;
  final BusinessType businessType;

  @override
  ConsumerState<_CreateSubsphereDialog> createState() => _CreateSubsphereDialogState();
}

class _CreateSubsphereDialogState extends ConsumerState<_CreateSubsphereDialog> {
  final _codeController = TextEditingController();
  final _nameKkController = TextEditingController();
  final _nameRuController = TextEditingController();
  final _nameEnController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameKkController.dispose();
    _nameRuController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FactoryDialog(
      title: 'New subsphere under ${widget.businessType.nameEn}',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryTextField(controller: _codeController, enabled: !_isSubmitting, label: 'Code (e.g. hot_yoga)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameEnController, enabled: !_isSubmitting, label: 'Name (English)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameRuController, enabled: !_isSubmitting, label: 'Name (Russian)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameKkController, enabled: !_isSubmitting, label: 'Name (Kazakh)'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: FactorySpacing.space2),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(label: l10n.createButton, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
      ],
    );
  }

  Future<void> _submit() async {
    if (_codeController.text.trim().isEmpty ||
        _nameEnController.text.trim().isEmpty ||
        _nameRuController.text.trim().isEmpty ||
        _nameKkController.text.trim().isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(catalogApiProvider).createSubsphere(
            widget.platformToken,
            businessTypeId: widget.businessType.id,
            code: _codeController.text.trim(),
            nameKk: _nameKkController.text.trim(),
            nameRu: _nameRuController.text.trim(),
            nameEn: _nameEnController.text.trim(),
            sortOrder: 100,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isSubmitting = false;
      });
    }
  }
}

class _CreateCatalogServiceDialog extends ConsumerStatefulWidget {
  const _CreateCatalogServiceDialog({required this.platformToken, required this.businessType});

  final String platformToken;
  final BusinessType businessType;

  @override
  ConsumerState<_CreateCatalogServiceDialog> createState() => _CreateCatalogServiceDialogState();
}

class _CreateCatalogServiceDialogState extends ConsumerState<_CreateCatalogServiceDialog> {
  final _nameKkController = TextEditingController();
  final _nameRuController = TextEditingController();
  final _nameEnController = TextEditingController();
  Subsphere? _subsphere;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameKkController.dispose();
    _nameRuController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subspheresAsync =
        ref.watch(platformAllSubspheresProvider((widget.platformToken, widget.businessType.id)));
    return FactoryDialog(
      title: 'New service under ${widget.businessType.nameEn}',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FactoryTextField(controller: _nameEnController, enabled: !_isSubmitting, label: 'Name (English)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameRuController, enabled: !_isSubmitting, label: 'Name (Russian)'),
            const SizedBox(height: FactorySpacing.space3),
            FactoryTextField(controller: _nameKkController, enabled: !_isSubmitting, label: 'Name (Kazakh)'),
            const SizedBox(height: FactorySpacing.space3),
            subspheresAsync.when(
              data: (subspheres) => subspheres.isEmpty
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<Subsphere?>(
                      initialValue: _subsphere,
                      decoration: const InputDecoration(labelText: 'Subsphere (optional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None — attach directly to sphere')),
                        for (final subsphere in subspheres)
                          DropdownMenuItem(value: subsphere, child: Text(subsphere.nameEn)),
                      ],
                      onChanged: (value) => setState(() => _subsphere = value),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: FactorySpacing.space2),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        FactoryButton(
          label: l10n.cancelButton,
          variant: FactoryButtonVariant.text,
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
        ),
        FactoryButton(label: l10n.createButton, isLoading: _isSubmitting, onPressed: _isSubmitting ? null : _submit),
      ],
    );
  }

  Future<void> _submit() async {
    if (_nameEnController.text.trim().isEmpty ||
        _nameRuController.text.trim().isEmpty ||
        _nameKkController.text.trim().isEmpty) {
      setState(() => _error = 'All name fields are required.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await ref.read(catalogApiProvider).createCatalogService(
            widget.platformToken,
            businessTypeId: widget.businessType.id,
            subsphereId: _subsphere?.id,
            nameKk: _nameKkController.text.trim(),
            nameRu: _nameRuController.text.trim(),
            nameEn: _nameEnController.text.trim(),
            sortOrder: 100,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = '$e';
        _isSubmitting = false;
      });
    }
  }
}
