/// Result of a local authentication attempt
/// (biometrics or device credentials).
enum LocalAuthResult {
  /// The user successfully authenticated.
  success,

  /// The user cancelled or dismissed the authentication prompt.
  cancelled,

  /// Local authentication is not available on this device
  /// (no biometric hardware, no enrolled biometrics, or no credentials set).
  unavailable,

  /// Authentication failed for another reason; the user may retry.
  failed,
}

abstract class ILocalAuthService {
  /// Whether the device can perform local authentication — biometrics
  /// (fingerprint/face) or device credentials (PIN/pattern/passcode).
  Future<bool> isAvailable();

  /// Prompts the user to authenticate locally (fingerprint, face, or device
  /// credentials such as PIN/pattern/passcode).
  ///
  /// Never throws; outcomes are reported through [LocalAuthResult].
  Future<LocalAuthResult> authenticate({required String reason});
}
