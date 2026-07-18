// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;

import 'anthropic_sse_parser.dart';
import 'gemini_sse_parser.dart';
import 'genui_x_config.dart';
import 'openai_sse_parser.dart';

/// The wire-format identity of a backend: the HTTP routing details that
/// distinguish one provider's contract from another.
///
/// These are exactly the values that were previously hand-copied into each
/// provider factory. Centralising them here keeps a provider's routing in one
/// place, so a new backend can't be wired up with the wrong auth header or
/// endpoint — and the body shape for each is locked by
/// `test/provider_conformance_test.dart`.
///
/// Behavioural knobs (retries, debug, prompt fragments, token limits) are
/// caller-supplied and shared across providers, so they are deliberately not
/// part of a profile.
class _ProviderProfile {
  const _ProviderProfile({
    required this.endpointPath,
    required this.apiKeyHeader,
    required this.apiKeyPrefix,
    required this.streamFormat,
  });

  /// Path appended to the base URL. May contain a `{model}` placeholder that
  /// [GenuiXTransport._buildUri] substitutes at request time (Gemini).
  final String endpointPath;

  /// Header name carrying the API key (e.g. `x-api-key`, `authorization`).
  final String apiKeyHeader;

  /// Prefix prepended to the key value (e.g. `Bearer ` for Authorization).
  final String apiKeyPrefix;

  /// SSE format the response stream is parsed as.
  final GenuiXStreamFormat streamFormat;
}

const _anthropicProfile = _ProviderProfile(
  endpointPath: '/v1/messages',
  apiKeyHeader: 'x-api-key',
  apiKeyPrefix: '',
  streamFormat: GenuiXStreamFormat.anthropic,
);

const _openaiProfile = _ProviderProfile(
  endpointPath: '/v1/chat/completions',
  apiKeyHeader: 'authorization',
  apiKeyPrefix: 'Bearer ',
  streamFormat: GenuiXStreamFormat.openai,
);

const _geminiProfile = _ProviderProfile(
  // The {model} placeholder is substituted at request time; Gemini embeds the
  // model in the URL path.
  endpointPath: '/v1beta/models/{model}:streamGenerateContent?alt=sse',
  apiKeyHeader: 'x-goog-api-key',
  apiKeyPrefix: '',
  streamFormat: GenuiXStreamFormat.gemini,
);

