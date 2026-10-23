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
}
