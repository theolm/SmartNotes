import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:smartnotes/data/datasources/local/file_storage_service.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
}

void main() {
  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProvider();
  });

  group('FileStorageService', () {
    late FileStorageService service;

    setUp(() {
      service = FileStorageService();
    });

    test('getAudioDirectoryPath returns existing directory', () async {
      final path = await service.getAudioDirectoryPath();

      expect(path.contains('audio'), true);
      expect(Directory(path).existsSync(), true);
    });

    test('generateAudioFilePath returns unique path', () async {
      final first = await service.generateAudioFilePath();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await service.generateAudioFilePath();

      expect(first, isNot(second));
      expect(first.endsWith('.m4a'), true);
    });

    test('deleteFile removes file', () async {
      final file = File('${Directory.systemTemp.path}/test_delete.m4a')
        ..writeAsStringSync('audio');

      await service.deleteFile(file.path);

      expect(file.existsSync(), false);
    });

    test('exists returns true for existing file', () async {
      final file = File('${Directory.systemTemp.path}/test_exists.m4a')
        ..writeAsStringSync('audio');

      final result = await service.exists(file.path);

      expect(result, true);
      await service.deleteFile(file.path);
    });
  });
}
