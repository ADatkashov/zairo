/// What each platform role may do — mirrors the backend's checks
/// (`PlatformCurrentAdmin`), so the console only offers actions the server
/// would accept instead of letting someone tap a button that ends in "403".
///
/// - PLATFORM_ADMIN: everything, including staff accounts.
/// - PLATFORM_MODERATOR: reads everything, approves / suspends businesses.
/// - PLATFORM_SUPPORT: reads everything; changes nothing.
class PlatformPermissions {
  final String role;

  const PlatformPermissions(this.role);

  bool get isAdmin => role == 'PLATFORM_ADMIN';

  /// Approve, suspend or reinstate a business.
  bool get canModerateBusinesses => isAdmin || role == 'PLATFORM_MODERATOR';

  /// Create / edit / hide categories, spheres, subspheres and services.
  bool get canEditCatalog => isAdmin;

  /// Create / edit / delete cities.
  bool get canEditCities => isAdmin;

  /// Mark payouts processing / paid / failed.
  bool get canSettlePayouts => isAdmin;

  /// Add, deactivate and reactivate staff accounts.
  bool get canManageStaff => isAdmin;

  /// Compare a payment with the payment provider (read-only on the provider).
  bool get canReconcile => true;
}
