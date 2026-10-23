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
  int _generation = 0;

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

  Future<void> begin(String entryId, String modelName) async {
    _generation++;
    await _set(
      ProcessingFeedback(
        entryId: entryId,
        phase: ProcessingPhase.preparingTranscription,
        modelName: modelName,
      ),
    );
  }

  Future<void> update(ProcessingPhase phase, String modelName) async {
    final current = _current;
    if (current == null) return;
    await _set(
      ProcessingFeedback(
        entryId: current.entryId,
        phase: phase,
        modelName: modelName,
      ),
    );
  }

  Future<void> finish({bool failed = false}) async {
    if (_current == null) return;
    final generation = ++_generation;
    if (!failed) {
      await update(ProcessingPhase.finalizing, _current!.modelName);
      if (supported) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (generation != _generation) return;
    }
    _current = null;
    _changes.add(null);
    if (supported) {
      try {
        await channel.invokeMethod<void>('dismiss');
      } on PlatformException {
        // Feedback must never change the outcome of local processing.
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
    }
  }

  Future<void> dispose() async {
    await _changes.close();
    await _entryOpens.close();
  }
}
