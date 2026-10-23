import 'dart:math' as math;
import 'package:injectable/injectable.dart';
import 'package:smartnotes/data/services/local_embedding_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/embedding_pipeline.dart';
import 'package:smartnotes/domain/entities/inference_cancelled.dart';
import 'package:smartnotes/domain/services/i_embedding_model_service.dart';
import 'package:smartnotes/domain/services/i_embedding_service.dart';

@LazySingleton(as: IEmbeddingService)
class LocalEmbeddingService implements IEmbeddingService {
  LocalEmbeddingService(this._models, this._queue)
    : _session = LlamaEmbeddingSession.new;
  LocalEmbeddingService.forTesting(this._models, this._queue, this._session);
  final IEmbeddingModelService _models;
  final LocalInferenceQueue _queue;
  final LocalEmbeddingSession Function() _session;

  Future<T> _withSession<T>(
    Future<T> Function(LocalEmbeddingSession session) job, {
    bool background = false,
    bool Function()? isCancelled,
  }) => _queue.run(
    () async {
      if (!await _models.isReady()) {
        checkInferenceCancelled(isCancelled);
        throw const AiFailure(AiFailureCode.modelMissing);
      }
      checkInferenceCancelled(isCancelled);
      final path = await _models.requireModelPath();
      checkInferenceCancelled(isCancelled);
      final session = _session();
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
  }) => _withSession((session) async {
    final input = EmbeddingPipeline.query(text);
    if (text.trim().isEmpty ||
        await session.countTokens(input) >
            EmbeddingPipeline.contextTokens - 8) {
      throw const AiFailure(AiFailureCode.queryTooLong);
    }
    checkInferenceCancelled(isCancelled);
    return normalizeEmbedding(await session.embed(input));
  }, isCancelled: isCancelled);

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
    final chunks = _EmbeddingChunks(text);
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
                final tokens = await session.countTokens(text);
                check();
                return tokens;
              }

              final chunk = await chunks.next(count);
              if (await count(chunk) > EmbeddingPipeline.contextTokens - 8) {
                throw const AiFailure(AiFailureCode.invalidEmbedding);
              }
              result.add(normalizeEmbedding(await session.embed(chunk)));
              onPassage?.call(chunk, chunks.lastStartOffset);
            }
            return result;
          },
          background: true,
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
List<double> normalizeEmbedding(List<double> vector) {
  if (vector.length != 1024 || vector.any((v) => !v.isFinite)) {
    throw const AiFailure(AiFailureCode.invalidEmbedding);
  }
  final output = vector.take(EmbeddingPipeline.dimensions).toList();
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
  _EmbeddingChunks(String text)
    : runes = text.trim().isEmpty ? [] : text.runes.toList();
  final List<int> runes;
  int start = 0;
  int startOffset = 0;
  int lastStartOffset = 0;
  bool get isDone => start >= runes.length;
  String slice(int start, int end) =>
      String.fromCharCodes(runes.sublist(start, end));

  Future<String> next(Future<int> Function(String) count) async {
    lastStartOffset = startOffset;
    var low = start + 1;
    // Any one rune needs at most a small number of tokens. Cap tokenizer work.
    var high = math.min(runes.length, start + 4096);
    var end = start;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (await count(slice(start, mid)) <= EmbeddingPipeline.chunkTokens) {
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
    if (await count(chunk) > EmbeddingPipeline.chunkTokens) {
      throw const AiFailure(AiFailureCode.invalidEmbedding);
    }
    if (end == runes.length) {
      start = end;
      return chunk;
    }
    low = start + 1;
    high = end;
    var next = end;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (await count(slice(mid, end)) <= EmbeddingPipeline.overlapTokens) {
        next = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    final nextStart = math.max(start + 1, next);
    startOffset += slice(start, nextStart).length;
    start = nextStart;
    return chunk;
  }
}
