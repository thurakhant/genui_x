// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

/// Parses OpenAI-style SSE streams into text delta chunks.
class OpenAiSseParser {
  /// Transforms a raw byte stream into a stream of text delta strings.
  Stream<String> parse(Stream<List<int>> byteStream) {
    return _parseLines(
      byteStream,
    ).transform(StreamTransformer.fromHandlers(handleData: _handleLine));
  }

  void _handleLine(String line, EventSink<String> sink) {
    if (!line.startsWith('data:')) return;

    final data = line.substring(5).trim();
    if (data == '[DONE]') return;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return;

      final first = choices.first as Map<String, dynamic>;
      final delta = first['delta'] as Map<String, dynamic>?;
      final text = delta?['content'] as String?;
      if (text != null && text.isNotEmpty) {
        sink.add(text);
      }
    } catch (_) {
      // Ignore malformed JSON events
    }
  }

  Stream<String> _parseLines(Stream<List<int>> byteStream) async* {
    final decoder = utf8.decoder;
    var buffer = '';

    await for (final chunk in byteStream) {
      buffer += decoder.convert(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();
      for (final line in lines) {
        yield line;
      }
    }

    if (buffer.isNotEmpty) {
      yield buffer;
    }
  }
}