/// A [Transport] implementation that connects any AI backend to genui.
///
/// Works with Anthropic Claude, OpenAI-compatible APIs, and any custom proxy.
/// Sends the A2UI widget schema as a system prompt and streams the response
/// back through genui's rendering pipeline.
///
/// ## Basic usage (Claude)
///
/// ```dart
/// final transport = GenuiXTransport(
///   apiKey: 'your-api-key',
///   catalog: myCatalog,
/// );
/// ```
///
/// ## Proxy / OpenAI-compatible backend
///
/// ```dart
/// final transport = GenuiXTransport(
///   apiKey: 'your-key',
///   catalog: myCatalog,
///   baseUrl: 'https://your-proxy.example.com',
///   endpointPath: '/v1/chat/completions',
///   apiKeyHeader: 'authorization',
///   apiKeyPrefix: 'Bearer ',
///   streamFormat: GenuiXStreamFormat.openai,
/// );
/// ```
class GenuiXTransport implements Transport {
  /// Creates a [GenuiXTransport].
  ///
  /// ### Required
  /// - [apiKey] — API key sent in the request header.
  /// - [catalog] — defines the UI components the AI can generate.
  ///
  /// ### Backend
  /// - [model] — model identifier. Defaults to `claude-haiku-4-5-20251001`.
  /// - [baseUrl] — base URL of the API. Defaults to `https://api.anthropic.com`.
  ///   Override to route through your own proxy.
  /// - [endpointPath] — path appended to [baseUrl]. Defaults to `/v1/messages`.
  /// - [maxTokens] — maximum tokens in the response. Defaults to `8192`.
  /// - [streamFormat] — SSE format to parse. Use [GenuiXStreamFormat.openai]
  ///   for OpenAI-compatible endpoints. Defaults to [GenuiXStreamFormat.anthropic].
  ///
  /// ### Auth / Headers
  /// - [apiKeyHeader] — header name for the API key. Defaults to `x-api-key`.
  /// - [apiKeyPrefix] — prefix prepended to the key value. Use `'Bearer '`
  ///   for Authorization-style headers.
  /// - [headers] — additional headers merged into every request.
  ///
  /// ### Prompt
  /// - [systemPromptFragments] — extra instructions injected into the system
  ///   prompt before the catalog schema (persona, date, domain restrictions).
  /// - [surfaceOperations] — controls which A2UI operations the AI may use
  ///   (create, update, delete surfaces). Defaults to create-only via
  ///   [PromptBuilder.chat]. Pass a [SurfaceOperations] value to use
  ///   [PromptBuilder.custom] instead.
  /// - [clientDataModel] — optional app-state snapshot injected into the
  ///   system prompt so the AI has context about the current user or session.
  /// - [requestBodyOverrides] — raw JSON fields merged into the request body,
  ///   useful for provider-specific options like `response_format`.
  ///
  /// ### Retries
  /// - [maxRetries] — number of automatic retries on 429 responses with
  ///   exponential backoff. Defaults to `3`. Set to `0` to disable.
  ///
  /// ### Debugging
  /// - [debug] — when `true`, prints request URL, status code, and errors
  ///   via [debugPrint]. Useful for diagnosing proxy configuration issues.
  /// - [debugVerbose] — when `true`, prints parser selection, raw SSE lines,
  ///   and emitted chunk previews. Only applies when [debug] is also `true`.
  /// - [httpClient] — override the HTTP client (useful for testing).
  GenuiXTransport({
    required String apiKey,
    required Catalog catalog,
    String? model,
    String? baseUrl,
    String endpointPath = '/v1/messages',
    int maxTokens = 8192,
    http.Client? httpClient,
    String apiKeyHeader = 'x-api-key',
    String apiKeyPrefix = '',
    Map<String, String> headers = const <String, String>{},
    GenuiXStreamFormat streamFormat = GenuiXStreamFormat.anthropic,
    Map<String, Object?> requestBodyOverrides = const <String, Object?>{},
    List<String> systemPromptFragments = const <String>[],
    bool debug = false,
    bool debugVerbose = false,
    SurfaceOperations? surfaceOperations,
    Map<String, Object?>? clientDataModel,
    int maxRetries = 3,
    bool enforceJsonMode = false,
  }) : _config = GenuiXConfig(
         apiKey: apiKey,
         model: model ?? 'claude-haiku-4-5-20251001',
         baseUrl: baseUrl ?? 'https://api.anthropic.com',
         endpointPath: endpointPath,
         maxTokens: maxTokens,
         apiKeyHeader: apiKeyHeader,
         apiKeyPrefix: apiKeyPrefix,
         headers: headers,
         streamFormat: streamFormat,
         requestBodyOverrides: requestBodyOverrides,
         systemPromptFragments: systemPromptFragments,
         debug: debug,
         debugVerbose: debugVerbose,
         surfaceOperations: surfaceOperations,
         clientDataModel: clientDataModel,
         maxRetries: maxRetries,
         enforceJsonMode: enforceJsonMode,
       ),
       _catalog = catalog,
       _httpClient = httpClient ?? http.Client(),
       _adapter = A2uiTransportAdapter();

