import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:smartnotes/domain/entities/device_profile.dart';

/// No identifiers or network access. Platform failure is a safe unknown profile.
@lazySingleton
class DeviceProfileService {
  static const channel = MethodChannel('dev.theolm.smartnotes/device');

  Future<DeviceProfile> read() async {
    try {
      final data = await channel
          .invokeMapMethod<String, dynamic>('profile')
          .timeout(const Duration(seconds: 2));
      return DeviceProfile(
        memoryBytes: data?['memoryBytes'] as int?,
        lowMemory: data?['lowMemory'] == true,
        is64Bit: data?['is64Bit'] == true,
        processors: data?['processors'] as int?,
        soc: data?['soc'] as String?,
        sdkInt: data?['sdkInt'] as int?,
        supportedAbis:
            (data?['abis'] as List<dynamic>?)
                ?.whereType<String>()
                .toList(growable: false) ??
            const [],
        hasVulkan11: data?['vulkan11'] == true,
      );
    } on Exception {
      return const DeviceProfile();
    }
  }

  Future<int?> freeStorage() async {
    try {
      return await channel
          .invokeMethod<int>('freeStorage')
          .timeout(const Duration(seconds: 2));
    } on Exception {
      return null;
    }
  }
}
