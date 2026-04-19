<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-19 -->

# test/

## Purpose
Unit tests for the `genui_x` library. Covers `GenuiXConfig` defaults and custom construction, `GenuiXAuthError` / `GenuiXApiError` / `GenuiXRateLimitError` stringification, the three SSE parsers, and `GenuiXTransport` HTTP behaviour (auth errors, rate-limit retry, streaming, factory defaults, surface operations, client data model, JSON-mode injection, debug flag). Run with `flutter test` from the repo root.

## Key Files

| File | Description |
|------|-------------|
| `genui_x_test.dart` | Tests for `GenuiXConfig` defaults, custom values, surface operations, client data model, JSON-mode toggle, and re-exports |
| `genui_x_transport_test.dart` | HTTP-level transport tests using `_MockHttpClient` and `_CapturingHttpClient`. Covers `.openai()`, `.anthropic()`, `.gemini()` factories, retry-on-429, `enforceJsonMode`, surface operations, and the debug flag |
| `anthropic_sse_parser_test.dart` | Tests for `AnthropicSseParser` — feeds raw SSE bytes and asserts extracted `text_delta` content |
| `openai_sse_parser_test.dart` | Tests for `OpenAiSseParser` — feeds OpenAI-format SSE bytes and asserts extracted `delta.content` |
| `gemini_sse_parser_test.dart` | Tests for `GeminiSseParser` — feeds Gemini-format SSE bytes and asserts extracted `parts[*].text` |

## For AI Agents

### Working In This Directory
- Use `flutter_test` imports (`package:flutter_test/flutter_test.dart`).
- Group related tests with `group()`. Name tests as "does X when Y" or "has correct Z".
- For SSE parser tests, build a `Stream<List<int>>` of `utf8.encode('data: {...}\n\n')` payloads and `await stream.toList()`.
- Transport tests use the `_MockHttpClient` / `_CapturingHttpClient` helpers in `genui_x_transport_test.dart`. Keep new HTTP-level tests in that same file to share the helpers.

### Testing Requirements
```bash
flutter test                                        # all tests
flutter test test/genui_x_test.dart                 # single file
flutter test --name "has correct defaults"          # single test by name
```

### Common Patterns
```dart
group('GenuiXConfig', () {
  test('has correct defaults', () {
    const config = GenuiXConfig(apiKey: 'test-key');
    expect(config.model, 'claude-haiku-4-5-20251001');
  });
});
```

## Dependencies

### Internal
- `lib/src/genui_x_config.dart`
- `lib/src/anthropic_sse_parser.dart`
- `lib/src/openai_sse_parser.dart`
- `lib/src/gemini_sse_parser.dart`
- `lib/src/genui_x_transport.dart`

### External
- `flutter_test` — test runner and matchers
- `http` — request/response types used to build mock clients

<!-- MANUAL: -->
