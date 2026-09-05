import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../catalog/data/models/business_type.dart';
import '../../../catalog/data/models/category.dart';
import '../../../catalog/data/models/subsphere.dart';
import '../../../catalog/presentation/providers/catalog_providers.dart';
import '../providers/platform_admin_providers.dart';

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

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.email),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Categories'),
              Tab(text: 'Spheres'),
              Tab(text: 'Subspheres'),
              Tab(text: 'Services'),
            ],
          ),
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
        body: TabBarView(
          children: [
            _CategoriesTab(platformToken: session.accessToken),
            _SpheresTab(platformToken: session.accessToken),
            _SubspheresTab(platformToken: session.accessToken),
            _ServicesTab(platformToken: session.accessToken),
          ],
        ),
      ),
    );
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

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({required this.platformToken});

  final String platformToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
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
                    ref.invalidate(categoriesProvider);
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
          if (created == true) ref.invalidate(categoriesProvider);
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
    final categoriesAsync = ref.watch(categoriesProvider);
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
              if (selected != null) Expanded(child: _SpheresList(category: selected, platformToken: widget.platformToken)),
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
                if (created == true) ref.invalidate(businessTypesProvider(category.id));
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
    final businessTypesAsync = ref.watch(businessTypesProvider(category.id));
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
                  ref.invalidate(businessTypesProvider(category.id));
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
    final categoriesAsync = ref.watch(categoriesProvider);
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
                      final businessTypesAsync = ref.watch(businessTypesProvider(selectedCategory.id));
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
                if (created == true) ref.invalidate(subspheresProvider(businessType.id));
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
    final subspheresAsync = ref.watch(subspheresProvider(businessType.id));
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
                        ref.invalidate(subspheresProvider(businessType.id));
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
    final categoriesAsync = ref.watch(categoriesProvider);
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
                      final businessTypesAsync = ref.watch(businessTypesProvider(selectedCategory.id));
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
                if (created == true) ref.invalidate(catalogServicesProvider(businessType.id));
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
    final servicesAsync = ref.watch(catalogServicesProvider(businessType.id));
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
                  ref.invalidate(catalogServicesProvider(businessType.id));
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
/// offers.
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
          onPressed: () => onToggle(status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'),
        ),
      ],
    );
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
    final subspheresAsync = ref.watch(subspheresProvider(widget.businessType.id));
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
