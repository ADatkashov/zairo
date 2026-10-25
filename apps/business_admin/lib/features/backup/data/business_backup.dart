/// Mirrors backend's BusinessBackupDtos.BackupResponse
/// (backend/provider-insights/.../BusinessBackupDtos.java): one business's schedule, customers and services
/// as an owner keeps them to work from while the app is unavailable.
class BusinessBackup {
  final String providerId;

  /// Filled in by the app (the response itself carries only the id), so the file can say which business a row is of.
  final String providerName;
  final DateTime generatedAt;
  final DateTime from;
  final DateTime to;
  final List<BackupBooking> bookings;
  final List<BackupCustomer> customers;
  final List<BackupService> services;

  const BusinessBackup({
    required this.providerId,
    required this.providerName,
    required this.generatedAt,
    required this.from,
    required this.to,
    required this.bookings,
    required this.customers,
    required this.services,
  });

  factory BusinessBackup.fromJson(Map<String, dynamic> json, {required String providerName}) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final e in (json[key] as List<dynamic>? ?? const [])) parse(e as Map<String, dynamic>),
    ];
    return BusinessBackup(
      providerId: json['providerId'] as String,
      providerName: providerName,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      bookings: list('bookings', BackupBooking.fromJson),
      customers: list('customers', BackupCustomer.fromJson),
      services: list('services', BackupService.fromJson),
    );
  }
}

class BackupBooking {
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String? serviceTitle;
  final String? staffName;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double totalPrice;
  final String? currency;

  const BackupBooking({
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.serviceTitle,
    this.staffName,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.totalPrice,
    this.currency,
  });

  factory BackupBooking.fromJson(Map<String, dynamic> json) => BackupBooking(
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: DateTime.parse(json['endsAt'] as String),
    status: json['status'] as String,
    serviceTitle: json['serviceTitle'] as String?,
    staffName: json['staffName'] as String?,
    customerName: json['customerName'] as String?,
    customerPhone: json['customerPhone'] as String?,
    customerEmail: json['customerEmail'] as String?,
    totalPrice: (json['totalPrice'] as num).toDouble(),
    currency: json['currency'] as String?,
  );
}

class BackupCustomer {
  final String? name;
  final String? phone;
  final String? email;
  final DateTime? lastVisitAt;
  final int totalBookings;
  final double totalSpent;
  final String? currency;
  final int noShows;

  const BackupCustomer({
    this.name,
    this.phone,
    this.email,
    this.lastVisitAt,
    required this.totalBookings,
    required this.totalSpent,
    this.currency,
    required this.noShows,
  });

  factory BackupCustomer.fromJson(Map<String, dynamic> json) => BackupCustomer(
    name: json['name'] as String?,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    lastVisitAt: json['lastVisitAt'] == null ? null : DateTime.parse(json['lastVisitAt'] as String),
    totalBookings: (json['totalBookings'] as num).toInt(),
    totalSpent: (json['totalSpent'] as num).toDouble(),
    currency: json['currency'] as String?,
    noShows: (json['noShows'] as num).toInt(),
  );
}

class BackupService {
  final String title;
  final int durationMinutes;
  final double price;
  final String? currency;
  final bool active;

  const BackupService({
    required this.title,
    required this.durationMinutes,
    required this.price,
    this.currency,
    required this.active,
  });

  factory BackupService.fromJson(Map<String, dynamic> json) => BackupService(
    title: json['title'] as String,
    durationMinutes: (json['durationMinutes'] as num).toInt(),
    price: (json['price'] as num).toDouble(),
    currency: json['currency'] as String?,
    active: json['active'] as bool,
  );
}
