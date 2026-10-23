import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smartnotes/core/di/injection.dart';
import 'package:smartnotes/core/l10n/app_localizations.dart';
import 'package:smartnotes/core/theme/theme.dart';
import 'package:smartnotes/domain/services/i_recording_playback.dart';

/// Compact controls for the retained recording. The surrounding surface owns
/// the title and placement; this widget owns playback only.
class RecordingPlayer extends StatefulWidget {
  const RecordingPlayer({super.key, required this.path, this.enabled = true});

  final String? path;
  final bool enabled;

  @override
  State<RecordingPlayer> createState() => RecordingPlayerState();
}

class RecordingPlayerState extends State<RecordingPlayer>
    with WidgetsBindingObserver {
  IRecordingPlayback? _player;
  double? _seeking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  void _open() {
    if (widget.path == null) return;
    _player = getIt<IRecordingPlayback>();
    _player!.addListener(_changed);
    unawaited(_player!.load(widget.path!));
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(RecordingPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _player?.removeListener(_changed);
      unawaited(_player?.close());
      _player = null;
      _open();
      _changed();
    }
    if (!widget.enabled && oldWidget.enabled) unawaited(stop());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == false) unawaited(stop());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.removeListener(_changed);
    unawaited(_player?.close());
    super.dispose();
  }

  String _time(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final player = _player;
    final status = player?.status ?? RecordingPlaybackStatus.missing;
    final failed = status == RecordingPlaybackStatus.error;
    final missing = status == RecordingPlaybackStatus.missing;
    if (missing || failed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            missing ? l10n.recordingUnavailable : l10n.recordingPlaybackFailed,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (failed) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: widget.enabled
                  ? () => player!.load(widget.path!)
                  : null,
              child: Text(l10n.retry),
            ),
          ],
        ],
      );
    }
    final duration = player?.duration?.inMilliseconds.toDouble() ?? 0;
    final position =
        (_seeking ?? player?.position.inMilliseconds.toDouble() ?? 0).clamp(
          0.0,
          duration,
        );
    final preparing = status == RecordingPlaybackStatus.preparing;
    final playing = status == RecordingPlaybackStatus.playing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: playing ? l10n.pauseRecording : l10n.playRecording,
              onPressed: !widget.enabled || preparing
                  ? null
                  : () => playing ? player!.pause() : player!.play(),
              icon: preparing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            Expanded(
              child: Semantics(
                label: l10n.seekRecording,
                child: Slider(
                  value: position,
                  min: 0,
                  max: duration > 0 ? duration : 1,
                  semanticFormatterCallback: (value) =>
                      _time(Duration(milliseconds: value.round())),
                  onChanged: !widget.enabled || preparing || duration <= 0
                      ? null
                      : (value) => setState(() => _seeking = value),
                  onChangeEnd: (value) async {
                    await player?.seek(Duration(milliseconds: value.round()));
                    if (mounted) setState(() => _seeking = null);
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _time(Duration(milliseconds: position.round())),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              player?.duration == null
                  ? l10n.durationUnknown
                  : _time(
                      player!.duration! + const Duration(milliseconds: 999),
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}
