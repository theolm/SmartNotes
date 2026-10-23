import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/services/local_model_download.dart';
import 'package:smartnotes/data/services/model_verification.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';

/// Run with a separate application ID. Only a four-byte synthetic artifact and
/// its verification preference are accessed; no journal or real weights.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  static const bytes = [1, 2, 3, 4];
  static final model = LocalAiModel(
    id: 'verification-fixture',
    name: 'Verification fixture',
    fileName: 'fixture.bin',
    url: 'https://example.com/unused',
    bytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );
  String status = 'First frame: readable';
  int hashes = 0;
  bool busy = false;
  final client = http.Client();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  Future<void> check({String? mutation}) async {
    if (busy) return;
    setState(() {
      busy = true;
      status = 'Checking synthetic fixture';
    });
    try {
      final root = await getApplicationSupportDirectory();
      final file = File('${root.path}/verification_probe/${model.fileName}');
      await file.parent.create(recursive: true);
      if (!await file.exists() || mutation == 'repair') {
        await file.writeAsBytes(bytes);
      }
      if (mutation == 'corrupt') await file.writeAsBytes([9, 9, 9, 9]);
      if (mutation != null) {
        await file.setLastModified(
          DateTime.now().add(const Duration(seconds: 2)),
        );
      }
      final store = ModelVerificationStore(
        await SharedPreferences.getInstance(),
      )..allowVerification();
      final worker = LocalModelDownload(
        client,
        model: model,
        directory: () async => root,
        folder: 'verification_probe',
        verificationStore: store,
      );
      final state = await worker.readiness(verify: true);
      if (mounted) {
        setState(() {
          status = 'Fixture: ${state.name}';
          hashes = worker.verification.fullHashCount;
        });
      }
    } catch (_) {
      if (mounted) setState(() => status = 'Fixture check failed');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Isolated verification probe')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(status),
            Text('Full hashes in this check: $hashes'),
            if (busy) const LinearProgressIndicator(),
            const Text('Synthetic data only. No journal or real model access.'),
            FilledButton(
              onPressed: busy ? null : () => check(),
              child: const Text('Cold readiness'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => check(mutation: 'mtime'),
              child: const Text('Change mtime'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => check(mutation: 'corrupt'),
              child: const Text('Corrupt fixture'),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => check(mutation: 'repair'),
              child: const Text('Repair fixture'),
            ),
          ],
        ),
      ),
    ),
  );
}