  /// Creates a [GenuiXTransport] pre-configured for OpenAI-compatible backends.
  ///
  /// Sets the correct `Authorization: Bearer` header, `/v1/chat/completions`
  /// endpoint, and OpenAI SSE stream format automatically — no boilerplate needed.
  ///
  /// Works with OpenAI, OpenRouter, LiteLLM, and any OpenAI-compatible proxy.
  ///
  /// ```dart
  /// final transport = GenuiXTransport.openai(
  ///   apiKey: 'sk-your-openai-key',
  ///   catalog: myCatalog,
  /// );
  /// ```
  ///
  /// Override [baseUrl] for third-party providers:
  /// ```dart
  /// GenuiXTransport.openai(
  ///   apiKey: 'sk-or-key',
  ///   catalog: myCatalog,
  ///   baseUrl: 'https://openrouter.ai/api',
  ///   model: 'anthropic/claude-3.5-sonnet',
  /// );
  /// ```
  factory GenuiXTransport.openai({
    required String apiKey,
    required Catalog catalog,
    String model = 'gpt-4o-mini',
    String baseUrl = 'https://api.openai.com',
    int maxTokens = 8192,
    http.Client? httpClient,
    Map<String, String> headers = const <String, String>{},
    Map<String, Object?> requestBodyOverrides = const <String, Object?>{},
    List<String> systemPromptFragments = const <String>[],
    bool debug = false,
    bool debugVerbose = false,
    SurfaceOperations? surfaceOperations,
    Map<String, Object?>? clientDataModel,
    int maxRetries = 3,
    bool enforceJsonMode = false,
  }) {
    return GenuiXTransport(
      apiKey: apiKey,
      catalog: catalog,
      model: model,
      baseUrl: baseUrl,
      endpointPath: _openaiProfile.endpointPath,
      maxTokens: maxTokens,
      httpClient: httpClient,
      apiKeyHeader: _openaiProfile.apiKeyHeader,
      apiKeyPrefix: _openaiProfile.apiKeyPrefix,
      headers: headers,
      streamFormat: _openaiProfile.streamFormat,
      requestBodyOverrides: requestBodyOverrides,
      systemPromptFragments: systemPromptFragments,
      debug: debug,
      debugVerbose: debugVerbose,
      surfaceOperations: surfaceOperations,
      clientDataModel: clientDataModel,
      maxRetries: maxRetries,
      enforceJsonMode: enforceJsonMode,
    );
  }

  /// Creates a [GenuiXTransport] pre-configured for Anthropic Claude.
  ///
  /// Sets the correct `x-api-key` header, `/v1/messages` endpoint, and
  /// Anthropic SSE stream format automatically — mirrors [GenuiXTransport.openai]
  /// for symmetry and explicit defaults.
  ///
  /// ```dart
  /// final transport = GenuiXTransport.anthropic(
  ///   apiKey: 'your-anthropic-key',
  ///   catalog: myCatalog,
  /// );
  /// ```
  ///
  /// Override [model] for a different Claude version:
  /// ```dart
  /// GenuiXTransport.anthropic(
  ///   apiKey: 'your-key',
  ///   catalog: myCatalog,
  ///   model: 'claude-sonnet-4-6',
  /// );
  /// ```
  factory GenuiXTransport.anthropic({
    required String apiKey,
    required Catalog catalog,
    String model = 'claude-haiku-4-5-20251001',
    String baseUrl = 'https://api.anthropic.com',
    int maxTokens = 8192,
    http.Client? httpClient,
    Map<String, String> headers = const <String, String>{},
    Map<String, Object?> requestBodyOverrides = const <String, Object?>{},
    List<String> systemPromptFragments = const <String>[],
    bool debug = false,
    bool debugVerbose = false,
    SurfaceOperations? surfaceOperations,
    Map<String, Object?>? clientDataModel,
    int maxRetries = 3,
  }) {
    return GenuiXTransport(
      apiKey: apiKey,
      catalog: catalog,
      model: model,
      baseUrl: baseUrl,
      endpointPath: _anthropicProfile.endpointPath,
      maxTokens: maxTokens,
      httpClient: httpClient,
      apiKeyHeader: _anthropicProfile.apiKeyHeader,
      apiKeyPrefix: _anthropicProfile.apiKeyPrefix,
      headers: headers,
      streamFormat: _anthropicProfile.streamFormat,
      requestBodyOverrides: requestBodyOverrides,
      systemPromptFragments: systemPromptFragments,
      debug: debug,
      debugVerbose: debugVerbose,
      surfaceOperations: surfaceOperations,
      clientDataModel: clientDataModel,
      maxRetries: maxRetries,
    );
  }

