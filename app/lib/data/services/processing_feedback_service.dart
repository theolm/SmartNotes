import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:smartnotes/core/l10n/app_localizations_en.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';

@lazySingleton
class ProcessingFeedbackService {
  ProcessingFeedbackService()
    : _forceUnsupported = false,
      _forceSupported = false {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openEntry' && call.arguments is String) {
        _entryOpens.add(call.arguments as String);
      }
    });
  }

  ProcessingFeedbackService.unsupported()
    : _forceUnsupported = true,
      _forceSupported = false;

  ProcessingFeedbackService.forTesting()
    : _forceUnsupported = false,
      _forceSupported = true {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openEntry' && call.arguments is String) {
        _entryOpens.add(call.arguments as String);
      }
    });
  }

  static const channel = MethodChannel(
    'dev.theolm.smartnotes/processing_feedback',
  );
  final bool _forceUnsupported;
  final bool _forceSupported;
  final _changes = StreamController<ProcessingFeedback?>.broadcast();
  final _entryOpens = StreamController<String>.broadcast();
  ProcessingFeedback? _current;
  int _nextJob = 0;
  final _jobs = <int, ProcessingFeedback>{};

  bool get supported =>
      _forceSupported ||
      (!_forceUnsupported &&
          (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));
  ProcessingFeedback? get current => _current;
  Stream<ProcessingFeedback?> get changes => _changes.stream;
  Stream<String> get entryOpens => _entryOpens.stream;

  Future<void> initialize() async {
    if (!supported) return;
    final entryId = await channel.invokeMethod<String>('takePendingEntry');
    if (entryId != null) _entryOpens.add(entryId);
  }

  Future<bool> notificationsAllowed() async =>
      !supported ||
      (await channel.invokeMethod<bool>('notificationsAllowed') ?? false);

  Future<bool> requestNotifications() async =>
      !supported ||
      (await channel.invokeMethod<bool>('requestNotifications') ?? false);

  Future<int> begin(
    String entryId,
    String modelName, {
    ProcessingPhase phase = ProcessingPhase.preparingTranscription,
  }) async {
    final job = ++_nextJob;
    final feedback = ProcessingFeedback(
      entryId: entryId,
      phase: phase,
      modelName: modelName,
    );
    _jobs[job] = feedback;
    await _set(feedback);
    return job;
  }

  Future<void> update(
    ProcessingPhase phase,
    String modelName, {
    int? job,
  }) async {
    job ??= _jobs.keys.lastOrNull;
    final current = _jobs[job];
    if (current == null) return;
    final feedback = ProcessingFeedback(
      entryId: current.entryId,
      phase: phase,
      modelName: modelName,
    );
    _jobs[job!] = feedback;
    if (job == _jobs.keys.last) await _set(feedback);
  }

  Future<void> finish({bool failed = false, int? job}) async {
    job ??= _jobs.keys.lastOrNull;
    final current = _jobs[job];
    if (current == null) return;
    if (!failed) {
      await update(ProcessingPhase.finalizing, current.modelName, job: job);
      if (supported && job == _jobs.keys.lastOrNull) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    final wasVisible = job == _jobs.keys.lastOrNull;
    if (_jobs.remove(job) == null || !wasVisible) return;
    if (_jobs.isNotEmpty) {
      await _set(_jobs.values.last);
      return;
    }
    _current = null;
    _changes.add(null);
    if (supported) {
      try {
        await channel.invokeMethod<void>('dismiss');
      } on PlatformException {
        // Feedback must never change the outcome of local processing.
      } on MissingPluginException {
        // Native feedback may be unavailable in a test or unsupported host.
      }
    }
  }

  Future<void> _set(ProcessingFeedback feedback) async {
    _current = feedback;
    _changes.add(feedback);
    if (!supported) return;
    final copy = AppLocalizationsEn();
    final (title, body, detail) = switch (feedback.phase) {
      ProcessingPhase.preparingTranscription => (
        copy.processingNotificationTitle,
        copy.processingPreparingTranscription,
        copy.processingLoadingModel(feedback.modelName),
      ),
      ProcessingPhase.transcribing => (
        copy.processingNotificationTitle,
        copy.processingTranscribingAudio,
        copy.processingRunningModel(feedback.modelName),
      ),
      ProcessingPhase.preparingFormatting => (
        copy.processingNotificationTitle,
        copy.processingPreparingFormatting,
        copy.processingLoadingModel(feedback.modelName),
      ),
      ProcessingPhase.formatting => (
        copy.processingNotificationTitle,
        copy.processingFormattingNote,
        copy.processingRunningModel(feedback.modelName),
      ),
      ProcessingPhase.preparingSearch => (
        copy.processingNoteReadyTitle,
        copy.processingPreparingSearch,
        copy.processingCreatingEmbeddings(feedback.modelName),
      ),
      ProcessingPhase.finalizing => (
        copy.processingNotificationTitle,
        copy.processingFinalizing,
        copy.processingReleasingModels,
      ),
    };
    try {
      await channel.invokeMethod<void>('show', {
        'entryId': feedback.entryId,
        'title': title,
        'body': body,
        'detail': detail,
        'channel': copy.processingNotificationChannel,
      });
    } on PlatformException {
      // In-app status remains available if native notifications fail.
    } on MissingPluginException {
      // Keep formatting and transcription usable without a native handler.
    }
  }

  Future<void> dispose() async {
    await _changes.close();
    await _entryOpens.close();
  }
}
