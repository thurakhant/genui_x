// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;

import 'claude_config.dart';
import 'openai_sse_parser.dart';
import 'sse_parser.dart';

/// A [Transport] implementation that uses Anthropic's Claude API.
///
/// Connects the genui framework to Claude by generating A2UI JSON messages
/// in markdown code blocks, which the [A2uiParserTransformer] automatically
/// extracts and routes to the [SurfaceController].
///
/// ## Usage
///
/// ```dart
/// final transport = GenuiXTransport(
///   apiKey: 'your-api-key',
///   catalog: myCatalog,
/// );
///
/// final controller = SurfaceController(catalogs: [myCatalog]);
/// final conversation = Conversation(
///   controller: controller,
///   transport: transport,
/// );
/// ```
class GenuiXTransport implements Transport {
  /// Creates a [GenuiXTransport].
  ///
  /// [apiKey] is required. All other parameters are optional.
  /// [catalog] defines the UI components the AI can generate.
  /// [model] defaults to `claude-haiku-4-5-20251001` for cost efficiency.
  /// [baseUrl] can be overridden to route through your own proxy.
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
  })  : _config = GenuiXConfig(
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
        ),
        _catalog = catalog,
        _httpClient = httpClient ?? http.Client(),
        _adapter = A2uiTransportAdapter();

  final GenuiXConfig _config;
  final Catalog _catalog;
  final http.Client _httpClient;
  final A2uiTransportAdapter _adapter;
  final _sseParser = ClaudeSseParser();
  final _openaiSseParser = OpenAiSseParser();

  /// Whether a request is currently in flight.
  ///
  /// Listen to this notifier to drive loading indicators in your UI.
  final ValueNotifier<bool> isLoading = ValueNotifier(false);

  // Conversation history in Claude's messages format
  final List<Map<String, dynamic>> _history = [];

  StreamSubscription<String>? _currentStream;

  // Cached system prompt (built once from catalog + user fragments)
  late final String _systemPrompt = PromptBuilder.chat(
    catalog: _catalog,
    systemPromptFragments: _config.systemPromptFragments,
  ).systemPromptJoined();

  @override
  Stream<A2uiMessage> get incomingMessages => _adapter.incomingMessages;

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

  @override
  Future<void> sendRequest(ChatMessage message) async {
    _history.add(_toClaudeMessage(message));
    isLoading.value = true;

    final buffer = StringBuffer();
    final completer = Completer<void>();

    _currentStream = _streamClaude().listen(
      (chunk) {
        _adapter.addChunk(chunk);
        buffer.write(chunk);
      },
      onError: (Object e, StackTrace st) {
        if (e is GenuiXAuthError) {
          completer.completeError(e, st);
        } else if (e is GenuiXApiError) {
          _adapter.addChunk('\n\nSorry, I encountered an error: ${e.message}');
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

    try {
      await completer.future;
    } finally {
      _currentStream = null;
      isLoading.value = false;
      final assistantText = buffer.toString();
      if (assistantText.isNotEmpty) {
        _history.add({'role': 'assistant', 'content': assistantText});
      }
    }
  }

  /// Streams text chunks from the Claude Messages API.
  Stream<String> _streamClaude() async* {
    final uri = Uri.parse(_config.baseUrl).resolve(_config.endpointPath);
    if (_config.debug) {
      debugPrint('[genui_x] POST $uri (model: ${_config.model})');
    }
    final payload = <String, Object?>{
      'model': _config.model,
      'max_tokens': _config.maxTokens,
      'system': _systemPrompt,
      'messages': _history,
      'stream': true,
    };
    payload.addAll(_config.requestBodyOverrides);
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

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      if (_config.debug) debugPrint('[genui_x] api error: $body');
      throw GenuiXApiError(response.statusCode, body);
    }

    if (_config.streamFormat == GenuiXStreamFormat.openai) {
      yield* _openaiSseParser.parse(response.stream);
    } else {
      yield* _sseParser.parse(response.stream);
    }
  }

  /// Converts a [ChatMessage] to Claude's messages format.
  Map<String, dynamic> _toClaudeMessage(ChatMessage message) {
    final role = message.role == ChatMessageRole.model ? 'assistant' : 'user';
    return {'role': role, 'content': message.text};
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
