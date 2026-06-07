// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_x/src/gemini_sse_parser.dart';

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
  late GeminiSseParser parser;

  setUp(() => parser = GeminiSseParser());

  group('GeminiSseParser', () {
    test('extracts text from a single SSE event', () async {
      const sse =
          'data: {"candidates":[{"content":{"parts":[{"text":"Hello"}],'
          '"role":"model"}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello']);
    });

    test('accepts SSE lines without a space after data:', () async {
      const sse =
          'data:{"candidates":[{"content":{"parts":[{"text":"Hello"}],'
          '"role":"model"}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello']);
    });

    test('handles multiple text deltas across events', () async {
      const sse =
          'data: {"candidates":[{"content":{"parts":[{"text":"Hello "}]}}]}\n\n'
          'data: {"candidates":[{"content":{"parts":[{"text":"world"}]}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hello ', 'world']);
    });

    test('handles multiple parts in a single event', () async {
      const sse =
          'data: {"candidates":[{"content":{"parts":['
          '{"text":"Part A"},{"text":"Part B"}]}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Part A', 'Part B']);
    });

    test('ignores non-text parts (e.g. function calls)', () async {
      const sse =
          'data: {"candidates":[{"content":{"parts":['
          '{"functionCall":{"name":"foo"}},{"text":"Visible"}]}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Visible']);
    });

    test('handles partial TCP chunks gracefully', () async {
      const sse =
          'data: {"candidates":[{"content":{"parts":[{"text":"Split"}]}}]}\n\n';

      final chunks = await parser.parse(_chunkedStream(sse, 4)).toList();
      expect(chunks, ['Split']);
    });

    test('ignores malformed JSON without crashing', () async {
      const sse =
          'data: {not valid json}\n\n'
          'data: {"candidates":[{"content":{"parts":[{"text":"OK"}]}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['OK']);
    });

    test('ignores [DONE] sentinel and empty data lines', () async {
      const sse =
          'data: \n\n'
          'data: [DONE]\n\n'
          'data: {"candidates":[{"content":{"parts":[{"text":"Hi"}]}}]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, ['Hi']);
    });

    test('returns nothing when candidates list is empty', () async {
      const sse = 'data: {"candidates":[]}\n\n';

      final chunks = await parser.parse(_toByteStream(sse)).toList();
      expect(chunks, isEmpty);
    });
  });
}
