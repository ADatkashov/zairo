/// Mirrors backend's VehicleDtos.VehicleResponse
/// (backend/vertical-auto/.../VehicleDtos.java).
class Vehicle {
  final String id;
  final String ownerUserId;
  final String make;
  final String model;
  final int year;
  final String licensePlate;

  const Vehicle({
    required this.id,
    required this.ownerUserId,
    required this.make,
    required this.model,
    required this.year,
    required this.licensePlate,
  });

  String get displayName => '$make $model ($year)';

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      licensePlate: json['licensePlate'] as String,
    );
  }
}