  /// Creates a [GenuiXTransport] pre-configured for a local Ollama server.
  ///
  /// Ollama exposes an OpenAI-compatible Chat Completions endpoint at
  /// `/v1/chat/completions` on `http://localhost:11434` by default, so this
  /// factory is a thin wrapper around [GenuiXTransport.openai] with sane
  /// local-development defaults. No API key is required by Ollama itself, but
  /// the OpenAI-compat layer expects a non-empty bearer token, so a placeholder
  /// (`ollama`) is sent unless [apiKey] is overridden.
  ///
  /// ```dart
  /// final transport = GenuiXTransport.ollama(
  ///   catalog: myCatalog,
  ///   // model: 'llama3.2',                    // optional — default
  ///   // baseUrl: 'http://localhost:11434',    // optional — default
  /// );
  /// ```
  ///
  /// Local models are often inconsistent at emitting strict A2UI JSON. If
  /// the server you point at supports OpenAI's `response_format`, set
  /// [enforceJsonMode] to `true` for tighter compliance — Ollama does honour
  /// `response_format: {type: "json_object"}` for models that support tools.
  factory GenuiXTransport.ollama({
    required Catalog catalog,
    String model = 'llama3.2',
    String baseUrl = 'http://localhost:11434',
    String apiKey = 'ollama',
    int maxTokens = 8192,
    http.Client? httpClient,
    Map<String, String> headers = const <String, String>{},
    Map<String, Object?> requestBodyOverrides = const <String, Object?>{},
    List<String> systemPromptFragments = const <String>[],
    bool debug = false,
    bool debugVerbose = false,
    SurfaceOperations? surfaceOperations,
    Map<String, Object?>? clientDataModel,
    int maxRetries = 0,
    bool enforceJsonMode = false,
  }) {
    return GenuiXTransport.openai(
      apiKey: apiKey,
      catalog: catalog,
      model: model,
      baseUrl: baseUrl,
      maxTokens: maxTokens,
      httpClient: httpClient,
      headers: headers,
      requestBodyOverrides: requestBodyOverrides,
      systemPromptFragments: systemPromptFragments,
      debug: debug,
      debugVerbose: debugVerbose,
      surfaceOperations: surfaceOperations,
      clientDataModel: clientDataModel,
      maxRetries: maxRetries,
      enforceJsonMode: enforceJsonMode,
    );
  }

  /// Creates a [GenuiXTransport] pre-configured for Google Gemini.
  ///
  /// Sets the correct `x-goog-api-key` header, the
  /// `/v1beta/models/{model}:streamGenerateContent` endpoint with `?alt=sse`,
  /// and the Gemini SSE stream format automatically.
  ///
  /// Works with `gemini-2.5-flash`, `gemini-2.5-pro`, and any Vertex AI or
  /// proxy endpoint that mirrors the Generative Language API surface.
  ///
  /// ```dart
  /// final transport = GenuiXTransport.gemini(
  ///   apiKey: 'your-google-api-key',
  ///   catalog: myCatalog,
  /// );
  /// ```
  ///
  /// Override [model] for a different Gemini variant:
  /// ```dart
  /// GenuiXTransport.gemini(
  ///   apiKey: 'your-key',
  ///   catalog: myCatalog,
  ///   model: 'gemini-2.5-pro',
  /// );
  /// ```
  factory GenuiXTransport.gemini({
    required String apiKey,
    required Catalog catalog,
    String model = 'gemini-2.5-flash',
    String baseUrl = 'https://generativelanguage.googleapis.com',
    int maxTokens = 8192,
    http.Client? httpClient,
    Map<String, String> headers = const <String, String>{},
    Map<String, Object?> requestBodyOverrides = const <String, Object?>{},
    List<String> systemPromptFragments = const <String>[],
    bool debug = false,
    bool debugVerbose = false,
    SurfaceOperations? surfaceOperations,
    Map<String, Object?>? clientDataModel,
    int maxRetries = 3,
  }) {
    return GenuiXTransport(
      apiKey: apiKey,
      catalog: catalog,
      model: model,
      baseUrl: baseUrl,
      endpointPath: _geminiProfile.endpointPath,
      maxTokens: maxTokens,
      httpClient: httpClient,
      apiKeyHeader: _geminiProfile.apiKeyHeader,
      apiKeyPrefix: _geminiProfile.apiKeyPrefix,
      headers: headers,
      streamFormat: _geminiProfile.streamFormat,
      requestBodyOverrides: requestBodyOverrides,
      systemPromptFragments: systemPromptFragments,
      debug: debug,
      debugVerbose: debugVerbose,
      surfaceOperations: surfaceOperations,
      clientDataModel: clientDataModel,
      maxRetries: maxRetries,
    );
  }

