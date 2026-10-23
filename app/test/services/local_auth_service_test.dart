import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/data/services/local_auth_service.dart';
import 'package:smartnotes/domain/services/i_local_auth_service.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  late MockLocalAuthentication mockLocalAuth;
  late LocalAuthService service;

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
    service = LocalAuthService(mockLocalAuth);
  });

  group('LocalAuthService', () {
    test('isAvailable returns true when the device is supported', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => true);

      expect(await service.isAvailable(), true);
    });

    test(
      'isAvailable returns false when the device is not supported',
      () async {
        when(
          () => mockLocalAuth.isDeviceSupported(),
        ).thenAnswer((_) async => false);

        expect(await service.isAvailable(), false);
      },
    );

    test('isAvailable returns false when the platform check throws', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenThrow(Exception('platform error'));

      expect(await service.isAvailable(), false);
    });

    test('returns unavailable when the device is not supported', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => false);

      final result = await service.authenticate(reason: 'Unlock SmartNotes');

      expect(result, LocalAuthResult.unavailable);
      verifyNever(
        () => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      );
    });

    test('returns success when authentication succeeds', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenAnswer((_) async => true);

      final result = await service.authenticate(reason: 'Unlock SmartNotes');

      expect(result, LocalAuthResult.success);
      verify(
        () => mockLocalAuth.authenticate(
          localizedReason: 'Unlock SmartNotes',
          biometricOnly: false,
        ),
      ).called(1);
    });

    test('returns cancelled when the user dismisses the prompt', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenAnswer((_) async => false);

      final result = await service.authenticate(reason: 'Unlock SmartNotes');

      expect(result, LocalAuthResult.cancelled);
    });

    test('maps userCanceled exception to cancelled', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenThrow(
        const LocalAuthException(code: LocalAuthExceptionCode.userCanceled),
      );

      final result = await service.authenticate(reason: 'Unlock SmartNotes');

      expect(result, LocalAuthResult.cancelled);
    });

    test('maps noCredentialsSet exception to unavailable', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenThrow(
        const LocalAuthException(code: LocalAuthExceptionCode.noCredentialsSet),
      );

      final result = await service.authenticate(reason: 'Unlock SmartNotes');

      expect(result, LocalAuthResult.unavailable);
    });

    test('maps unknown exception to failed', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenThrow(
        const LocalAuthException(code: LocalAuthExceptionCode.deviceError),
      );

      final result = await service.authenticate(reason: 'Unlock SmartNotes');

      expect(result, LocalAuthResult.failed);
    });

    test('maps unexpected error to failed', () async {
      when(
        () => mockLocalAuth.isDeviceSupported(),
      ).thenAnswer((_) async => true);
      when(
        () => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        ),
      ).thenThrow(Exception('boom'));

      final result = await service.authenticate(reason: 'Unlock SmartNotes');

      expect(result, LocalAuthResult.failed);
    });
  });
}
