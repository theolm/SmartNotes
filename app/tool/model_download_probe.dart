import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartnotes/data/services/platform_model_downloader.dart';
import 'package:smartnotes/domain/entities/local_ai_model.dart';
import 'package:smartnotes/domain/entities/model_transfer.dart';
import 'package:smartnotes/domain/entities/speech_model.dart';

/// Isolated device lifecycle fixture. Build with a separate application ID.
/// No dependency injection, journal access, or production-model paths.
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
  static final downloader = PlatformModelDownloader();
  static final source = SpeechModel.whisperBaseQ8;
  static final artifact = LocalAiModel(
    id: 'background-download-probe',
    name: 'Background download test',
    fileName: 'probe.bin',
    url: source.url,
    bytes: source.bytes,
    sha256: source.sha256,
  );
  Timer? _timer;
  ModelTransfer? _transfer;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await downloader.start(artifact, 'download_probe');
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _refresh() async {
    try {
      final transfers = await downloader.status();
      if (mounted) {
        setState(
          () => _transfer = transfers
              .where((item) => item.id == artifact.id)
              .firstOrNull,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Background download probe')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('State: ${_transfer?.state.name ?? 'starting'}'),
            Text('Bytes: ${_transfer?.received ?? 0} / ${artifact.bytes}'),
            const Text('File: Application Support/download_probe/probe.bin'),
            if (_transfer?.error != null) Text(_transfer!.error!),
            if (_error != null) Text('$_error'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _start,
              child: const Text('Start / resume'),
            ),
            OutlinedButton(
              onPressed: () => downloader.cancel(artifact.id),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: downloader.requestNotifications,
              child: const Text('Allow notifications'),
            ),
          ],
        ),
      ),
    ),
  );
}
