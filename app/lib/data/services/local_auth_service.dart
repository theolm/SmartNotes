import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';

import 'package:smartnotes/domain/services/i_local_auth_service.dart';

@Injectable(as: ILocalAuthService)
class LocalAuthService implements ILocalAuthService {
  LocalAuthService(this._localAuth);

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<LocalAuthResult> authenticate({required String reason}) async {
    try {
      if (!await _localAuth.isDeviceSupported()) {
        return LocalAuthResult.unavailable;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        // Allow device credentials (PIN/pattern/passcode) as the platform
        // fallback when biometrics are unavailable.
        biometricOnly: false,
      );
      return authenticated
          ? LocalAuthResult.success
          : LocalAuthResult.cancelled;
    } on LocalAuthException catch (e) {
      return _mapException(e.code);
    } catch (_) {
      return LocalAuthResult.failed;
    }
  }

  LocalAuthResult _mapException(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        return LocalAuthResult.cancelled;
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return LocalAuthResult.unavailable;
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.uiUnavailable:
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
      case LocalAuthExceptionCode.userRequestedFallback:
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return LocalAuthResult.failed;
    }
  }
}
