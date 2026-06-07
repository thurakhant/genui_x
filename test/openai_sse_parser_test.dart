import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x/src/openai_sse_parser.dart';

Stream<List<int>> _toByteStream(String text) async* {
  yield utf8.encode(text);
}

Stream<List<int>> _chunkedStream(String text, int chunkSize) async* {
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i += chunkSize) {
    final end = i + chunkSize > bytes.length ? bytes.length : i + chunkSize;
    yield bytes.sublist(i, end);
  }
}

void main() {
  late OpenAiSseParser parser;

  setUp(() => parser = OpenAiSseParser());

  group('OpenAiSseParser', () {
    test('extracts content from valid SSE event', () async {
      const sse = 'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello']);
    });

    test('accepts SSE lines without a space after data:', () async {
      const sse = 'data:{"choices":[{"delta":{"content":"Hello"}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello']);
    });

    test('handles multiple content deltas', () async {
      const sse =
          'data: {"choices":[{"delta":{"content":"Hello "}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"world"}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello ', 'world']);
    });

    test('ignores non-content deltas', () async {
      const sse =
          'data: {"choices":[{"delta":{"role":"assistant"}}]}\n\n'
          'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hi']);
    });

    test('ignores [DONE] sentinel', () async {
      const sse = 'data: [DONE]\n\n';
      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, isEmpty);
    });

    test('handles partial TCP chunks gracefully', () async {
      const sse = 'data: {"choices":[{"delta":{"content":"Split"}}]}\n\n';

      final chunks = await parser.parse(_chunkedStream(sse, 4)).toList();
      expect(chunks, ['Split']);
    });

    test('ignores malformed JSON without crashing', () async {
      const sse =
          'data: {not valid json}\n\n'
          'data: {"choices":[{"delta":{"content":"OK"}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['OK']);
    });
  });
}
