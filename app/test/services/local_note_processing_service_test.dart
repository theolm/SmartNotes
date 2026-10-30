import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartnotes/data/services/local_formatting_session.dart';
import 'package:smartnotes/data/services/local_inference_queue.dart';
import 'package:smartnotes/data/services/local_note_processing_service.dart';
import 'package:smartnotes/domain/entities/ai_failure.dart';
import 'package:smartnotes/domain/entities/enums/ai_action.dart';
import 'package:smartnotes/domain/services/i_transcription_service.dart';
import '../helpers/local_services.dart';

class MockTranscription extends Mock implements ITranscriptionService {}

class FakeSession implements LocalFormattingSession {
  int promptTokens = 500;
  int generations = 0;
  bool disposed = false;
  Object? loadError;
  void Function()? onLoad;
  List<LlamaChatMessage>? messages;
  Map<String, dynamic>? format;
  Completer<void>? disposalGate;
  LlamaCompletion result = LlamaCompletion(
    text: jsonEncode({
      'title': 'Reunião',
      'subTitle': 'Planos',
      'markdown': '- Conversar com Ana amanhã.',
    }),
    finishReason: LlamaFinishReason.stop,
  );
  @override
  Future<void> load(String path) async {
    expect(path, contains('Qwen3-1.7B-Q4_K_M'));
    onLoad?.call();
    if (loadError != null) throw loadError!;
  }

  @override
  Future<int> countPrompt(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) async {
    this.messages = messages;
    this.format = format;
    return promptTokens;
  }

  @override
  Future<LlamaCompletion> generate(
    List<LlamaChatMessage> messages,
    Map<String, dynamic> format,
  ) async {
    generations++;
    return result;
  }

  @override
  Future<void> dispose() async {
    if (disposalGate != null) await disposalGate!.future;
    disposed = true;
  }
}

