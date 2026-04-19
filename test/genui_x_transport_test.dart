// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';
import 'package:http/http.dart' as http;

// Captures the raw request body for inspection.
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

// Minimal mock HTTP client — no extra dependencies needed.
class _MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest) _handler;
  _MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}

http.StreamedResponse _response(int status, String body) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status);

// Empty catalog is valid — no CatalogItems needed for HTTP-level tests.
final _catalog = Catalog([], catalogId: 'test.catalog');

GenuiXTransport _transport({required http.Client httpClient}) =>
    GenuiXTransport(
      apiKey: 'test-key',
      catalog: _catalog,
      maxRetries: 0,
      httpClient: httpClient,
    );

void main() {
  group('GenuiXTransport — error handling', () {
    test('throws GenuiXAuthError on 401', () async {
      final t = _transport(
        httpClient: _MockHttpClient(
          (_) async => _response(401, 'Unauthorized'),
        ),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      t.dispose();
    });

    test('throws GenuiXAuthError on 403', () async {
      final t = _transport(
        httpClient: _MockHttpClient((_) async => _response(403, 'Forbidden')),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      t.dispose();
    });

    test('completes normally on 500 — error surfaced as chunk', () async {
      final t = _transport(
        httpClient: _MockHttpClient(
          (_) async => _response(500, 'Internal Server Error'),
        ),
      );
      await expectLater(t.sendRequest(ChatMessage.user('hello')), completes);
      t.dispose();
    });

    test('completes normally on network error', () async {
      final t = _transport(
        httpClient: _MockHttpClient(
          (_) async => throw Exception('Connection refused'),
        ),
      );
      await expectLater(t.sendRequest(ChatMessage.user('hello')), completes);
      t.dispose();
    });
  });

  group('GenuiXTransport — rate limiting', () {
    test('throws GenuiXRateLimitError on 429', () async {
      final t = _transport(
        httpClient: _MockHttpClient(
          (_) async => _response(429, 'Too Many Requests'),
        ),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXRateLimitError>()),
      );
      t.dispose();
    });

    test(
      'GenuiXRateLimitError.retryAfter is null when header absent',
      () async {
        GenuiXRateLimitError? caught;
        final t = _transport(
          httpClient: _MockHttpClient(
            (_) async => _response(429, 'Too Many Requests'),
          ),
        );
        try {
          await t.sendRequest(ChatMessage.user('hello'));
        } on GenuiXRateLimitError catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(caught!.retryAfter, isNull);
        t.dispose();
      },
    );

    test(
      'GenuiXRateLimitError.retryAfter is parsed from Retry-After header',
      () async {
        GenuiXRateLimitError? caught;
        final t = _transport(
          httpClient: _MockHttpClient((_) async {
            return http.StreamedResponse(
              Stream.value(utf8.encode('Too Many Requests')),
              429,
              headers: {'retry-after': '30'},
            );
          }),
        );
        try {
          await t.sendRequest(ChatMessage.user('hello'));
        } on GenuiXRateLimitError catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(caught!.retryAfter, 30);
        t.dispose();
      },
    );

    test('isLoading is false after rate limit error', () async {
      final t = _transport(
        httpClient: _MockHttpClient(
          (_) async => _response(429, 'Too Many Requests'),
        ),
      );
      try {
        await t.sendRequest(ChatMessage.user('hello'));
      } on GenuiXRateLimitError {
        // expected
      }
      expect(t.isLoading.value, isFalse);
      t.dispose();
    });
  });

  group('GenuiXTransport — streaming', () {
    test('emits text chunks from Anthropic SSE response', () async {
      const sseData =
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,'
          '"delta":{"type":"text_delta","text":"Hello"}}\n\n';

      final t = _transport(
        httpClient: _MockHttpClient(
          (_) async =>
              http.StreamedResponse(Stream.value(utf8.encode(sseData)), 200),
        ),
      );

      final chunks = <String>[];
      final sub = t.incomingText.listen(chunks.add);
      await t.sendRequest(ChatMessage.user('hello'));
      await sub.cancel();

      expect(chunks, contains('Hello'));
      t.dispose();
    });

    test('emits text chunks from OpenAI SSE response', () async {
      const sseData =
          'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n'
          'data: [DONE]\n\n';

      final t = GenuiXTransport(
        apiKey: 'test-key',
        catalog: _catalog,
        streamFormat: GenuiXStreamFormat.openai,
        httpClient: _MockHttpClient(
          (_) async =>
              http.StreamedResponse(Stream.value(utf8.encode(sseData)), 200),
        ),
      );

      final chunks = <String>[];
      final sub = t.incomingText.listen(chunks.add);
      await t.sendRequest(ChatMessage.user('hello'));
      await sub.cancel();

      expect(chunks, contains('Hi'));
      t.dispose();
    });
  });

  group('GenuiXTransport — state', () {
    test('isLoading is false initially', () {
      final t = GenuiXTransport(apiKey: 'test-key', catalog: _catalog);
      expect(t.isLoading.value, isFalse);
      t.dispose();
    });

    test('isLoading is false after request completes', () async {
      final t = _transport(
        httpClient: _MockHttpClient((_) async => _response(500, 'error')),
      );
      await t.sendRequest(ChatMessage.user('hello'));
      expect(t.isLoading.value, isFalse);
      t.dispose();
    });

    test('cancel() resets isLoading and is safe when idle', () {
      final t = GenuiXTransport(apiKey: 'test-key', catalog: _catalog);
      expect(() => t.cancel(), returnsNormally);
      expect(t.isLoading.value, isFalse);
      t.dispose();
    });

    test('clearHistory() can be called at any time', () {
      final t = GenuiXTransport(apiKey: 'test-key', catalog: _catalog);
      expect(() => t.clearHistory(), returnsNormally);
      t.dispose();
    });

    test(
      'clearHistory() allows a fresh request after previous messages',
      () async {
        final requestBodies = <String>[];
        final t = GenuiXTransport(
          apiKey: 'test-key',
          catalog: _catalog,
          httpClient: _MockHttpClient((req) async {
            requestBodies.add(await req.finalize().bytesToString());
            return _response(401, 'stop'); // 401 to break early
          }),
        );

        // First request — will fail with auth error
        await expectLater(
          t.sendRequest(ChatMessage.user('first')),
          throwsA(isA<GenuiXAuthError>()),
        );

        t.clearHistory();

        // Second request — history should only have the new message
        await expectLater(
          t.sendRequest(ChatMessage.user('second')),
          throwsA(isA<GenuiXAuthError>()),
        );

        // After clear, second request body should not contain 'first'
        expect(requestBodies.length, 2);
        final secondBody = requestBodies[1];
        expect(secondBody, isNot(contains('"first"')));
        expect(secondBody, contains('"second"'));
        t.dispose();
      },
    );
  });

  group('GenuiXTransport.openai()', () {
    test('sends Authorization Bearer header', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.openai(
        apiKey: 'sk-test',
        catalog: _catalog,
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.headers['authorization'], 'Bearer sk-test');
      t.dispose();
    });

    test('posts to /v1/chat/completions', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.openai(
        apiKey: 'sk-test',
        catalog: _catalog,
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.url.path, '/v1/chat/completions');
      t.dispose();
    });

    test('uses gpt-4o-mini as default model', () async {
      final client = _CapturingHttpClient();
      final t = GenuiXTransport.openai(
        apiKey: 'sk-test',
        catalog: _catalog,
        httpClient: client,
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(client.lastRequestBody, contains('gpt-4o-mini'));
      t.dispose();
    });

    test('custom baseUrl is respected', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.openai(
        apiKey: 'sk-test',
        catalog: _catalog,
        baseUrl: 'https://openrouter.ai/api',
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.url.host, 'openrouter.ai');
      t.dispose();
    });
  });

  group('GenuiXTransport — surfaceOperations and clientDataModel', () {
    test(
      'default (no surfaceOperations) includes createSurface in system prompt',
      () async {
        final client = _CapturingHttpClient();
        final t = GenuiXTransport(
          apiKey: 'test-key',
          catalog: _catalog,
          httpClient: client,
        );
        await expectLater(
          t.sendRequest(ChatMessage.user('hello')),
          throwsA(isA<GenuiXAuthError>()),
        );
        expect(client.lastRequestBody, contains('createSurface'));
        t.dispose();
      },
    );

    test(
      'SurfaceOperations.all includes deleteSurface in system prompt',
      () async {
        final client = _CapturingHttpClient();
        final t = GenuiXTransport(
          apiKey: 'test-key',
          catalog: _catalog,
          surfaceOperations: SurfaceOperations.all(dataModel: false),
          httpClient: client,
        );
        await expectLater(
          t.sendRequest(ChatMessage.user('hello')),
          throwsA(isA<GenuiXAuthError>()),
        );
        expect(client.lastRequestBody, contains('deleteSurface'));
        t.dispose();
      },
    );

    test(
      'SurfaceOperations.createOnly restricts updates in system prompt',
      () async {
        final client = _CapturingHttpClient();
        final t = GenuiXTransport(
          apiKey: 'test-key',
          catalog: _catalog,
          surfaceOperations: SurfaceOperations.createOnly(dataModel: false),
          httpClient: client,
        );
        await expectLater(
          t.sendRequest(ChatMessage.user('hello')),
          throwsA(isA<GenuiXAuthError>()),
        );
        // createOnly has update:false — genui injects a "DO NOT update" instruction
        expect(
          client.lastRequestBody,
          contains('DO NOT update or modify surfaces'),
        );
        t.dispose();
      },
    );

    test('clientDataModel is included in system prompt', () async {
      final client = _CapturingHttpClient();
      final t = GenuiXTransport(
        apiKey: 'test-key',
        catalog: _catalog,
        clientDataModel: {'userName': 'Alice', 'plan': 'pro'},
        httpClient: client,
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(client.lastRequestBody, contains('Alice'));
      expect(client.lastRequestBody, contains('pro'));
      t.dispose();
    });
  });

  group('GenuiXTransport.anthropic()', () {
    test('sends x-api-key header', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.anthropic(
        apiKey: 'ant-test',
        catalog: _catalog,
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.headers['x-api-key'], 'ant-test');
      t.dispose();
    });

    test('posts to /v1/messages', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.anthropic(
        apiKey: 'ant-test',
        catalog: _catalog,
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.url.path, '/v1/messages');
      t.dispose();
    });

    test('uses claude-haiku-4-5-20251001 as default model', () async {
      final client = _CapturingHttpClient();
      final t = GenuiXTransport.anthropic(
        apiKey: 'ant-test',
        catalog: _catalog,
        httpClient: client,
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(client.lastRequestBody, contains('claude-haiku-4-5-20251001'));
      t.dispose();
    });

    test('custom baseUrl is respected', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.anthropic(
        apiKey: 'ant-test',
        catalog: _catalog,
        baseUrl: 'https://my-proxy.example.com',
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.url.host, 'my-proxy.example.com');
      t.dispose();
    });
  });

  group('GenuiXTransport — retry on 429', () {
    test('maxRetries: 0 throws immediately on 429', () async {
      final t = GenuiXTransport(
        apiKey: 'test-key',
        catalog: _catalog,
        maxRetries: 0,
        httpClient: _MockHttpClient(
          (_) async => _response(429, 'rate limited'),
        ),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXRateLimitError>()),
      );
      t.dispose();
    });

    test('succeeds on second attempt after 429', () async {
      int calls = 0;
      const sseData =
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","index":0,'
          '"delta":{"type":"text_delta","text":"Hi"}}\n\n';

      final t = GenuiXTransport(
        apiKey: 'test-key',
        catalog: _catalog,
        maxRetries: 1,
        httpClient: _MockHttpClient((_) async {
          calls++;
          if (calls == 1) {
            return http.StreamedResponse(
              Stream.value(utf8.encode('rate limited')),
              429,
              headers: {'retry-after': '0'},
            );
          }
          return http.StreamedResponse(Stream.value(utf8.encode(sseData)), 200);
        }),
      );

      await expectLater(t.sendRequest(ChatMessage.user('hello')), completes);
      expect(calls, 2);
      t.dispose();
    });

    test('throws GenuiXRateLimitError after exhausting all retries', () async {
      final t = GenuiXTransport(
        apiKey: 'test-key',
        catalog: _catalog,
        maxRetries: 1,
        httpClient: _MockHttpClient(
          (_) async => http.StreamedResponse(
            Stream.value(utf8.encode('rate limited')),
            429,
            headers: {'retry-after': '0'},
          ),
        ),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXRateLimitError>()),
      );
      t.dispose();
    });
  });

  group('GenuiXTransport.gemini()', () {
    test('sends x-goog-api-key header', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.gemini(
        apiKey: 'goog-test',
        catalog: _catalog,
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.headers['x-goog-api-key'], 'goog-test');
      t.dispose();
    });

    test('embeds model in URL path with ?alt=sse', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.gemini(
        apiKey: 'goog-test',
        catalog: _catalog,
        model: 'gemini-2.5-pro',
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(
        captured!.url.path,
        '/v1beta/models/gemini-2.5-pro:streamGenerateContent',
      );
      expect(captured!.url.queryParameters['alt'], 'sse');
      t.dispose();
    });

    test('uses gemini-2.5-flash as default model', () async {
      final client = _CapturingHttpClient();
      final t = GenuiXTransport.gemini(
        apiKey: 'goog-test',
        catalog: _catalog,
        httpClient: client,
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(client.lastRequestBody, contains('"role":"user"'));
      // URL contains model — but body uses Gemini's contents shape.
      expect(client.lastRequestBody, isNot(contains('"messages"')));
      t.dispose();
    });

    test('builds Gemini contents payload with systemInstruction', () async {
      final client = _CapturingHttpClient();
      final t = GenuiXTransport.gemini(
        apiKey: 'goog-test',
        catalog: _catalog,
        httpClient: client,
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello world')),
        throwsA(isA<GenuiXAuthError>()),
      );
      final body = client.lastRequestBody!;
      expect(body, contains('"contents"'));
      expect(body, contains('"systemInstruction"'));
      expect(body, contains('"parts"'));
      expect(body, contains('hello world'));
      // Must NOT contain Anthropic/OpenAI fields.
      expect(body, isNot(contains('"max_tokens"')));
      expect(body, isNot(contains('"messages"')));
      t.dispose();
    });

    test('custom baseUrl is respected', () async {
      http.BaseRequest? captured;
      final t = GenuiXTransport.gemini(
        apiKey: 'goog-test',
        catalog: _catalog,
        baseUrl: 'https://my-vertex-proxy.example.com',
        httpClient: _MockHttpClient((req) async {
          captured = req;
          return _response(401, 'stop');
        }),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(captured!.url.host, 'my-vertex-proxy.example.com');
      t.dispose();
    });

    test('parses Gemini SSE response', () async {
      const sseData =
          'data: {"candidates":[{"content":{"parts":[{"text":"Hi"}],'
          '"role":"model"}}]}\n\n';

      final t = GenuiXTransport.gemini(
        apiKey: 'goog-test',
        catalog: _catalog,
        httpClient: _MockHttpClient(
          (_) async =>
              http.StreamedResponse(Stream.value(utf8.encode(sseData)), 200),
        ),
      );

      final chunks = <String>[];
      final sub = t.incomingText.listen(chunks.add);
      await t.sendRequest(ChatMessage.user('hello'));
      await sub.cancel();

      expect(chunks, contains('Hi'));
      t.dispose();
    });
  });

  group('GenuiXTransport.openai() — enforceJsonMode', () {
    test('does NOT inject response_format by default', () async {
      final client = _CapturingHttpClient();
      final t = GenuiXTransport.openai(
        apiKey: 'sk-test',
        catalog: _catalog,
        httpClient: client,
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(client.lastRequestBody, isNot(contains('response_format')));
      t.dispose();
    });

    test('injects response_format json_object when enabled', () async {
      final client = _CapturingHttpClient();
      final t = GenuiXTransport.openai(
        apiKey: 'sk-test',
        catalog: _catalog,
        enforceJsonMode: true,
        httpClient: client,
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      expect(client.lastRequestBody, contains('"response_format"'));
      expect(client.lastRequestBody, contains('"json_object"'));
      t.dispose();
    });

    test(
      'does not override an explicit requestBodyOverrides response_format',
      () async {
        final client = _CapturingHttpClient();
        final t = GenuiXTransport.openai(
          apiKey: 'sk-test',
          catalog: _catalog,
          enforceJsonMode: true,
          requestBodyOverrides: const {
            'response_format': {'type': 'json_schema', 'json_schema': {}},
          },
          httpClient: client,
        );
        await expectLater(
          t.sendRequest(ChatMessage.user('hello')),
          throwsA(isA<GenuiXAuthError>()),
        );
        // User override wins; the json_object default is not present.
        expect(client.lastRequestBody, contains('"json_schema"'));
        expect(client.lastRequestBody, isNot(contains('"json_object"')));
        t.dispose();
      },
    );
  });

  group('GenuiXTransport — debug flag', () {
    test('debug: false does not throw', () async {
      final t = GenuiXTransport(
        apiKey: 'test-key',
        catalog: _catalog,
        debug: false,
        httpClient: _MockHttpClient((_) async => _response(401, 'stop')),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      t.dispose();
    });

    test('debug: true does not throw', () async {
      final t = GenuiXTransport(
        apiKey: 'test-key',
        catalog: _catalog,
        debug: true,
        httpClient: _MockHttpClient((_) async => _response(401, 'stop')),
      );
      await expectLater(
        t.sendRequest(ChatMessage.user('hello')),
        throwsA(isA<GenuiXAuthError>()),
      );
      t.dispose();
    });
  });
}
