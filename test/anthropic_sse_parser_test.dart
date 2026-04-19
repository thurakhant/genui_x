import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x/src/anthropic_sse_parser.dart';

Stream<List<int>> _toByteStream(String text) async* {
  yield utf8.encode(text);
}

Stream<List<int>> _chunkedStream(String text, int chunkSize) async* {
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i += chunkSize) {
    yield bytes.sublist(
      i,
      i + chunkSize > bytes.length ? bytes.length : i + chunkSize,
    );
  }
}

void main() {
  late AnthropicSseParser parser;

  setUp(() => parser = AnthropicSseParser());

  group('AnthropicSseParser', () {
    test('extracts text_delta from a valid SSE event', () async {
      const sse =
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello']);
    });

    test('handles multiple text_delta events', () async {
      const sse =
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello "}}\n\n'
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"world"}}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello ', 'world']);
    });

    test('ignores non-text_delta event types', () async {
      const sse =
          'event: message_start\n'
          'data: {"type":"message_start","message":{"id":"msg_123"}}\n\n'
          'event: content_block_start\n'
          'data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\n'
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}\n\n'
          'event: message_stop\n'
          'data: {"type":"message_stop"}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hi']);
    });

    test('ignores [DONE] sentinel', () async {
      const sse = 'data: [DONE]\n\n';
      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, isEmpty);
    });

    test('handles partial TCP chunks gracefully', () async {
      const sse =
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Split"}}\n\n';

      // Split into 5-byte chunks to simulate partial network packets
      final chunks = await parser.parse(_chunkedStream(sse, 5)).toList();
      expect(chunks, ['Split']);
    });

    test('ignores malformed JSON without crashing', () async {
      const sse =
          'data: {not valid json}\n\n'
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"OK"}}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['OK']);
    });

    test('skips empty text_delta values', () async {
      const sse =
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":""}}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, isEmpty);
    });

    test('handles tool_use input_json_delta without emitting', () async {
      const sse =
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\\"city\\""}}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, isEmpty);
    });
  });
}
