// Isolated diagnostic entry point. Never initializes the journal or app DI.
// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
// See docs/formatting-gpu-validation.md for installation and fixture requirements.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:llamadart/llamadart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartnotes/data/services/device_profile_service.dart';
import 'package:smartnotes/data/services/formatting_acceleration_service.dart';
import 'package:smartnotes/data/services/formatting_inference_runner.dart';
import 'package:smartnotes/data/services/gpu_circuit_store.dart';
import 'package:smartnotes/data/services/local_formatting_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_note_processing_service.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/entities/formatting_acceleration.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/services/i_formatting_model_service.dart';
import 'package:smartnotes/domain/services/i_transcription_service.dart';

class _Model implements IFormattingModelService {
  _Model(this.path, this.model);
  final String path;
  final FormattingModel model;
  @override
  String get activeModelId => model.id;
  @override
  FormattingModel get activeModel => model;
  @override
  Future<bool> isReady([String? modelId]) async => true;
  @override
  Future<String> requireModelPath() async => path;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Probe model is read-only');
}

class _NoSpeech implements ITranscriptionService {
  @override
  Future<String> transcribe(String audioPath) =>
      throw UnsupportedError('No speech in this probe');
}

class _MeasuredSession extends LlamaFormattingSession {
  _MeasuredSession(FormattingBackendDecision decision)
    : super(decision: decision);
  final stages = <String, int>{};
  LlamaGenerationUsage? usage;
  Future<T> _measure<T>(String name, Future<T> Function() work) async {
    final timer = Stopwatch()..start();
    try {
      return await work();
    } finally {
      stages[name] = timer.elapsedMicroseconds;
    }
  }

