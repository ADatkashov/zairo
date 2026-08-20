import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:business_admin/app/app.dart';
import 'package:business_admin/core/constants/environment.dart';

class _InMemorySecureStorageService extends SecureStorageService {
  _InMemorySecureStorageService() : super(const FlutterSecureStorage());

  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

void main() {
  testWidgets('App smoke test — shows the login screen when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkConfigProvider.overrideWithValue(adminNetworkConfig),
          secureStorageServiceProvider.overrideWithValue(_InMemorySecureStorageService()),
        ],
        child: const BusinessAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Business Admin — Log in'), findsOneWidget);
  });
}
