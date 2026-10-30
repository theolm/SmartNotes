import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/formatting_feedback_service.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/formatting_model.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';

import '../helpers/local_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProcessingFeedbackService feedback;
  late MemoryFormattingModels models;
  late FormattingFeedbackService service;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    feedback = ProcessingFeedbackService.forTesting();
    models = MemoryFormattingModels(activeId: FormattingModel.gemma3_4b.id);
    service = FormattingFeedbackService(feedback, models);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProcessingFeedbackService.channel, (
          call,
        ) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() async {
    await feedback.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProcessingFeedbackService.channel, null);
  });

  test(
    'tracks preparation, running model and cleanup through preview completion',
    () async {
      final gate = Completer<String>();
      final running = service.run('entry-1', () {
        expect(feedback.current!.phase, ProcessingPhase.formatting);
        expect(feedback.current!.entryId, 'entry-1');
        expect(feedback.current!.modelName, FormattingModel.gemma3_4b.name);
        return gate.future;
      });
      await pumpEventQueue();
      final shows = calls.where((call) => call.method == 'show').toList();
      expect(shows, hasLength(2));
      expect(
        shows.first.arguments,
        containsPair('body', 'Preparing AI formatting…'),
      );
      expect(
        shows.first.arguments,
        containsPair('detail', 'Loading ${FormattingModel.gemma3_4b.name}'),
      );
      expect(shows.last.arguments, containsPair('body', 'Formatting note…'));
      expect(
        shows.last.arguments,
        containsPair('detail', 'Running ${FormattingModel.gemma3_4b.name}'),
      );
      expect(calls.where((call) => call.method == 'dismiss'), isEmpty);
      gate.complete('Unsaved preview');
      expect(await running, 'Unsaved preview');
      expect(feedback.current, isNull);
      expect(calls.last.method, 'dismiss');
      final finalizing = calls.where((call) => call.method == 'show').last;
      expect(finalizing.arguments, containsPair('body', 'Finalizing…'));
    },
  );

  test(
    'failure dismisses feedback and preserves the original typed failure',
    () async {
      const failure = AiFailure(AiFailureCode.invalidNote);
      await expectLater(
        service.run<void>('entry-1', () async => throw failure),
        throwsA(same(failure)),
      );
      expect(feedback.current, isNull);
      expect(calls.last.method, 'dismiss');
    },
  );

  test(
    'native notification failure never blocks generation or cleanup',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ProcessingFeedbackService.channel, (
            _,
          ) async {
            throw PlatformException(code: 'notifications_denied');
          });
      expect(await service.run('entry-1', () async => 'Preview'), 'Preview');
      expect(feedback.current, isNull);
    },
  );

  test(
    'no selected model delegates the usual missing-model failure without feedback',
    () async {
      models.ready = false;
      const failure = AiFailure(AiFailureCode.formattingModelMissing);
      await expectLater(
        service.run<void>('entry-1', () async => throw failure),
        throwsA(same(failure)),
      );
      expect(calls, isEmpty);
      expect(feedback.current, isNull);
    },
  );
}