  final GenuiXConfig _config;
  final Catalog _catalog;
  final http.Client _httpClient;
  final A2uiTransportAdapter _adapter;
  final _anthropicSseParser = AnthropicSseParser();
  final _openaiSseParser = OpenAiSseParser();
  final _geminiSseParser = GeminiSseParser();

  /// Whether a request is currently in flight.
  ///
  /// Listen to this notifier to drive loading indicators in your UI.
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  // Conversation history in Claude's messages format
  final List<Map<String, dynamic>> _history = [];

  StreamSubscription<String>? _currentStream;

  // Cached system prompt (built once from catalog + user fragments)
  late final String _systemPrompt =
      (_config.surfaceOperations != null
              ? PromptBuilder.custom(
                  catalog: _catalog,
                  allowedOperations: _config.surfaceOperations!,
                  systemPromptFragments: _config.systemPromptFragments,
                  clientDataModel: _config.clientDataModel,
                )
              : PromptBuilder.chat(
                  catalog: _catalog,
                  systemPromptFragments: _config.systemPromptFragments,
                  clientDataModel: _config.clientDataModel,
                ))
          .systemPromptJoined();

  /// Stream of parsed A2UI messages from the AI response.
  ///
  /// Use this to react to structured UI commands such as `createSurface`
  /// or `updateComponents`. For raw text, use [incomingText].
  @override
  Stream<A2uiMessage> get incomingMessages => _adapter.incomingMessages;

  /// Stream of raw text chunks from the AI response.
  ///
  /// Emits each chunk as it arrives from the streaming API.
  /// A2UI JSON blocks are included in this stream before being parsed.
  @override
  Stream<String> get incomingText => _adapter.incomingText;

  /// Cancels any in-flight request.
  ///
  /// Safe to call even when no request is active. Resets [isLoading] to false.
  void cancel() {
    _currentStream?.cancel();
    _currentStream = null;
    isLoading.value = false;
  }

  /// Clears the conversation history.
  ///
  /// Call this to start a fresh conversation without creating a new transport.
  void clearHistory() => _history.clear();

  /// Sends a message to the AI backend and streams the response.
  ///
  /// Adds [message] to the conversation history, streams the response
  /// through [incomingText] and [incomingMessages], then appends the
  /// assistant reply to history for multi-turn context.
  ///
  /// Throws [GenuiXAuthError] on 401/403. Other API errors are surfaced
  /// as a text chunk rather than thrown, so the conversation continues.
  @override
  Future<void> sendRequest(ChatMessage message) async {
    final outbound = _toMessage(message);
    final content = outbound['content'] as String;
    if (content.isEmpty) {
      return;
    }

    _history.add(outbound);
    isLoading.value = true;

    try {
      final assistantText = await _sendWithRetry();
      if (assistantText.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': assistantText});
      }
    } finally {
      _currentStream = null;
      isLoading.value = false;
    }
  }

  /// Attempts the request, retrying on 429 with exponential backoff.
  Future<String> _sendWithRetry() async {
    int attempt = 0;
    while (true) {
      try {
        return await _collectStream();
      } on GenuiXRateLimitError catch (e) {
        if (attempt >= _config.maxRetries) rethrow;
        final delay = e.retryAfter != null
            ? Duration(seconds: e.retryAfter!)
            : Duration(seconds: 1 << attempt);
        if (_config.debug) {
          debugPrint(
            '[genui_x] rate limited — retry ${attempt + 1}/${_config.maxRetries} in ${delay.inSeconds}s',
          );
        }
        await Future.delayed(delay);
        attempt++;
      }
    }
  }

