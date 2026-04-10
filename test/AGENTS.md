<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-06 -->

# test/

## Purpose
Unit tests for the `genui_x` library. Covers `ClaudeConfig` defaults and custom construction, `ClaudeApiException`/`ClaudeAuthException` stringification, and the two SSE parsers. Run with `flutter test` from the repo root.

## Key Files

| File | Description |
|------|-------------|
| `genui_x_test.dart` | Tests for `ClaudeConfig` (defaults, custom values, OpenAI headers) and exception `toString()` |
| `sse_parser_test.dart` | Tests for `ClaudeSseParser` — feeds raw SSE bytes and asserts extracted text deltas |
| `openai_sse_parser_test.dart` | Tests for `OpenAiSseParser` — feeds OpenAI-format SSE bytes and asserts extracted content |

## For AI Agents

### Working In This Directory
- Use `flutter_test` imports (`package:flutter_test/flutter_test.dart`).
- Group related tests with `group()`. Name tests as "does X when Y" or "has correct Z".
- For SSE parser tests, create a `StreamController<List<int>>` and send `utf8.encode('data: {...}\n\n')` payloads, then `await` the stream.
- Do **not** mock `ClaudeTransport` HTTP calls here — that is out of scope for unit tests. Integration behaviour is exercised by the example app.

### Testing Requirements
```bash
flutter test                                       # all tests
flutter test test/genui_x_test.dart           # single file
flutter test --name "has correct defaults"         # single test by name
```

### Common Patterns
```dart
group('ClaudeConfig', () {
  test('has correct defaults', () {
    const config = ClaudeConfig(apiKey: 'test-key');
    expect(config.model, 'claude-haiku-4-5-20251001');
  });
});
```

## Dependencies

### Internal
- `lib/src/claude_config.dart`
- `lib/src/sse_parser.dart`
- `lib/src/openai_sse_parser.dart`

### External
- `flutter_test` — test runner and matchers

<!-- MANUAL: -->
