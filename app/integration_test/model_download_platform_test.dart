import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/testing.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartnotes/data/services/platform_model_downloader.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';

/// Run only in a separate test application ID. Never touches installed models.
/// Uses a small pinned public license instead of downloading AI weights.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = PlatformModelDownloader();
  const folder = 'download_test';
  const fixtureHash =
      '2cfa3ee8e7512e6d44c854b986510810fadc815f93f890373b3a81c1b6ccd256';
  LocalAiModel fixture(String id, {String hash = fixtureHash}) => LocalAiModel(
    id: id,
    name: 'Download test fixture',
    fileName: '$id.bin',
    url: 'https://raw.githubusercontent.com/dart-lang/sdk/3.12.0/LICENSE',
    bytes: 1502,
    sha256: hash,
  );

  Future<ModelTransfer> waitFor(
    String id,
    bool Function(ModelTransfer) predicate,
  ) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (DateTime.now().isBefore(deadline)) {
      final state = (await platform.status())
          .where((item) => item.id == id)
          .firstOrNull;
      if (state != null && predicate(state)) return state;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Timed out waiting for $id');
  }

  for (final scenario in [
    'complete',
    'resume',
    'invalid-resume',
    'repair',
    'integrity',
    'cancel',
    'cancel-restart',
  ]) {
    testWidgets('native model download: $scenario', (tester) async {
      final id = 'platform-test-$scenario';
      final artifact = fixture(
        id,
        hash: scenario == 'integrity' ? '0' * 64 : fixtureHash,
      );
      final root = await getApplicationSupportDirectory();
      final file = File('${root.path}/$folder/${artifact.fileName}');
      final partial = File('${file.path}.part');
      final resume = File('${file.path}.resume');
      final segment = File('${file.path}.segment');
      final scratch = File('${file.path}.merge');
      await file.parent.create(recursive: true);
      for (final item in [file, partial, resume, segment, scratch]) {
        if (await item.exists()) await item.delete();
      }
      addTearDown(() async {
        await platform.cancel(id);
        for (final item in [file, partial, resume, segment, scratch]) {
          if (await item.exists()) await item.delete();
        }
      });
      if (scenario == 'invalid-resume' && Platform.isIOS) {
        await resume.writeAsString('Invalid or evicted URLSession resume data');
      }
      if (scenario == 'repair') {
        await file.writeAsBytes(List.filled(artifact.bytes, 0));
      }
      if (scenario == 'resume' || scenario == 'invalid-resume') {
        // Legacy Dart partial bytes must remain usable by the native path.
        // Use actual fixture prefix, independent of upstream HTTP Range support.
        final client = HttpClient();
        final response = await (await client.getUrl(
          Uri.parse(artifact.url),
        )).close();
        final bytes = await response.fold<List<int>>(
          [],
          (a, b) => a..addAll(b),
        );
        client.close();
        await partial.writeAsBytes(bytes.take(97).toList());
      }
      await platform.start(artifact, folder, repair: scenario == 'repair');
      if (scenario == 'cancel-restart') {
        await platform.cancel(id);
        await platform.start(artifact, folder);
      }
      if (scenario == 'cancel') {
        await platform.cancel(id);
        final state = await waitFor(id, (state) => !state.state.isActive);
        expect(state.state, ModelTransferState.cancelled);
        return;
      }
      // Reattaching must not create duplicate work or reset the transfer.
      await platform.start(artifact, folder);
      final state = await waitFor(id, (state) => !state.state.isActive);
      if (scenario == 'integrity') {
        expect(state.state, ModelTransferState.failed);
        expect(await file.exists(), false);
        expect(await partial.exists(), false);
        expect(state.verification, isNull);
      } else {
        expect(state.state, ModelTransferState.completed, reason: state.error);
        expect(await file.length(), artifact.bytes);
        expect(
          (await sha256.bind(file.openRead()).first).toString(),
          fixtureHash,
        );
        expect(await partial.exists(), false);
        expect(state.verification, isNotNull);
        expect(state.verification!['token'], state.token);
        expect(
          state.verification!['modified'],
          (await file.stat()).modified.millisecondsSinceEpoch,
        );
        final records = <String, String>{};
        final store = ModelVerificationStore.forTesting(
          read: (key) => records[key],
          write: (key, value) async {
            if (value == null) {
              records.remove(key);
            } else {
              records[key] = value;
            }
          },
        );
        final client = MockClient(
          (_) async => throw StateError('No Dart HTTP'),
        );
        addTearDown(client.close);
        LocalModelDownload installation() => LocalModelDownload(
          client,
          model: artifact,
          directory: () async => root,
          folder: folder,
          platformDownloader: platform,
          verificationStore: store,
        );
        final first = installation();
        expect(await first.isReady(), true);
        expect(first.verification.fullHashCount, 0);
        final cold = installation();
        expect(await cold.isReady(), true);
        expect(cold.verification.fullHashCount, 0);
        await file.setLastModified(
          DateTime.now().add(const Duration(seconds: 5)),
        );
        expect(await cold.isReady(), true);
        expect(cold.verification.fullHashCount, 1);
      }
    });
  }
}
