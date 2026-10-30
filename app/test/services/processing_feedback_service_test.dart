import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartnotes/data/services/processing_feedback_service.dart';
import 'package:smartnotes/domain/entities/processing_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProcessingFeedbackService.channel, (
          call,
        ) async {
          calls.add(call);
          return switch (call.method) {
            'notificationsAllowed' || 'requestNotifications' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ProcessingFeedbackService.channel, null);
  });

  test(
    'updates one notification with user and expanded technical status',
    () async {
      final feedback = ProcessingFeedbackService.forTesting();
      await feedback.begin('entry-1', 'Whisper Small');
      await feedback.update(
        ProcessingPhase.preparingSearch,
        'Qwen3 Embedding 0.6B Q8',
      );

      final shows = calls.where((call) => call.method == 'show').toList();
      expect(shows, hasLength(2));
      expect(
        shows.first.arguments,
        containsPair('body', 'Preparing transcription…'),
      );
      expect(
        shows.first.arguments,
        containsPair('detail', 'Loading Whisper Small'),
      );
      expect(shows.last.arguments, containsPair('title', 'Note ready'));
      expect(
        shows.last.arguments,
        containsPair(
          'detail',
          'Creating embeddings with Qwen3 Embedding 0.6B Q8',
        ),
      );

      await feedback.finish(failed: true);
      expect(feedback.current, isNull);
      expect(calls.last.method, 'dismiss');
      await feedback.dispose();
    },
  );

  test(
    'overlapping formatting restores the latest transcription status',
    () async {
      final feedback = ProcessingFeedbackService.forTesting();
      final speech = await feedback.begin('speech', 'Whisper Small');
      final formatting = await feedback.begin(
        'note',
        'Gemma 3 4B IT Q4_K_M',
        phase: ProcessingPhase.preparingFormatting,
      );
      await feedback.update(
        ProcessingPhase.formatting,
        'Gemma 3 4B IT Q4_K_M',
        job: formatting,
      );
      final shows = calls.length;
      await feedback.update(
        ProcessingPhase.preparingSearch,
        'Qwen Embedding',
        job: speech,
      );
      expect(calls, hasLength(shows));
      expect(feedback.current!.entryId, 'note');
      await feedback.finish(job: formatting, failed: true);
      expect(feedback.current!.entryId, 'speech');
      expect(feedback.current!.phase, ProcessingPhase.preparingSearch);
      expect(feedback.current!.modelName, 'Qwen Embedding');
      expect(calls.last.method, 'show');
      await feedback.finish(job: speech, failed: true);
      expect(feedback.current, isNull);
      expect(calls.last.method, 'dismiss');
      await feedback.dispose();
    },
  );

  test(
    'a completed hidden job cannot dismiss or later resurrect another job',
    () async {
      final feedback = ProcessingFeedbackService.forTesting();
      final speech = await feedback.begin('speech', 'Whisper');
      final formatting = await feedback.begin('note', 'Qwen');
      final count = calls.length;
      await feedback.finish(job: speech, failed: true);
      await feedback.update(
        ProcessingPhase.transcribing,
        'Whisper',
        job: speech,
      );
      expect(calls, hasLength(count));
      expect(feedback.current!.entryId, 'note');
      await feedback.finish(job: formatting, failed: true);
      expect(feedback.current, isNull);
      expect(calls.last.method, 'dismiss');
      await feedback.dispose();
    },
  );

  test('delayed finalization cannot dismiss a newly started job', () async {
    final feedback = ProcessingFeedbackService.forTesting();
    final first = await feedback.begin('first', 'Whisper');
    final finishing = feedback.finish(job: first);
    await pumpEventQueue();
    final second = await feedback.begin('second', 'Qwen');
    await finishing;
    expect(feedback.current!.entryId, 'second');
    expect(calls.last.method, 'show');
    await feedback.finish(job: second, failed: true);
    expect(feedback.current, isNull);
    await feedback.dispose();
  });
}
