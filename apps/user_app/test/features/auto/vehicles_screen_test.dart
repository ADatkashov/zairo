import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zairo/features/auto/data/auto_api.dart';
import 'package:zairo/features/auto/data/models/vehicle.dart';
import 'package:zairo/features/auto/presentation/providers/auto_providers.dart';
import 'package:zairo/features/auto/presentation/screens/vehicles_screen.dart';
import 'package:zairo/l10n/app_localizations.dart';

class _FakeAutoApi extends AutoApi {
  _FakeAutoApi(List<Vehicle> vehicles) : _vehicles = List.of(vehicles), super(DioClient(Dio()));

  final List<Vehicle> _vehicles;
  Map<String, dynamic>? lastRegisterCall;
  String? lastDeletedId;

  @override
  Future<List<Vehicle>> listVehicles(String userId) async => List.of(_vehicles);

  @override
  Future<Vehicle> registerVehicle({
    required String ownerUserId,
    required String make,
    required String model,
    required int year,
    required String licensePlate,
  }) async {
    lastRegisterCall = {
      'ownerUserId': ownerUserId,
      'make': make,
      'model': model,
      'year': year,
      'licensePlate': licensePlate,
    };
    final vehicle = Vehicle(
      id: 'vehicle-new',
      ownerUserId: ownerUserId,
      make: make,
      model: model,
      year: year,
      licensePlate: licensePlate,
    );
    _vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    lastDeletedId = vehicleId;
    _vehicles.removeWhere((v) => v.id == vehicleId);
  }
}

Widget _wrap(AutoApi api, Widget child) {
  return ProviderScope(
    overrides: [autoApiProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: factoryLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('shows an empty state when the user has no vehicles yet', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAutoApi(const []), const VehiclesScreen(userId: 'user-1')));
    await tester.pumpAndSettle();

    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(find.text('Add a vehicle to book an auto service.'), findsOneWidget);
  });

  testWidgets('shows vehicle details once loaded', (tester) async {
    final api = _FakeAutoApi(const [
      Vehicle(id: 'v1', ownerUserId: 'user-1', make: 'Toyota', model: 'Camry', year: 2019, licensePlate: '777 ABC 02'),
    ]);

    await tester.pumpWidget(_wrap(api, const VehiclesScreen(userId: 'user-1')));
    await tester.pumpAndSettle();

    expect(find.text('Toyota Camry (2019)'), findsOneWidget);
    expect(find.text('777 ABC 02'), findsOneWidget);
  });

  testWidgets('adding a vehicle via the dialog calls the API with the entered fields', (tester) async {
    final api = _FakeAutoApi(const []);

    await tester.pumpWidget(_wrap(api, const VehiclesScreen(userId: 'user-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add vehicle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Make'), 'Honda');
    await tester.enterText(find.widgetWithText(TextFormField, 'Model'), 'Civic');
    await tester.enterText(find.widgetWithText(TextFormField, 'Year'), '2021');
    await tester.enterText(find.widgetWithText(TextFormField, 'License plate'), '999 XYZ 01');
    await tester.tap(find.widgetWithText(FilledButton, 'Add vehicle'));
    await tester.pumpAndSettle();

    expect(api.lastRegisterCall, {
      'ownerUserId': 'user-1',
      'make': 'Honda',
      'model': 'Civic',
      'year': 2021,
      'licensePlate': '999 XYZ 01',
    });
    expect(find.text('Honda Civic (2021)'), findsOneWidget);
  });

  testWidgets('deleting a vehicle asks for confirmation before calling the API', (tester) async {
    final api = _FakeAutoApi(const [
      Vehicle(id: 'v1', ownerUserId: 'user-1', make: 'Toyota', model: 'Camry', year: 2019, licensePlate: '777 ABC 02'),
    ]);

    await tester.pumpWidget(_wrap(api, const VehiclesScreen(userId: 'user-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this vehicle?'), findsOneWidget);
    expect(api.lastDeletedId, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(api.lastDeletedId, 'v1');
    expect(find.text('Toyota Camry (2019)'), findsNothing);
    expect(find.text('No vehicles yet'), findsOneWidget);
  });
}
