import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';

/// Local capability channel smoke test. Uses no journal or personal data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('reports local hardware capability without identifiers', (
    tester,
  ) async {
    final service = DeviceProfileService();
    final profile = await service.read();
    expect(profile.memoryBytes, isNotNull);
    expect(profile.memoryBytes, greaterThan(0));
    expect(profile.processors, isNotNull);
    expect(profile.processors, greaterThan(0));
    final freeStorage = await service.freeStorage();
    expect(freeStorage, isNotNull);
    expect(freeStorage, greaterThan(0));
  });
}
