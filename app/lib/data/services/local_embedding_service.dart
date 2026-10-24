import 'dart:math' as math;
import 'package:injectable/injectable.dart';
import 'package:smartnotes/data/services/local_embedding_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/embedding_model.dart';
import 'package:smartnotes/domain/entities/inference_cancelled.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/domain/services/i_embedding_service.dart';

@LazySingleton(as: IEmbeddingService)
class LocalEmbeddingService implements IEmbeddingService {
  LocalEmbeddingService(this._models, this._queue) : _session = null;
  LocalEmbeddingService.forTesting(this._models, this._queue, this._session);
  final IEmbeddingModelService _models;
  final LocalInferenceQueue _queue;
  final LocalEmbeddingSession Function()? _session;
  EmbeddingModel get profile => _models.model is EmbeddingModel
      ? _models.model as EmbeddingModel
      : EmbeddingModel.find(_models.model.id) ?? EmbeddingModel.qwen;

  Future<T> _withSession<T>(
    Future<T> Function(LocalEmbeddingSession session) job, {
    required EmbeddingModel model,
    bool background = false,
    bool Function()? isCancelled,
  }) => _queue.run(
    () async {
      if (!await _models.isReady()) {
        checkInferenceCancelled(isCancelled);
        throw const AiFailure(AiFailureCode.modelMissing);
      }
      checkInferenceCancelled(isCancelled);
      if (profile.pipelineId != model.pipelineId) throw InferenceCancelled();
      final path = await _models.requireModelPath();
      checkInferenceCancelled(isCancelled);
      final session = _session?.call() ?? LlamaEmbeddingSession(model: model);
      try {
        await session.load(path);
        checkInferenceCancelled(isCancelled);
        final result = await job(session);
        checkInferenceCancelled(isCancelled);
        return result;
      } on InferenceCancelled {
        rethrow;
      } on AiFailure {
        rethrow;
      } catch (_) {
        throw const AiFailure(AiFailureCode.invalidEmbedding);
      } finally {
        await session.dispose();
      }
    },
    background: background,
    isCancelled: isCancelled,
  );

  @override
  Future<List<double>> embedQuery(
    String text, {
    bool Function()? isCancelled,
  }) async {
    await _models.isReady();
    final model = profile;
    return _withSession(
      (session) async {
        final input = model.query(text);
        if (text.trim().isEmpty ||
            await session.countTokens(input) > model.contextTokens - 8) {
          throw const AiFailure(AiFailureCode.queryTooLong);
        }
        checkInferenceCancelled(isCancelled);
        return normalizeEmbedding(await session.embed(input), model: model);
      },
      model: model,
      isCancelled: isCancelled,
    );
  }

  @override
  Future<List<List<double>>> embedDocument(
    String text, {
    bool Function()? isCancelled,
    void Function(String text, int start)? onPassage,
  }) async {
    void check() {
      checkInferenceCancelled(isCancelled);
    }

    check();
    await _models.isReady();
    final model = profile;
    final chunks = _EmbeddingChunks(text, model: model);
    final vectors = <List<double>>[];
    while (!chunks.isDone) {
      check();
      vectors.addAll(
        await _withSession(
          (session) async {
            final result = <List<double>>[];
            // Bound tokenization AND inference, yielding to interactive jobs
            // between batches instead of tokenizing an entire library first.
            for (var i = 0; i < 4 && !chunks.isDone; i++) {
              check();
              Future<int> count(String text) async {
                check();
                final tokens = await session.countTokens(model.document(text));
                check();
                return tokens;
              }

              final chunk = await chunks.next(count);
              if (await count(chunk) > model.contextTokens - 8) {
                throw const AiFailure(AiFailureCode.invalidEmbedding);
              }
              result.add(
                normalizeEmbedding(
                  await session.embed(model.document(chunk)),
                  model: model,
                ),
              );
              onPassage?.call(chunk, chunks.lastStartOffset);
            }
            return result;
          },
          background: true,
          model: model,
          isCancelled: isCancelled,
        ),
      );
    }
    check();
    return vectors;
  }
}

/// MRL slicing is supported by this checkpoint. Validate ALL native dimensions
/// before slicing, then re-normalize, never zero-pad a different vector space.
List<double> normalizeEmbedding(
  List<double> vector, {
  EmbeddingModel model = EmbeddingModel.qwen,
}) {
  if (vector.length != model.nativeDimensions ||
      vector.any((v) => !v.isFinite)) {
    throw const AiFailure(AiFailureCode.invalidEmbedding);
  }
  final output = vector.take(model.dimensions).toList();
  final norm = math.sqrt(output.fold<double>(0, (sum, v) => sum + v * v));
  if (!norm.isFinite || norm <= 0) {
    throw const AiFailure(AiFailureCode.invalidEmbedding);
  }
  return output.map((v) => v / norm).toList(growable: false);
}

/// Count with the real model tokenizer, but slice Unicode runes, not token bytes:
/// a BPE token boundary can split a UTF-8 character. Every source rune survives.
Future<List<String>> chunkEmbeddingText(
  String text,
  Future<int> Function(String) count,
) async {
  final source = _EmbeddingChunks(text);
  final chunks = <String>[];
  while (!source.isDone) {
    chunks.add(await source.next(count));
  }
  return chunks;
}

class _EmbeddingChunks {
  _EmbeddingChunks(String text, {this.model = EmbeddingModel.qwen})
    : text = text.trim().isEmpty ? '' : text;
  final String text;
  final EmbeddingModel model;
  int startOffset = 0;
  int lastStartOffset = 0;
  bool get isDone => startOffset >= text.length;

  Future<String> next(Future<int> Function(String) count) async {
    lastStartOffset = startOffset;
    // Bound Dart work too: never expand an entire long note into code points on
    // the UI isolate. Surrogate pairs cannot be split at a window boundary.
    var windowEnd = math.min(text.length, startOffset + 8192);
    if (windowEnd < text.length &&
        text.codeUnitAt(windowEnd - 1) >= 0xD800 &&
        text.codeUnitAt(windowEnd - 1) <= 0xDBFF) {
      windowEnd--;
    }
    final runes = text.substring(startOffset, windowEnd).runes.toList();
    const start = 0;
    String slice(int start, int end) =>
        String.fromCharCodes(runes.sublist(start, end));
    var low = start + 1;
    // Any one rune needs at most a small number of tokens. Cap tokenizer work.
    var high = math.min(runes.length, start + 4096);
    var end = start;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (await count(slice(start, mid)) <= model.chunkTokens) {
        end = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (end == start) {
      throw const AiFailure(AiFailureCode.invalidEmbedding);
    }
    if (end < runes.length) {
      // Prefer sentence/paragraph boundaries near the end, not tiny fragments.
      for (var i = end - 1; i >= start + (end - start) * 3 ~/ 4; i--) {
        if ([10, 46, 33, 63].contains(runes[i])) {
          end = i + 1;
          break;
        }
      }
    }
    final chunk = slice(start, end);
    if (await count(chunk) > model.chunkTokens) {
      throw const AiFailure(AiFailureCode.invalidEmbedding);
    }
    if (end == runes.length && windowEnd == text.length) {
      startOffset = text.length;
      return chunk;
    }
    low = start + 1;
    high = end;
    var next = end;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (await count(slice(mid, end)) <= model.overlapTokens) {
        next = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    final nextStart = math.max(start + 1, next);
    startOffset += slice(start, nextStart).length;
    return chunk;
  }
}