  /// Runs one HTTP attempt, collecting streamed chunks into a string.
  Future<String> _collectStream() async {
    final buffer = StringBuffer();
    final completer = Completer<void>();

    _currentStream = _streamLlm().listen(
      (chunk) {
        _adapter.addChunk(chunk);
        buffer.write(chunk);
      },
      onError: (Object e, StackTrace st) {
        if (e is GenuiXAuthError || e is GenuiXRateLimitError) {
          completer.completeError(e, st);
        } else if (e is GenuiXApiError) {
          final status = e.statusCode > 0 ? ' (HTTP ${e.statusCode})' : '';
          _adapter.addChunk(
            '\n\nSorry, I encountered an API error$status. Please try again.',
          );
          completer.complete();
        } else {
          _adapter.addChunk('\n\nSorry, I encountered an unexpected error.');
          completer.complete();
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
    _currentStream = null;
    return buffer.toString();
  }

  /// Streams text chunks from the configured AI backend.
  Stream<String> _streamLlm() async* {
    final uri = _buildUri();
    if (_config.debug) {
      debugPrint('[genui_x] POST $uri (model: ${_config.model})');
    }
    final payload = _buildPayload();
    final body = jsonEncode(payload);

    final headers = <String, String>{'content-type': 'application/json'};
    if (_config.streamFormat == GenuiXStreamFormat.anthropic) {
      headers['anthropic-version'] = _config.anthropicVersion;
    }
    if (_config.apiKeyHeader.isNotEmpty) {
      headers[_config.apiKeyHeader] =
          '${_config.apiKeyPrefix}${_config.apiKey}';
    }
    headers.addAll(_config.headers);

    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = body;

    final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request);
    } catch (e) {
      throw GenuiXApiError(0, 'Network error: $e');
    }

    if (_config.debug) {
      debugPrint('[genui_x] status: ${response.statusCode}');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      final body = await response.stream.bytesToString();
      if (_config.debug) debugPrint('[genui_x] auth error: $body');
      throw GenuiXAuthError(response.statusCode, body);
    }

    if (response.statusCode == 429) {
      final body = await response.stream.bytesToString();
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
      if (_config.debug) {
        debugPrint('[genui_x] rate limited — retry-after: $retryAfter');
      }
      throw GenuiXRateLimitError(retryAfter: retryAfter, body: body);
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      if (_config.debug) debugPrint('[genui_x] api error: $body');
      throw GenuiXApiError(response.statusCode, body);
    }

    _debugVerbose('parser=${_config.streamFormat.name}');
    final byteStream = (_config.debug && _config.debugVerbose)
        ? _tapRawSseLines(response.stream)
        : response.stream;

    switch (_config.streamFormat) {
      case GenuiXStreamFormat.openai:
        yield* _logParsedChunks(_openaiSseParser.parse(byteStream));
      case GenuiXStreamFormat.gemini:
        yield* _logParsedChunks(_geminiSseParser.parse(byteStream));
      case GenuiXStreamFormat.anthropic:
        yield* _logParsedChunks(_anthropicSseParser.parse(byteStream));
    }
  }

  Stream<List<int>> _tapRawSseLines(Stream<List<int>> source) async* {
    var pending = '';
    await for (final bytes in source) {
      final chunk = utf8.decode(bytes, allowMalformed: true);
      final combined = pending + chunk;
      final lines = combined.split('\n');
      pending = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trimRight();
        if (trimmed.isEmpty) {
          continue;
        }
        if (trimmed.startsWith('data:')) {
          _debugVerbose('sse ${_truncate(trimmed)}');
        }
      }

      yield bytes;
    }

    if (pending.trim().startsWith('data:')) {
      _debugVerbose('sse ${_truncate(pending.trim())}');
    }
  }

  Stream<String> _logParsedChunks(Stream<String> source) async* {
    await for (final chunk in source) {
      _debugVerbose('chunk len=${chunk.length} preview=${_truncate(chunk)}');
      yield chunk;
    }
  }

  void _debugVerbose(String message) {
    if (!_config.debug || !_config.debugVerbose) {
      return;
    }
    debugPrint('[genui_x][verbose] $message');
  }

  String _truncate(String value, {int max = 220}) {
    final normalized = value.replaceAll('\n', r'\n').replaceAll('\r', r'\r');
    if (normalized.length <= max) {
      return normalized;
    }
    return '${normalized.substring(0, max)}…';
  }

  /// Builds the request URI for the active stream format.
  ///
  /// Substitutes the `{model}` placeholder in [GenuiXConfig.endpointPath]
  /// (used by the Gemini endpoint where the model is part of the URL path).
  Uri _buildUri() {
    final path = _config.endpointPath.replaceAll(
      '{model}',
      Uri.encodeComponent(_config.model),
    );
    return Uri.parse(_config.baseUrl).resolve(path);
  }

