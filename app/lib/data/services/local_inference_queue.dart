import 'dart:async';
import 'dart:collection';
import 'package:injectable/injectable.dart';
import 'package:smartnotes/domain/entities/inference_cancelled.dart';

/// A job owns native model disposal before releasing its lease. Interactive
/// work precedes backlog indexing; bounded fairness prevents starvation.
/// Cancelled queued jobs are skipped before acquiring native resources. Running
/// jobs must check cancellation themselves at safe boundaries, never via races
/// that release the lease while native work or disposal is still active.
@lazySingleton
class LocalInferenceQueue {
  final _foreground = Queue<Future<void> Function()>();
  final _background = Queue<Future<void> Function()>();
  bool _running = false;
  int _foregroundRun = 0;
  Future<T> run<T>(
    Future<T> Function() job, {
    bool background = false,
    bool Function()? isCancelled,
  }) {
    final result = Completer<T>();
    (background ? _background : _foreground).add(() async {
      try {
        checkInferenceCancelled(isCancelled);
        result.complete(await job());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    if (!_running) {
      _running = true;
      scheduleMicrotask(_drain);
    }
    return result.future;
  }

  Future<void> _drain() async {
    while (_foreground.isNotEmpty || _background.isNotEmpty) {
      final background =
          _background.isNotEmpty &&
          (_foreground.isEmpty || _foregroundRun >= 8);
      final job = (background ? _background : _foreground).removeFirst();
      _foregroundRun = background ? 0 : _foregroundRun + 1;
      await job();
    }
    _foregroundRun = 0;
    _running = false;
  }
}
