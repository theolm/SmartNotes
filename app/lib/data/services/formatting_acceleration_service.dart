import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/gpu_circuit_store.dart';
import 'package:smartnotes/domain/entities/formatting_acceleration.dart';
import 'package:smartnotes/domain/services/i_formatting_acceleration_service.dart';

@LazySingleton(as: IFormattingAccelerationService)
class FormattingAccelerationService implements IFormattingAccelerationService {
  FormattingAccelerationService(this._preferences, this._device)
    : _circuit = GpuCircuitStore.formatting(),
      _profiles = FormattingBackendPolicy.qualifiedProfiles;

  FormattingAccelerationService.forTesting(
    this._preferences,
    this._device,
    this._circuit, {
    List<FormattingGpuProfile> profiles =
        FormattingBackendPolicy.qualifiedProfiles,
    // Public test argument; the field remains private.
    // ignore: prefer_initializing_formals
  }) : _profiles = profiles;

  static const preferenceKey = 'formattingGpuPreferred';
  final SharedPreferences _preferences;
  final DeviceProfileService _device;
  final GpuCircuitStore _circuit;
  final List<FormattingGpuProfile> _profiles;
  final _changes = StreamController<FormattingAccelerationStatus>.broadcast();
  Future<void>? _initializing;
  bool _open = false;
  bool _active = false;
  FormattingRunReport? _lastRun;

  @override
  FormattingAccelerationStatus get status => FormattingAccelerationStatus(
    preferred: _preferences.getBool(preferenceKey) ?? false,
    circuitOpen: _open,
    busy: _active,
    lastRun: _lastRun,
  );

  @override
  Stream<FormattingAccelerationStatus> get changes => _changes.stream;
  void _emit() => _changes.add(status);

  @override
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      _open = (await _circuit.read()).open;
    } catch (_) {
      _open = true;
    }
    _emit();
  }

  @override
  Future<void> setPreferred(bool preferred) async {
    if (!await _preferences.setBool(preferenceKey, preferred)) {
      throw StateError('Formatting preference could not be saved');
    }
    _emit();
  }

  @override
  Future<void> resetCircuit() async {
    await initialize();
    if (_active) return;
    // Reserve ownership while awaiting storage so begin() cannot race reset().
    _active = true;
    try {
      await _circuit.reset();
      _open = false;
    } catch (_) {
      _open = true;
      rethrow;
    } finally {
      _active = false;
      _emit();
    }
  }

  @override
  Future<FormattingBackendDecision> decide(
    String modelId,
    FormattingWorkload workload,
  ) async {
    await initialize();
    // No GPU enumeration in settings or before the native crash marker.
    final profile = await _device.read();
    return FormattingBackendPolicy.decide(
      preferred: status.preferred,
      circuitOpen: _open || _active,
      hardware: profile.hardwareIdentity,
      modelId: modelId,
      workload: workload,
      memoryBytes: profile.memoryBytes,
      availableBytes: profile.availableMemoryBytes,
      lowMemory: profile.lowMemory || profile.memoryPressure,
      profiles: _profiles,
    );
  }

  @override
  Future<bool> begin(String modelId, FormattingBackendDecision decision) async {
    await initialize();
    if (!decision.usesGpu || _open || _active || !status.preferred) {
      return false;
    }
    _active = true;
    try {
      final profile = await _device.read();
      await _circuit.begin(
        model: modelId,
        // A previous interrupted attempt must not reopen on a new OS/build.
        runtime:
            '${FormattingBackendPolicy.runtime}/${decision.profile!.id}/'
            '${profile.runtimeIdentity}',
      );
      _emit();
      return true;
    } catch (_) {
      _open = true;
      _active = false;
      _emit();
      return false;
    }
  }

  @override
  Future<bool> canRetryOnCpu(FormattingBackendDecision decision) async {
    final profile = await _device.read();
    final minimum = decision.profile?.minimumAvailableBytes;
    return minimum != null &&
        !profile.lowMemory &&
        !profile.memoryPressure &&
        (profile.availableMemoryBytes ?? 0) >= minimum;
  }

  @override
  Future<void> finish(String modelId, {required bool backendFailed}) async {
    try {
      if (backendFailed) {
        await _circuit.recordFailure(
          model: modelId,
          code: 'backend_unavailable',
        );
        _open = (await _circuit.read()).open;
      } else {
        await _circuit.complete();
      }
    } catch (_) {
      _open = true;
    } finally {
      _active = false;
      _emit();
    }
  }

  @override
  void cleanupFailed() {
    // Keep marker and ownership: no more GPU work or reset in this process.
    _open = true;
    _emit();
  }

  @override
  void report(FormattingRunReport report) {
    _lastRun = report;
    _emit();
  }

  @disposeMethod
  @override
  Future<void> dispose() => _changes.close();
}