  /// Builds the provider-specific request body.
  Map<String, Object?> _buildPayload() {
    switch (_config.streamFormat) {
      case GenuiXStreamFormat.gemini:
        final payload = <String, Object?>{
          'contents': _history.map(_toGeminiContent).toList(),
          'systemInstruction': {
            'parts': [
              {'text': _systemPrompt},
            ],
          },
          'generationConfig': {'maxOutputTokens': _config.maxTokens},
        };
        payload.addAll(_config.requestBodyOverrides);
        return payload;
      case GenuiXStreamFormat.openai:
        // OpenAI's Chat Completions API has no top-level `system` parameter —
        // the system prompt must be the first entry in `messages` with role
        // `system`, otherwise the model never receives the A2UI catalog
        // instructions. (Anthropic, by contrast, does take a top-level
        // `system`, which is why that case below keeps it.)
        final payload = <String, Object?>{
          'model': _config.model,
          'max_tokens': _config.maxTokens,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            ..._history,
          ],
          'stream': true,
        };
        if (_config.enforceJsonMode &&
            !_config.requestBodyOverrides.containsKey('response_format')) {
          payload['response_format'] = const {'type': 'json_object'};
        }
        payload.addAll(_config.requestBodyOverrides);
        return payload;
      case GenuiXStreamFormat.anthropic:
        final payload = <String, Object?>{
          'model': _config.model,
          'max_tokens': _config.maxTokens,
          'system': _systemPrompt,
          'messages': _history,
          'stream': true,
        };
        payload.addAll(_config.requestBodyOverrides);
        return payload;
    }
  }

  /// Converts a [ChatMessage] to the `{role, content}` shape used by both
  /// the Anthropic Messages API and OpenAI Chat Completions API.
  ///
  /// The Gemini path converts these entries to its own `contents` shape via
  /// [_toGeminiContent] at request time.
  Map<String, dynamic> _toMessage(ChatMessage message) {
    final role = message.role == ChatMessageRole.model ? 'assistant' : 'user';
    return {'role': role, 'content': message.text.trim()};
  }

  /// Converts a stored history entry (`{role, content}`) into Gemini's
  /// `contents` shape: `{role: 'user'|'model', parts: [{text: ...}]}`.
  Map<String, Object?> _toGeminiContent(Map<String, dynamic> entry) {
    final role = entry['role'] == 'assistant' ? 'model' : 'user';
    final content = entry['content'];
    final text = content is String ? content : content?.toString() ?? '';
    return {
      'role': role,
      'parts': [
        {'text': text},
      ],
    };
  }

  @override
  void dispose() {
    _currentStream?.cancel();
    _adapter.dispose();
    _httpClient.close();
    isLoading.dispose();
  }
}

/// Thrown when the API returns an authentication error (401/403).
class GenuiXAuthError implements Exception {
  /// Creates a [GenuiXAuthError].
  const GenuiXAuthError(this.statusCode, this.body);

  /// The HTTP status code.
  final int statusCode;

  /// The response body.
  final String body;

  @override
  String toString() =>
      'GenuiXAuthError($statusCode): Invalid API key or unauthorized. $body';
}

/// Thrown when the API returns a rate limit response (429).
///
/// Check [retryAfter] to know how many seconds to wait before retrying.
class GenuiXRateLimitError implements Exception {
  /// Creates a [GenuiXRateLimitError].
  const GenuiXRateLimitError({this.retryAfter, required this.body});

  /// Seconds to wait before retrying, parsed from the `Retry-After` header.
  ///
  /// `null` if the header was absent or could not be parsed.
  final int? retryAfter;

  /// The response body.
  final String body;

  @override
  String toString() =>
      'GenuiXRateLimitError: Rate limited.'
      '${retryAfter != null ? ' Retry after ${retryAfter}s.' : ''} $body';
}

/// Thrown when the API returns an error response.
class GenuiXApiError implements Exception {
  /// Creates a [GenuiXApiError].
  const GenuiXApiError(this.statusCode, this.message);

  /// The HTTP status code. 0 for network errors.
  final int statusCode;

  /// The error message.
  final String message;

  @override
  String toString() => 'GenuiXApiError($statusCode): $message';
}
