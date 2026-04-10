// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause

/// Supported streaming response formats.
enum GenuiXStreamFormat {
  /// Anthropic Messages API streaming format.
  anthropic,

  /// OpenAI-style chat completions streaming format.
  openai,
}

/// Configuration for the Claude AI adapter.
class GenuiXConfig {
  /// Creates a [GenuiXConfig].
  const GenuiXConfig({
    required this.apiKey,
    this.model = 'claude-haiku-4-5-20251001',
    this.baseUrl = 'https://api.anthropic.com',
    this.endpointPath = '/v1/messages',
    this.maxTokens = 8192,
    this.anthropicVersion = '2023-06-01',
    this.apiKeyHeader = 'x-api-key',
    this.apiKeyPrefix = '',
    this.headers = const <String, String>{},
    this.streamFormat = GenuiXStreamFormat.anthropic,
    this.requestBodyOverrides = const <String, Object?>{},
    this.systemPromptFragments = const <String>[],
    this.debug = false,
  });

  /// The Anthropic API key.
  final String apiKey;

  /// The Claude model to use.
  ///
  /// Defaults to `claude-haiku-4-5-20251001` for cost efficiency.
  /// Use `claude-sonnet-4-6` for higher quality responses.
  final String model;

  /// The base URL for the Anthropic API.
  ///
  /// Override this to route through your own proxy backend.
  /// Defaults to `https://api.anthropic.com`.
  final String baseUrl;

  /// The API endpoint path.
  ///
  /// Defaults to `/v1/messages` for Anthropic-compatible backends.
  final String endpointPath;

  /// The maximum number of tokens to generate.
  final int maxTokens;

  /// The Anthropic API version header value.
  final String anthropicVersion;

  /// The header name used for the API key.
  ///
  /// Defaults to `x-api-key`.
  final String apiKeyHeader;

  /// Optional prefix for the API key header value.
  ///
  /// Use `Bearer ` for Authorization-style headers.
  final String apiKeyPrefix;

  /// Additional headers to send with each request.
  ///
  /// Values here override default headers when keys match.
  final Map<String, String> headers;

  /// The streaming response format to parse.
  final GenuiXStreamFormat streamFormat;

  /// Optional request body overrides for provider-specific features.
  ///
  /// Values here override default request fields when keys match.
  final Map<String, Object?> requestBodyOverrides;

  /// Additional fragments to inject into the system prompt.
  ///
  /// These are passed directly to [PromptBuilder.chat] and prepended to the
  /// generated catalog schema. Use them to give Claude a persona, restrict its
  /// domain, inject the current date, or add any other instructions.
  ///
  /// Example:
  /// ```dart
  /// systemPromptFragments: [
  ///   'You are Aria, a helpful travel assistant.',
  ///   'Always respond in English.',
  ///   PromptFragments.currentDate(),
  /// ]
  /// ```
  final List<String> systemPromptFragments;

  /// Whether to print request/response debug info to the console.
  ///
  /// Logs the request URL, model, status code, and any errors via [debugPrint].
  /// Useful for debugging proxy configuration issues.
  final bool debug;
}