void main() {
  late FakeSession session;
  late MemoryFormattingModels models;
  late MockTranscription transcription;
  late LocalInferenceQueue queue;
  late LocalNoteProcessingService service;
  setUp(() {
    session = FakeSession();
    models = MemoryFormattingModels();
    transcription = MockTranscription();
    queue = LocalInferenceQueue();
    service = LocalNoteProcessingService.forTesting(
      models,
      transcription,
      queue,
      session: () => session,
    );
  });
  Future<dynamic> format([String text = 'Quero conversar com Ana amanhã.']) =>
      service.formatTranscription(
        action: AiAction.keyPoints,
        transcription: text,
      );
  Matcher failure(AiFailureCode code) =>
      isA<AiFailure>().having((e) => e.code, 'code', code);

  test(
    'offline formatting returns Markdown and keeps the exact original source',
    () async {
      const source = '  Quero conversar com Ana amanhã.\nNão vou viajar.  ';
      final note = await format(source);
      expect(note.title, 'Reunião');
      expect(note.markdown, startsWith('- '));
      expect(note.transcription, source);
      expect(session.disposed, true);
      expect(session.format!['type'], 'json_schema');
      expect(
        jsonDecode(session.messages!.last.content)['transcription'],
        source,
      );
      expect(session.messages!.first.content, contains('Never translate'));
      expect(session.messages!.first.content, contains('bullet'));
      verifyZeroInteractions(transcription);
      // No API client/key service exists in the formatter's dependencies.
    },
  );
  test('transcription delegates locally without loading Qwen', () async {
    when(
      () => transcription.transcribe('/audio.m4a'),
    ).thenAnswer((_) async => 'Olá');
    expect(await service.transcribe('/audio.m4a'), 'Olá');
    expect(session.messages, isNull);
  });
  for (final opening in [
    '# Conversation',
    '  # Conversation ###',
    '# **Conversation**',
    'Conversation\n============',
    '**Conversation**',
    '__Conversation__',
    '# Conversation\n\n## Plans for tomorrow.',
    '# Conversation\n\n**Plans for tomorrow.**',
    'Conversation\n---\n\nPlans for tomorrow.\n---',
    '\n\n# Conversation\n\n# Conversation',
  ]) {
    test('removes exact opening metadata headers: $opening', () async {
      const body =
          '- Speak with Ana tomorrow.\n\n## Details\nKeep this section.';
      session.result = LlamaCompletion(
        text: jsonEncode({
          'title': 'Conversation',
          'subTitle': 'Plans for tomorrow.',
          'markdown': '$opening\n\n$body',
        }),
        finishReason: LlamaFinishReason.stop,
      );
      final note = await format('Speak with Ana tomorrow.');
      expect(note.markdown, body);
      expect(note.title, 'Conversation');
      expect(note.subTitle, 'Plans for tomorrow.');
      expect(note.transcription, 'Speak with Ana tomorrow.');
    });
  }
  for (final body in [
    'Conversation\n\nSpeak with Ana tomorrow.',
    'Plans for tomorrow.\n\nSpeak with Ana tomorrow.',
    '**Plans for tomorrow.**\nSpeak with Ana tomorrow.',
    '# Conversation with Ana\n\nSpeak tomorrow.',
    '# conversation\n\nSpeak tomorrow.',
    '## Details\n\n# Conversation',
    '- Conversation\n- Speak tomorrow.',
    '> # Conversation\n\nSpeak tomorrow.',
    '```markdown\n# Conversation\n```',
    '    # Conversation\n\nSpeak tomorrow.',
    '\nSpeak with Ana tomorrow.\n\n# Conversation\n',
  ]) {
    test('preserves prose and non-metadata blocks verbatim: $body', () async {
      session.result = LlamaCompletion(
        text: jsonEncode({
          'title': 'Conversation',
          'subTitle': 'Plans for tomorrow.',
          'markdown': body,
        }),
        finishReason: LlamaFinishReason.stop,
      );
      expect((await format('Speak with Ana tomorrow.')).markdown, body);
    });
  }
  test('rejects a body consisting only of metadata headers', () async {
    session.result = LlamaCompletion(
      text: jsonEncode({
        'title': 'Conversation',
        'subTitle': 'Plans for tomorrow.',
        'markdown': '# Conversation\n\n**Plans for tomorrow.**',
      }),
      finishReason: LlamaFinishReason.stop,
    );
    await expectLater(
      format('Speak with Ana tomorrow.'),
      throwsA(failure(AiFailureCode.invalidNote)),
    );
    expect(session.disposed, true);
  });
  for (final body in [
    '    # Conversation\n\nSpeak tomorrow.\n',
    'Speak tomorrow.\r\n\r\n## Details\r\nKeep this.\r\n',
  ]) {
    test('header removal preserves remaining whitespace: $body', () async {
      session.result = LlamaCompletion(
        text: jsonEncode({
          'title': 'Conversation',
          'subTitle': '',
          'markdown': '# Conversation\r\n\r\n$body',
        }),
        finishReason: LlamaFinishReason.stop,
      );
      expect((await format('Speak tomorrow.')).markdown, body);
    });
  }
  test(
    'metadata uses a two-field schema and the transcription language',
    () async {
      const source = 'Quero conversar com Ana amanhã.';
      session.result = const LlamaCompletion(
        text: '{"title":"Conversa com Ana","subTitle":"Planos para amanhã."}',
        finishReason: LlamaFinishReason.stop,
      );
      final metadata = await service.generateMetadata(source);
      expect(metadata, (
        title: 'Conversa com Ana',
        subTitle: 'Planos para amanhã.',
      ));
      expect(session.format, LocalNoteProcessingService.metadataResponseFormat);
      expect(
        session.messages!.first.content,
        contains('same language as the transcription'),
      );
      expect(session.messages!.first.content, contains('Never translate'));
      expect(
        jsonDecode(session.messages!.last.content)['transcription'],
        source,
      );
      expect(session.disposed, true);
      verifyZeroInteractions(transcription);
    },
  );
  test('metadata skips inference when no model is selected', () async {
    models.ready = false;
    expect(await service.generateMetadata('Uma nota.'), isNull);
    expect(session.messages, isNull);
    expect(session.disposed, false);
  });
  test('downloaded but unselected model does not generate metadata', () async {
    models.ready = false;
    await models.download(
      modelId: models.catalog.first.id,
      onProgress: (_, _) {},
    );
    expect(await service.generateMetadata('Uma nota.'), isNull);
    expect(session.generations, 0);
  });
  for (final invalid in [
    '{}',
    '{',
    '{"title":"","subTitle":"Summary"}',
    '{"title":"Title","subTitle":" "}',
    '{"title":"Title","subTitle":3}',
    '{"title":"Title","subTitle":"Summary","markdown":"Body"}',
  ]) {
    test('rejects invalid metadata: $invalid', () async {
      session.result = LlamaCompletion(
        text: invalid,
        finishReason: LlamaFinishReason.stop,
      );
      await expectLater(
        service.generateMetadata('Uma nota.'),
        throwsA(failure(AiFailureCode.invalidNote)),
      );
      expect(session.disposed, true);
    });
  }
  test('rejects incomplete metadata and disposes the model', () async {
    session.result = const LlamaCompletion(
      text: '{"title":"Title","subTitle":"Summary"}',
      finishReason: LlamaFinishReason.length,
    );
    await expectLater(
      service.generateMetadata('Uma nota.'),
      throwsA(failure(AiFailureCode.incompleteNote)),
    );
    expect(session.disposed, true);
  });
  for (final action in AiAction.values) {
    test(
      'supports ${action.name} as a stateless presentation preset',
      () async {
        await service.formatTranscription(
          action: action,
          transcription: 'Uma nota.',
        );
        expect(session.messages, hasLength(2));
        expect(session.messages!.first.content, contains('Presentation:'));
        expect(
          session.messages!.first.content,
          contains(
            'Write all three fields in the same language as the transcription.',
          ),
        );
        expect(
          session.messages!.first.content,
          contains(
            'Write the markdown body in the same language as the transcription; never translate it.',
          ),
        );
        expect(
          session.messages!.first.content,
          contains('The markdown field is the note body only.'),
        );
        expect(
          session.messages!.first.content,
          contains('Do not repeat title or subTitle'),
        );
        final prompt = session.messages!.first.content;
        expect(prompt, contains('Example of the selected preset only'));
        final example =
            jsonDecode(prompt.split('Output: ').last) as Map<String, dynamic>;
        final body = example['markdown'] as String;
        expect(
          example.keys,
          unorderedEquals(['title', 'subTitle', 'markdown']),
        );
        expect(body, contains('Ana'));
        expect(body, contains('tomorrow'));
        expect(body.toLowerCase(), contains('friday'));
        expect(body.toLowerCase(), matches(r'not|no |won’t'));
        if (action == AiAction.keyPoints) {
          expect(body.split('\n'), everyElement(startsWith('- ')));
          expect(prompt, contains('each starting with "- "'));
        } else {
          expect(
            RegExp(r'^\s*(?:[-*+]|\d+[.)])\s', multiLine: true).hasMatch(body),
            false,
          );
        }
        if (action == AiAction.journalEntry) {
          expect(prompt, contains('first-person prose in paragraphs'));
          expect(body, startsWith('I '));
        }
        switch (action) {
          case AiAction.journalEntry:
          case AiAction.formalSummary:
          case AiAction.casualRecap:
            expect(prompt, contains('Convert source lists into sentences'));
            expect(prompt, contains('No bullet points, numbered lists'));
          case AiAction.faithfulTranscription:
            expect(
              prompt,
              contains('Do not summarize, paraphrase, reorganize'),
            );
            expect(prompt, contains('Preserve existing source lists'));
            expect(
              body,
              'I want to speak with Ana tomorrow. I will not travel on Friday.',
            );
          case AiAction.organizedNote:
            expect(prompt, contains('section headings only where useful'));
          case AiAction.keyPoints:
            break;
        }
        expect(session.disposed, true);
      },
    );
  }
  test('full rendered prompt plus output stays inside 4096 tokens', () async {
    session.promptTokens = 4096 - 1536 - 64;
    await format();
    expect(session.generations, 1);
  });
  test(
    'oversized prompt is rejected before generation, never truncated',
    () async {
      session.promptTokens = 4096 - 1536 - 64 + 1;
      await expectLater(format(), throwsA(failure(AiFailureCode.noteTooLong)));
      expect(session.generations, 0);
      expect(session.disposed, true);
    },
  );
  test(
    'token/context exhaustion rejects partial JSON even when it parses',
    () async {
      session.result = LlamaCompletion(
        text: session.result.text,
        finishReason: LlamaFinishReason.length,
      );
      await expectLater(
        format(),
        throwsA(failure(AiFailureCode.incompleteNote)),
      );
      expect(session.disposed, true);
    },
  );
  for (final invalid in [
    '{}',
    '{',
    '{"title":4,"subTitle":"","markdown":"x"}',
    '{"title":"","subTitle":"","markdown":"x"}',
    '{"title":"x","subTitle":"","markdown":""}',
    '{"title":"x","subTitle":"","markdown":"x","transcription":"invented"}',
  ]) {
    test('invalid output is rejected: $invalid', () async {
      session.result = LlamaCompletion(
        text: invalid,
        finishReason: LlamaFinishReason.stop,
      );
      await expectLater(format(), throwsA(failure(AiFailureCode.invalidNote)));
      expect(session.disposed, true);
    });
  }
  test('empty source does not load or generate', () async {
    await expectLater(format(' \n '), throwsA(failure(AiFailureCode.noSpeech)));
    expect(session.disposed, false);
  });
  test(
    'failed native load disposes session and does not expose private error',
    () async {
      session.loadError = StateError('Private transcript');
      await expectLater(format(), throwsA(failure(AiFailureCode.unavailable)));
      expect(session.disposed, true);
    },
  );
  test(
    'model lost during native load offers repair and disposes the session',
    () async {
      session.onLoad = () => models.ready = false;
      session.loadError = StateError('Private native path');
      await expectLater(
        format(),
        throwsA(failure(AiFailureCode.formattingModelMissing)),
      );
      expect(session.disposed, true);
      expect(session.generations, 0);
    },
  );
  test('missing model has no online fallback and queue can recover', () async {
    models.ready = false;
    await expectLater(
      format(),
      throwsA(failure(AiFailureCode.formattingModelMissing)),
    );
    expect(session.messages, isNull);
    models.ready = true;
    expect((await format()).title, 'Reunião');
  });
  test(
    'shared STT/LLM lease waits for native disposal before the next job',
    () async {
      final sttGate = Completer<void>();
      final stt = queue.run(() => sttGate.future);
      session.disposalGate = Completer<void>();
      final formatting = format();
      await pumpEventQueue();
      expect(session.messages, isNull);
      sttGate.complete();
      await stt;
      await pumpEventQueue();
      expect(session.generations, 1);
      var nextStarted = false;
      final next = queue.run(() async {
        nextStarted = true;
      });
      await pumpEventQueue();
      expect(nextStarted, false);
      session.disposalGate!.complete();
      await formatting;
      await next;
      expect(session.disposed, true);
      expect(nextStarted, true);
    },
  );
}
