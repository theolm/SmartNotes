import 'dart:io';
import 'package:smartnotes/core/utils/inference_trace.dart';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/gpu_circuit_store.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';
import 'package:smartnotes/domain/entities/speech_acceleration.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';
import 'package:smartnotes/domain/services/i_settings_service.dart';
import 'package:smartnotes/domain/services/i_speech_acceleration_service.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

typedef GpuCapabilityProbe = Future<WhisperCapabilities> Function();

/// Device capability, preference, and crash-circuit policy for speech only.
/// It never touches audio, transcripts, entry IDs, or model paths.
@LazySingleton(as: ISpeechAccelerationService)
class SpeechAccelerationService implements ISpeechAccelerationService {
  SpeechAccelerationService(
    this._settings,
    this._deviceProfile,
    this._circuit,
  ) : _probe = _probeVulkan,
      _isAndroid = Platform.isAndroid;

  @visibleForTesting
  SpeechAccelerationService.forTesting(
    this._settings,
    this._deviceProfile,
    this._circuit, {
    required GpuCapabilityProbe probe,
    required bool isAndroid,
  }) : // Fields are private; the testing parameters must stay injectable by
       // their public names, so initializing formals are not possible here.
       // ignore: prefer_initializing_formals
       _probe = probe,
       // ignore: prefer_initializing_formals
       _isAndroid = isAndroid;

  final ISettingsService _settings;
  final DeviceProfileService _deviceProfile;
  final GpuCircuitStore _circuit;
  final GpuCapabilityProbe _probe;
  final bool _isAndroid;

  GpuCircuitState? _circuitState;
  DeviceProfile? _profile;
  WhisperCapabilities? _capabilities;
  Future<void>? _initializing;
  bool _attemptActive = false;
  bool _probeFailed = false;
  Future<SpeechAccelerationStatus>? _probing;

  void _storageFailed() {
    _circuitState = const GpuCircuitState(
      open: true,
      reason: 'storage_unavailable',
    );
  }

  static Future<WhisperCapabilities> _probeVulkan() =>
      Whisper.probeCapabilities(backend: WhisperBackend.vulkan);

