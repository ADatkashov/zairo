import '../../../l10n/app_localizations.dart';

/// Human wording for the raw codes the platform API speaks (roles, statuses,
/// audit actions). The console never shows a code like `PLATFORM_MODERATOR`
/// or `SUSPENDED` to a person — anything unknown falls back to a readable
/// version of the code rather than breaking.

String platformRoleLabel(AppLocalizations l10n, String role) => switch (role) {
  'PLATFORM_ADMIN' => l10n.paRoleAdmin,
  'PLATFORM_MODERATOR' => l10n.paRoleModerator,
  'PLATFORM_SUPPORT' => l10n.paRoleSupport,
  _ => humanizeCode(role),
};

String platformRoleDescription(AppLocalizations l10n, String role) => switch (role) {
  'PLATFORM_ADMIN' => l10n.paRoleAdminDesc,
  'PLATFORM_MODERATOR' => l10n.paRoleModeratorDesc,
  'PLATFORM_SUPPORT' => l10n.paRoleSupportDesc,
  _ => '',
};

String platformStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'PENDING' => l10n.paStatusPending,
  'ACTIVE' => l10n.paStatusActive,
  'SUSPENDED' => l10n.paStatusSuspended,
  'INACTIVE' => l10n.paStatusInactive,
  'ARCHIVED' => l10n.paStatusArchived,
  _ => humanizeCode(status),
};

String platformAuditActionLabel(AppLocalizations l10n, String action) => switch (action) {
  'CATEGORY_CREATED' => l10n.paActionCategoryCreated,
  'CATEGORY_UPDATED' => l10n.paActionCategoryUpdated,
  'CATEGORY_STATUS_CHANGED' => l10n.paActionCategoryStatus,
  'BUSINESS_TYPE_CREATED' => l10n.paActionSphereCreated,
  'BUSINESS_TYPE_UPDATED' => l10n.paActionSphereUpdated,
  'BUSINESS_TYPE_STATUS_CHANGED' => l10n.paActionSphereStatus,
  'SUBSPHERE_CREATED' => l10n.paActionSubsphereCreated,
  'SUBSPHERE_UPDATED' => l10n.paActionSubsphereUpdated,
  'SUBSPHERE_STATUS_CHANGED' => l10n.paActionSubsphereStatus,
  'CATALOG_SERVICE_CREATED' => l10n.paActionServiceCreated,
  'CATALOG_SERVICE_UPDATED' => l10n.paActionServiceUpdated,
  'CATALOG_SERVICE_STATUS_CHANGED' => l10n.paActionServiceStatus,
  'PROVIDER_STATUS_CHANGED' => l10n.paActionBusinessStatus,
  'PLATFORM_ADMIN_CREATED' => l10n.paActionStaffCreated,
  'PLATFORM_ADMIN_DEACTIVATED' => l10n.paActionStaffDeactivated,
  'PLATFORM_ADMIN_REACTIVATED' => l10n.paActionStaffReactivated,
  _ => humanizeCode(action),
};

/// "beauty" -> the vertical's translated name; an unknown vertical is shown
/// capitalised instead.
String platformVerticalLabel(AppLocalizations l10n, String vertical) => switch (vertical.toLowerCase()) {
  'beauty' => l10n.verticalBeautyLabel,
  'auto' => l10n.verticalAutoLabel,
  'cleaning' => l10n.verticalCleaningLabel,
  _ => humanizeCode(vertical),
};

/// "SOME_CODE" -> "Some code".
String humanizeCode(String code) {
  final words = code.replaceAll('_', ' ').trim().toLowerCase();
  return words.isEmpty ? code : '${words[0].toUpperCase()}${words.substring(1)}';
}

/// Turns an English name into a code for the catalog ("Hot Yoga!" ->
/// "hot_yoga") so the person creating an item doesn't have to invent one.
String slugifyCode(String name) {
  return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
}

final _codePattern = RegExp(r'^[a-z0-9_]+$');

bool isValidCatalogCode(String code) => _codePattern.hasMatch(code);

String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
