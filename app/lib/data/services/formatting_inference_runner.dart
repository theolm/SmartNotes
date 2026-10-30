import 'package:injectable/injectable.dart';
import 'package:smartnotes/core/utils/inference_trace.dart';
import 'package:smartnotes/data/services/local_formatting_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/formatting_acceleration.dart';
import 'package:smartnotes/domain/services/i_formatting_acceleration_service.dart';

typedef FormattingSessionFactory =
    LocalFormattingSession Function(
      FormattingBackendDecision decision,
    );

class FormattingLoadFailure implements Exception {
  const FormattingLoadFailure();
}

/// Called under the shared queue lease. Owns exactly one native session at a
/// time, including a possible fresh CPU retry after successful GPU teardown.
@lazySingleton
class FormattingInferenceRunner {
  FormattingInferenceRunner(this._acceleration, this._queue)
    : _factory = _nativeSession;

  FormattingInferenceRunner.forTesting(
    this._acceleration,
    this._queue,
    this._factory,
  );

  final IFormattingAccelerationService? _acceleration;
  final LocalInferenceQueue _queue;
  final FormattingSessionFactory _factory;
  static LocalFormattingSession _nativeSession(
    FormattingBackendDecision decision,
  ) => LlamaFormattingSession(decision: decision);

  Future<T> run<T>({
    required String path,
    required String modelId,
    required FormattingWorkload workload,
    required Future<T> Function(LocalFormattingSession) generate,
  }) async {
    final watch = Stopwatch()..start();
    final acceleration = _acceleration;
    var decision =
        await acceleration?.decide(modelId, workload) ??
        const FormattingBackendDecision.cpu(
          FormattingBackendReason.userDisabled,
        );
    if (decision.usesGpu && !await acceleration!.begin(modelId, decision)) {
      decision = const FormattingBackendDecision.cpu(
        FormattingBackendReason.circuitOpen,
      );
    }
    var fellBack = false;
    while (true) {
      LocalFormattingSession? session;
      var backendFailed = false;
      var loaded = false;
      late T result;
      try {
        session = _factory(decision);
        await InferenceTrace.run('formatting.load', () => session!.load(path));
        loaded = true;
        InferenceTrace.event('formatting.backend', {
          'backend': decision.backend.name,
          'fallback': fellBack,
          'reason': decision.reason.name,
        });
        result = await generate(session);
      } on FormattingGpuUnavailable {
        backendFailed = decision.usesGpu;
        if (!backendFailed) throw const FormattingLoadFailure();
      } catch (_) {
        if (!loaded) throw const FormattingLoadFailure();
        rethrow;
      } finally {
        if (session != null) {
          await _dispose(session);
        }
        if (decision.usesGpu) {
          await acceleration!.finish(modelId, backendFailed: backendFailed);
        }
      }
      if (!backendFailed) {
        acceleration?.report(
          FormattingRunReport(
            backend: decision.backend,
            fellBack: fellBack,
            elapsed: watch.elapsed,
          ),
        );
        return result;
      }
      // Recoverable failure only. Disposal above must finish before this point.
      if (fellBack || !await acceleration!.canRetryOnCpu(decision)) {
        throw const FormattingLoadFailure();
      }
      fellBack = true;
      decision = const FormattingBackendDecision.cpu(
        FormattingBackendReason.fallback,
      );
    }
  }

  Future<void> _dispose(LocalFormattingSession session) async {
    try {
      await InferenceTrace.run('formatting.dispose', session.dispose);
    } catch (_) {
      _queue.blockAfterCleanupFailure();
      _acceleration?.cleanupFailed();
      throw const AiFailure(AiFailureCode.unavailable);
    }
  }
}
