// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

/// Parses Google Gemini's Server-Sent Events (SSE) stream into text deltas.
///
/// Gemini's `streamGenerateContent` endpoint returns SSE chunks of the form:
///
/// ```
/// data: {"candidates":[{"content":{"parts":[{"text":"Hello"}],"role":"model"}}]}
/// ```
///
/// Only `candidates[0].content.parts[*].text` payloads are emitted; tool calls,
/// safety ratings, and usage metadata are ignored at this layer.
class GeminiSseParser {
  /// Transforms a raw byte stream from the Gemini API into a stream of text
  /// delta strings.
  Stream<String> parse(Stream<List<int>> byteStream) {
    return _parseLines(
      byteStream,
    ).transform(StreamTransformer.fromHandlers(handleData: _handleLine));
  }

  void _handleLine(String line, EventSink<String> sink) {
    if (!line.startsWith('data: ')) return;

    final data = line.substring(6).trim();
    if (data.isEmpty || data == '[DONE]') return;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return;

      final first = candidates.first as Map<String, dynamic>;
      final content = first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null) return;

      for (final part in parts) {
        if (part is! Map<String, dynamic>) continue;
        final text = part['text'] as String?;
        if (text != null && text.isNotEmpty) {
          sink.add(text);
        }
      }
    } catch (_) {
      // Ignore malformed JSON events.
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