  @override
  Future<void> initialize() async {
    final pending = _initializing ??= _initialize();
    try {
      await pending;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    try {
      _circuitState = await _circuit.read();
    } catch (_) {
      _storageFailed();
    }
  }

  @override
  Future<SpeechAccelerationStatus> status({
    bool refresh = false,
    bool probe = false,
  }) async {
    await initialize();
    if (refresh && !_attemptActive && _probing == null) {
      _capabilities = null;
      _probeFailed = false;
      _profile = null;
      // Read persisted interruption state only at startup. Refresh must not
      // mistake this process's own pending marker for a previous crash.
    }
    if (!_settings.getSpeechGpuPreferred()) {
      return const SpeechAccelerationStatus(
        state: SpeechAccelerationState.disabledByUser,
        reason: SpeechBackendReason.userDisabled,
      );
    }
    final circuit = _circuitState ?? const GpuCircuitState();
    if (circuit.open) {
      return SpeechAccelerationStatus(
        state: SpeechAccelerationState.circuitOpen,
        reason: SpeechBackendReason.circuitOpen,
        runtime: circuit.runtime,
        failureCode: circuit.reason,
      );
    }
    final profile = _profile ??= await _deviceProfile.read();
    if (!_isAndroid || !profile.supportsArm64 || profile.hasVulkan11 != true) {
      return const SpeechAccelerationStatus(
        state: SpeechAccelerationState.unsupportedDevice,
        reason: SpeechBackendReason.unsupportedDevice,
      );
    }
    final cached = _capabilities;
    if (cached != null) {
      return _available(cached);
    }
    if (_probeFailed) {
      return const SpeechAccelerationStatus(
        state: SpeechAccelerationState.capabilityFailed,
        reason: SpeechBackendReason.capabilityFailed,
      );
    }
    if (!probe) {
      return const SpeechAccelerationStatus(
        state: SpeechAccelerationState.checking,
      );
    }
    final pending = _probing ??= _probeGuarded();
    final SpeechAccelerationStatus result;
    try {
      result = await pending;
    } finally {
      if (identical(_probing, pending)) _probing = null;
    }
    // Probing itself can persist a failure (unreadable or unwritable state).
    if (_circuitState?.open == true) return status();
    return result;
  }

  Future<SpeechAccelerationStatus> _probeGuarded() async {
    // Loading the library and enumerating devices can crash inside the driver.
    // Persist before either operation, including probes from the settings UI.
    try {
      await _circuit.begin(model: 'capability_probe');
    } catch (_) {
      _storageFailed();
      return status();
    }
    try {
      final capabilities = await InferenceTrace.run('gpu.probe', _probe);
      _capabilities = capabilities;
      if (!capabilities.vulkanAvailable) _probeFailed = true;
      return _available(capabilities);
    } catch (_) {
      _probeFailed = true;
      return const SpeechAccelerationStatus(
        state: SpeechAccelerationState.capabilityFailed,
        reason: SpeechBackendReason.capabilityFailed,
      );
    } finally {
      try {
        await _circuit.complete(runtime: _capabilities?.runtime);
      } catch (_) {
        _storageFailed();
      }
    }
  }

  SpeechAccelerationStatus _available(WhisperCapabilities capabilities) {
    if (!capabilities.vulkanAvailable) {
      return const SpeechAccelerationStatus(
        state: SpeechAccelerationState.capabilityFailed,
        reason: SpeechBackendReason.capabilityFailed,
      );
    }
    return SpeechAccelerationStatus(
      state: SpeechAccelerationState.available,
      reason: SpeechBackendReason.gpuReady,
      deviceName: capabilities.deviceName,
      runtime: capabilities.runtime,
    );
  }

  @override
  Future<SpeechBackendDecision> decide({
    required SpeechModel model,
    required Duration audioDuration,
  }) async {
    final current = await status(probe: true);
    return SpeechBackendPolicy.decide(
      preferred: _settings.getSpeechGpuPreferred(),
      status: current,
      model: model,
      audioDuration: audioDuration,
    );
  }

  @override
  Future<bool> beginGpuAttempt(SpeechModel model) async {
    await initialize();
    await _probing;
    if (_attemptActive ||
        _circuitState?.open == true ||
        !_settings.getSpeechGpuPreferred()) {
      return false;
    }
    _attemptActive = true;
    try {
      final runtime = _capabilities?.runtime;
      await _circuit.begin(model: model.id, runtime: runtime);
      InferenceTrace.event('gpu.marker.begin', {'model': model.id});
      return true;
    } catch (_) {
      _attemptActive = false;
      _storageFailed();
      return false;
    }
  }

  @override
  Future<void> completeGpuAttempt() async {
    try {
      await _circuit.complete(runtime: _capabilities?.runtime);
      InferenceTrace.event('gpu.marker.complete');
    } catch (_) {
      _storageFailed();
      // A failed cleanup must not discard a successful transcription. The
      // orphan marker is handled as an interruption on the next launch.
    } finally {
      _attemptActive = false;
    }
  }

  @override
  Future<void> recordGpuFailure({
    required SpeechModel model,
    required String code,
  }) async {
    try {
      await _circuit.recordFailure(
        model: model.id,
        code: code,
        runtime: _capabilities?.runtime,
      );
      _circuitState = await _circuit.read();
    } catch (_) {
      _storageFailed();
    }
  }

  @override
  Future<SpeechAccelerationStatus> resetCircuit() async {
    // Do not remove an active native operation's crash guard.
    if (_attemptActive || _probing != null) return status();
    try {
      await _circuit.reset();
    } catch (_) {
      _storageFailed();
      return status();
    }
    _circuitState = const GpuCircuitState();
    _capabilities = null;
    _probeFailed = false;
    return status(probe: true);
  }
}
