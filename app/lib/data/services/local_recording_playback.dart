import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';
import 'package:smartnotes/domain/services/i_recording_playback.dart';

@Injectable(as: IRecordingPlayback)
class LocalRecordingPlayback extends IRecordingPlayback {
  final _player = AudioPlayer(handleInterruptions: false);
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _closed = false;
  int _request = 0;
  String? _path;
  bool _sessionReady = false;
  RecordingPlaybackStatus _status = RecordingPlaybackStatus.idle;

  @override
  RecordingPlaybackStatus get status => _status;
  @override
  Duration get position => _player.position;
  @override
  Duration? get duration => _player.duration;

  void _update(RecordingPlaybackStatus status) {
    if (_closed) return;
    _status = status;
    notifyListeners();
  }

  LocalRecordingPlayback() {
    _subscriptions.add(
      _player.positionStream.listen((_) {
        if (!_closed) notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.durationStream.listen((_) {
        if (!_closed) notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        if (_closed ||
            _status == RecordingPlaybackStatus.missing ||
            _status == RecordingPlaybackStatus.error) {
          return;
        }
        if (state.processingState == ProcessingState.completed) {
          _update(RecordingPlaybackStatus.ended);
        } else if (state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering) {
          _update(RecordingPlaybackStatus.preparing);
        } else if (state.processingState == ProcessingState.ready) {
          _update(
            state.playing
                ? RecordingPlaybackStatus.playing
                : RecordingPlaybackStatus.ready,
          );
        }
      }),
    );
    _subscriptions.add(
      _player.errorStream.listen((_) {
        _update(RecordingPlaybackStatus.error);
      }),
    );
  }

  Future<void> _configureSession() async {
    if (_sessionReady || _closed) return;
    final session = await AudioSession.instance;
    if (_closed) return;
    await session.configure(const AudioSessionConfiguration.speech());
    if (_closed) return;
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) unawaited(stop());
        // Interruption end deliberately does not resume playback.
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) => unawaited(stop())),
    );
    _sessionReady = true;
  }

  @override
  Future<void> load(String path) async {
    if (_closed) return;
    final request = ++_request;
    _path = path;
    _update(RecordingPlaybackStatus.preparing);
    try {
      // Replacing/retrying a source must never inherit just_audio's playing flag.
      await _player.pause();
      if (_closed || request != _request) return;
      if (!await File(path).exists()) {
        await _player.stop();
        if (request == _request) _update(RecordingPlaybackStatus.missing);
        return;
      }
      if (_closed || request != _request) return;
      await _player.setFilePath(path);
      if (!_closed && request == _request) {
        _update(RecordingPlaybackStatus.ready);
      }
    } catch (_) {
      if (!_closed && request == _request) {
        _update(RecordingPlaybackStatus.error);
      }
    }
  }

  @override
  Future<void> play() async {
    if (_closed || _path == null) return;
    final request = _request;
    try {
      await _configureSession();
      if (_closed || request != _request) return;
      if (_status == RecordingPlaybackStatus.ended) {
        await _player.seek(Duration.zero);
      }
      if (_closed || request != _request) return;
      // The future completes on pause/end, not when playback starts.
      unawaited(
        _player.play().catchError((Object _) {
          if (request == _request) _update(RecordingPlaybackStatus.error);
        }),
      );
    } catch (_) {
      if (request == _request) _update(RecordingPlaybackStatus.error);
    }
  }

  @override
  Future<void> pause() async {
    if (_closed) return;
    ++_request;
    try {
      await _player.pause();
      _update(RecordingPlaybackStatus.paused);
    } catch (_) {
      _update(RecordingPlaybackStatus.error);
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_closed) return;
    try {
      await _player.seek(position);
    } catch (_) {
      _update(RecordingPlaybackStatus.error);
    }
  }

  @override
  Future<void> stop() async {
    if (_closed) return;
    ++_request;
    try {
      await _player.stop();
      if (_status != RecordingPlaybackStatus.missing &&
          _status != RecordingPlaybackStatus.error) {
        _update(RecordingPlaybackStatus.paused);
      }
    } catch (_) {
      _update(RecordingPlaybackStatus.error);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    ++_request;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    super.dispose();
  }
}
