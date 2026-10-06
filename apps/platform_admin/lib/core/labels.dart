import '../l10n/app_localizations.dart';
import 'widgets/common.dart';

/// Human wording for the raw codes the backend speaks. The console never
/// shows `PLATFORM_MODERATOR` or `REFUND_FAILED` to a person; an unknown code
/// falls back to a readable version of itself instead of breaking.

String roleLabel(AppLocalizations l10n, String role) => switch (role) {
  'PLATFORM_ADMIN' => l10n.roleAdmin,
  'PLATFORM_MODERATOR' => l10n.roleModerator,
  'PLATFORM_SUPPORT' => l10n.roleSupport,
  _ => humanizeCode(role),
};

String roleDescription(AppLocalizations l10n, String role) => switch (role) {
  'PLATFORM_ADMIN' => l10n.roleAdminDesc,
  'PLATFORM_MODERATOR' => l10n.roleModeratorDesc,
  'PLATFORM_SUPPORT' => l10n.roleSupportDesc,
  _ => '',
};

/// Provider (business) status.
String businessStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'PENDING' => l10n.businessPending,
  'ACTIVE' => l10n.statusActive,
  'SUSPENDED' => l10n.businessSuspended,
  _ => humanizeCode(status),
};

Tone businessStatusTone(String status) => switch (status) {
  'ACTIVE' => Tone.good,
  'PENDING' => Tone.warn,
  'SUSPENDED' => Tone.bad,
  _ => Tone.neutral,
};

/// Catalog row status.
String taxonomyStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'ACTIVE' => l10n.statusActive,
  'INACTIVE' => l10n.statusHidden,
  'ARCHIVED' => l10n.statusArchived,
  _ => humanizeCode(status),
};

String payoutStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'PAYABLE' => l10n.payoutPayable,
  'PROCESSING' => l10n.payoutProcessing,
  'PAID' => l10n.payoutPaid,
  'FAILED' => l10n.payoutFailed,
  _ => humanizeCode(status),
};

Tone payoutStatusTone(String status) => switch (status) {
  'PAID' => Tone.good,
  'PAYABLE' || 'PROCESSING' => Tone.warn,
  'FAILED' => Tone.bad,
  _ => Tone.neutral,
};

String refundRequestStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'PENDING' => l10n.refundPending,
  'PROCESSING' => l10n.refundProcessing,
  'RETRY' => l10n.refundRetry,
  'SUCCEEDED' => l10n.refundSucceeded,
  'FAILED' => l10n.refundFailed,
  _ => humanizeCode(status),
};

Tone refundRequestStatusTone(String status) => switch (status) {
  'SUCCEEDED' => Tone.good,
  'PENDING' || 'PROCESSING' || 'RETRY' => Tone.warn,
  'FAILED' => Tone.bad,
  _ => Tone.neutral,
};

String paymentStatusLabel(AppLocalizations l10n, String status) => switch (status) {
  'CREATED' => l10n.paymentCreated,
  'PENDING' => l10n.paymentPending,
  'SUCCEEDED' => l10n.paymentSucceeded,
  'FAILED' => l10n.paymentFailed,
  'REFUND_PENDING' => l10n.paymentRefundPending,
  'REFUNDED' => l10n.paymentRefunded,
  'REFUND_FAILED' => l10n.paymentRefundFailed,
  _ => humanizeCode(status),
};

String verticalLabel(AppLocalizations l10n, String vertical) => switch (vertical.toLowerCase()) {
  'beauty' => l10n.verticalBeauty,
  'auto' => l10n.verticalAuto,
  'cleaning' => l10n.verticalCleaning,
  _ => humanizeCode(vertical),
};

String auditActionLabel(AppLocalizations l10n, String action) => switch (action) {
  'CATEGORY_CREATED' => l10n.actionCategoryCreated,
  'CATEGORY_UPDATED' => l10n.actionCategoryUpdated,
  'CATEGORY_STATUS_CHANGED' => l10n.actionCategoryStatus,
  'BUSINESS_TYPE_CREATED' => l10n.actionSphereCreated,
  'BUSINESS_TYPE_UPDATED' => l10n.actionSphereUpdated,
  'BUSINESS_TYPE_STATUS_CHANGED' => l10n.actionSphereStatus,
  'SUBSPHERE_CREATED' => l10n.actionSubsphereCreated,
  'SUBSPHERE_UPDATED' => l10n.actionSubsphereUpdated,
  'SUBSPHERE_STATUS_CHANGED' => l10n.actionSubsphereStatus,
  'CATALOG_SERVICE_CREATED' => l10n.actionServiceCreated,
  'CATALOG_SERVICE_UPDATED' => l10n.actionServiceUpdated,
  'CATALOG_SERVICE_STATUS_CHANGED' => l10n.actionServiceStatus,
  'PROVIDER_STATUS_CHANGED' => l10n.actionBusinessStatus,
  'PLATFORM_ADMIN_CREATED' => l10n.actionStaffCreated,
  'PLATFORM_ADMIN_DEACTIVATED' => l10n.actionStaffDeactivated,
  'PLATFORM_ADMIN_REACTIVATED' => l10n.actionStaffReactivated,
  _ => humanizeCode(action),
};

/// Which part of the console an audit action belongs to — drives the
/// activity filter chips.
enum AuditArea { businesses, catalog, staff, other }

AuditArea auditAreaOf(String action) {
  if (action.startsWith('PROVIDER_')) return AuditArea.businesses;
  if (action.startsWith('PLATFORM_ADMIN_')) return AuditArea.staff;
  if (action.startsWith('CATEGORY_') ||
      action.startsWith('BUSINESS_TYPE_') ||
      action.startsWith('SUBSPHERE_') ||
      action.startsWith('CATALOG_SERVICE_')) {
    return AuditArea.catalog;
  }
  return AuditArea.other;
}

/// "SUSPENDED" inside an audit before/after value becomes its translated
/// name; anything else (an id, free text) is shown as is.
String auditValueLabel(AppLocalizations l10n, String? value) {
  if (value == null || value.isEmpty) return '—';
  const businessStatuses = {'PENDING', 'ACTIVE', 'SUSPENDED'};
  const taxonomyStatuses = {'INACTIVE', 'ARCHIVED'};
  if (businessStatuses.contains(value)) return businessStatusLabel(l10n, value);
  if (taxonomyStatuses.contains(value)) return taxonomyStatusLabel(l10n, value);
  if (value.startsWith('PLATFORM_')) return roleLabel(l10n, value);
  return value;
}

/// Turns an English name into a code ("Hot Yoga!" -> "hot_yoga") so the
/// person creating a catalog row doesn't have to invent an identifier.
String slugifyCode(String name) {
  return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
}

/// The backend's own pattern for catalog / city codes.
bool isValidCode(String code) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(code);
