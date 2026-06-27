// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

// Provider wire-format conformance.
//
// These tests decode the actual request body and assert the *structure* each
// provider's API requires — not just that the system prompt text appears
// somewhere in the payload. The distinction matters: a system prompt placed
// under the wrong JSON key is silently ignored by the provider, so the model
// never receives the A2UI catalog instructions. Substring assertions miss
// that class of bug; structural assertions catch it.
//
// The catalog instruction marker `createSurface` is emitted by
// `PromptBuilder.chat` even for an empty catalog, so we use it to prove the
// system prompt reached the field the provider actually reads.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';
import 'package:http/http.dart' as http;

/// Captures the raw request body, then short-circuits with a 401 so
/// `sendRequest` returns quickly without needing a real stream.
class _CapturingHttpClient extends http.BaseClient {
  String? lastRequestBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequestBody = await (request as http.Request)
        .finalize()
        .bytesToString();
    return http.StreamedResponse(Stream.value(utf8.encode('')), 401);
  }
}

final _catalog = Catalog([], catalogId: 'test.catalog');

/// Sends one user message through [transport] and returns the decoded JSON
/// body the transport tried to POST.
Future<Map<String, dynamic>> _capturedBody(
  GenuiXTransport Function(http.Client) build,
) async {
  final client = _CapturingHttpClient();
  final t = build(client);
  await expectLater(
    t.sendRequest(ChatMessage.user('hello world')),
    throwsA(isA<GenuiXAuthError>()),
  );
  t.dispose();
  return jsonDecode(client.lastRequestBody!) as Map<String, dynamic>;
}

void main() {
  group('OpenAI wire format', () {
    test('delivers the system prompt as a system-role message', () async {
      final body = await _capturedBody(
        (c) => GenuiXTransport.openai(
          apiKey: 'sk-test',
          catalog: _catalog,
          httpClient: c,
        ),
      );

      final messages = body['messages'] as List<dynamic>;
      final system = messages.first as Map<String, dynamic>;

      // OpenAI reads the system prompt from a system-role message, never from
      // a top-level `system` field.
      expect(system['role'], 'system');
      expect(system['content'], contains('createSurface'));
      expect(
        body.containsKey('system'),
        isFalse,
        reason: 'OpenAI has no top-level `system` parameter; it is ignored.',
      );

      // The user turn must still follow the system message.
      final user = messages.last as Map<String, dynamic>;
      expect(user['role'], 'user');
      expect(user['content'], 'hello world');
    });
  });

  group('Ollama wire format', () {
    // Ollama is configured through the OpenAI-compatible path, so it was
    // subject to the same misplaced-system-prompt bug and is covered by the
    // same fix. This guards the most common local-dev setup.
    test('delivers the system prompt as a system-role message', () async {
      final body = await _capturedBody(
        (c) => GenuiXTransport.ollama(catalog: _catalog, httpClient: c),
      );

      final messages = body['messages'] as List<dynamic>;
      final system = messages.first as Map<String, dynamic>;
      expect(system['role'], 'system');
      expect(system['content'], contains('createSurface'));
      expect(body.containsKey('system'), isFalse);
    });
  });

  group('Anthropic wire format', () {
    test('delivers the system prompt as a top-level system field', () async {
      final body = await _capturedBody(
        (c) => GenuiXTransport.anthropic(
          apiKey: 'ant-test',
          catalog: _catalog,
          httpClient: c,
        ),
      );

      // Anthropic's Messages API reads the system prompt from a top-level
      // `system` string — the opposite of OpenAI.
      expect(body['system'], isA<String>());
      expect(body['system'], contains('createSurface'));

      // The system prompt must NOT be duplicated as a message role; the
      // Messages API rejects a `system` role inside `messages`.
      final messages = body['messages'] as List<dynamic>;
      for (final m in messages.cast<Map<String, dynamic>>()) {
        expect(m['role'], isNot('system'));
      }
      expect(messages.last['content'], 'hello world');
    });
  });

  group('Gemini wire format', () {
    test('delivers the system prompt via systemInstruction', () async {
      final body = await _capturedBody(
        (c) => GenuiXTransport.gemini(
          apiKey: 'goog-test',
          catalog: _catalog,
          httpClient: c,
        ),
      );

      // Gemini reads the system prompt from `systemInstruction.parts[].text`.
      final instruction = body['systemInstruction'] as Map<String, dynamic>;
      final parts = instruction['parts'] as List<dynamic>;
      final text = (parts.first as Map<String, dynamic>)['text'] as String;
      expect(text, contains('createSurface'));

      // Gemini uses `contents`, never the OpenAI/Anthropic `messages` or a
      // top-level `system` field.
      expect(body['contents'], isA<List<dynamic>>());
      expect(body.containsKey('messages'), isFalse);
      expect(body.containsKey('system'), isFalse);

      final contents = body['contents'] as List<dynamic>;
      final firstContent = contents.first as Map<String, dynamic>;
      final contentParts = firstContent['parts'] as List<dynamic>;
      expect(
        (contentParts.first as Map<String, dynamic>)['text'],
        'hello world',
      );
    });
  });
}
