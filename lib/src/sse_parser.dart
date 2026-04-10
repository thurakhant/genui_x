// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

/// Parses Claude's Server-Sent Events (SSE) stream into text delta chunks.
///
/// Only `text_delta` events are emitted; all other event types are ignored.
class ClaudeSseParser {
  /// Transforms a raw byte stream from the Anthropic Messages API into
  /// a stream of text delta strings.
  Stream<String> parse(Stream<List<int>> byteStream) {
    return _parseLines(byteStream).transform(
      StreamTransformer.fromHandlers(
        handleData: _handleLine,
      ),
    );
  }

  void _handleLine(String line, EventSink<String> sink) {
    if (line.startsWith('data: ')) {
      final data = line.substring(6).trim();
      if (data == '[DONE]') return;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final type = json['type'] as String?;

        if (type == 'content_block_delta') {
          final delta = json['delta'] as Map<String, dynamic>?;
          if (delta?['type'] == 'text_delta') {
            final text = delta!['text'] as String?;
            if (text != null && text.isNotEmpty) {
              sink.add(text);
            }
          }
        }
      } catch (_) {
        // Ignore malformed JSON events
      }
    }
  }

  Stream<String> _parseLines(Stream<List<int>> byteStream) async* {
    final decoder = utf8.decoder;
    String buffer = '';

    await for (final chunk in byteStream) {
      buffer += decoder.convert(chunk);
      final lines = buffer.split('\n');
      // Keep the last (potentially incomplete) line in the buffer
      buffer = lines.removeLast();
      for (final line in lines) {
        yield line;
      }
    }

    // Emit any remaining buffered content
    if (buffer.isNotEmpty) {
      yield buffer;
    }
  }
}