  @override
  Future<void> load(String path) => _measure('loadUs', () => super.load(path));
  @override
  Future<int> countPrompt(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) => _measure('tokenizeUs', () => super.countPrompt(messages, format));
  @override
  Future<LlamaCompletion> generate(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) => _measure('generateUs', () async {
    final result = await super.generate(messages, format);
    usage = result.usage;
    return result;
  });
  @override
  Future<void> dispose() => _measure('disposeUs', super.dispose);
}

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
  String status = 'Preparing isolated formatting probe';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      await runFormattingProbe();
      if (mounted) setState(() => status = 'Formatting probe completed');
    } catch (error) {
      // Native messages may contain paths. Only the exception type is reported.
      print(
        'FORMATTING_PROBE ${jsonEncode({'errorType': error.runtimeType.toString()})}',
      );
      if (mounted) {
        setState(
          () => status = 'Formatting probe failed: ${error.runtimeType}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(status)));
}

Future<void> runFormattingProbe() async {
  const path = String.fromEnvironment('FORMATTING_MODEL_PATH');
  const id = String.fromEnvironment(
    'FORMATTING_MODEL_ID',
    defaultValue: 'qwen3-1.7b-q4_k_m',
  );
  const repetitions = int.fromEnvironment(
    'FORMATTING_REPETITIONS',
    defaultValue: 5,
  );
  const mode = String.fromEnvironment(
    'FORMATTING_BACKEND',
    defaultValue: 'paired',
  );
  const layers = int.fromEnvironment(
    'FORMATTING_GPU_LAYERS',
    defaultValue: 999,
  );
  const workloadName = String.fromEnvironment(
    'FORMATTING_WORKLOAD',
    defaultValue: 'organization',
  );
  // Shipped-policy mode proves the qualified allow-list end to end. The
  // default diagnostic profile only measures a candidate configuration.
  const useShippedPolicy = bool.fromEnvironment(
    'FORMATTING_USE_SHIPPED_PROFILES',
  );
  final workload = FormattingWorkload.values.byName(workloadName);
  final model = FormattingModel.find(id);
  if (model == null ||
      path.isEmpty ||
      repetitions < 1 ||
      layers < 1 ||
      !['cpu', 'gpu', 'paired'].contains(mode)) {
    throw ArgumentError('Invalid probe configuration');
  }
  final file = File(path);
  if (await file.length() != model.bytes ||
      (await sha256.bind(file.openRead()).first).toString() != model.sha256) {
    throw StateError('Model verification failed');
  }
  final directory = await Directory.systemTemp.createTemp(
    'formatting-gpu-probe-',
  );
  final device = DeviceProfileService();
  final hardware = await device.read();
  print(
    'FORMATTING_PROBE ${jsonEncode({
      'runtime': FormattingBackendPolicy.runtime,
      'hardware': hardware.hardwareIdentity,
      'model': model.id,
      'sha256': model.sha256,
      'memoryBytes': hardware.memoryBytes,
      'availableBytes': hardware.availableMemoryBytes,
      'workload': workload.name,
    })}',
  );
  // Mock preference storage is confined to this diagnostic process.
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final acceleration = FormattingAccelerationService.forTesting(
    preferences,
    device,
    GpuCircuitStore.at(File('${directory.path}/circuit.json')),
    profiles: useShippedPolicy
        ? FormattingBackendPolicy.qualifiedProfiles
        : [
            FormattingGpuProfile(
              id: 'diagnostic-only',
              hardware: hardware.hardwareIdentity,
              modelId: model.id,
              workload: workload,
              backend: Platform.isAndroid
                  ? FormattingBackend.vulkan
                  : FormattingBackend.metal,
              minimumMemoryBytes: 0,
              minimumAvailableBytes: 0,
              gpuLayers: layers,
            ),
          ],
  );
  final queue = LocalInferenceQueue();
  _MeasuredSession? lastSession;
  final runner = FormattingInferenceRunner.forTesting(acceleration, queue, (
    decision,
  ) {
    lastSession = _MeasuredSession(decision);
    return lastSession!;
  });
  final service = LocalNoteProcessingService(
    _Model(path, model),
    _NoSpeech(),
    queue,
    inference: runner,
  );
  const source =
      'Hoje conversei com Marina sobre o projeto em Lisboa. '
      'Não vou viajar amanhã. Talvez a reunião aconteça na sexta-feira, '
      'mas ainda não confirmamos. O orçamento é de 250 euros, não 500. '
      'Preciso enviar três documentos até terça-feira. Estou preocupado com o prazo.';
  final records = <Map<String, Object?>>[];
  try {
    // Pair order alternates. Run zero is a warm-up and retained as cold evidence.
    for (var run = 0; run <= repetitions; run++) {
      final backends = mode == 'paired'
          ? (run.isEven ? [false, true] : [true, false])
          : [mode == 'gpu'];
      for (final gpu in backends) {
        await acceleration.setPreferred(gpu);
        final timer = Stopwatch()..start();
        final String output;
        if (workload == FormattingWorkload.metadata) {
          final metadata = await service.generateMetadata(source);
          output = jsonEncode({
            'title': metadata?.title,
            'subTitle': metadata?.subTitle,
          });
        } else {
          final note = await service.formatTranscription(
            action: AiAction.organizedNote,
            transcription: source,
          );
          output = jsonEncode({
            'title': note.title,
            'subTitle': note.subTitle,
            'markdown': note.markdown,
          });
        }
        final report = acceleration.status.lastRun!;
        if (gpu && report.backend == FormattingBackend.cpu) {
          throw StateError('Requested GPU did not produce this result');
        }
        final record = <String, Object?>{
          'run': run,
          'warmup': run == 0,
          'requestedGpu': gpu,
          'backend': report.backend.name,
          'reportedBackend': lastSession?.backendName,
          'resolvedLayers': lastSession?.resolvedGpuLayers,
          'fallback': report.fellBack,
          'totalMs': timer.elapsedMilliseconds,
          'rssBytes': ProcessInfo.currentRss,
          'peakRssBytes': ProcessInfo.maxRss,
          ...?lastSession?.stages,
          'usage': lastSession?.usage?.toJson(),
        };
        print('FORMATTING_PROBE ${jsonEncode(record)}');
        records.add({...record, 'fixtureOutput': output});
        await File(
          '${directory.path}/results.json',
        ).writeAsString(jsonEncode(records), flush: true);
      }
    }
  } finally {
    await acceleration.dispose();
  }
  // Synthetic fixture output only, never a user note. Retain for local review.
  print('FORMATTING_PROBE results=${directory.path}/results.json');
}
