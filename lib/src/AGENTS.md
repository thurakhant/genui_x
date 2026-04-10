<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-06 -->

# lib/src/

## Purpose
Internal implementation of the `genui_x` package. Contains the HTTP transport layer, configuration model, and two SSE stream parsers (one for Anthropic's native format, one for the OpenAI-compatible format). Nothing here is exported directly; all public symbols flow through `lib/genui_x.dart`.

## Key Files

| File | Description |
|------|-------------|
| `claude_config.dart` | Immutable config value object — holds API key, model, base URL, endpoint path, token limit, auth header names, and stream format |
| `claude_transport.dart` | Main `Transport` implementation. Manages conversation history, builds the system prompt via `PromptBuilder`, streams chunks from Claude, and pipes them to `A2uiTransportAdapter` |
| `sse_parser.dart` | `ClaudeSseParser` — parses Anthropic Messages API SSE stream (`content_block_delta` / `text_delta` events) |
| `openai_sse_parser.dart` | `OpenAiSseParser` — parses OpenAI chat-completions SSE stream (`choices[0].delta.content`) |

## For AI Agents

### Working In This Directory

**License header required** on every file:
```dart
// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause
```

**`ClaudeTransport` is the integration point** — it owns the system prompt construction, HTTP request lifecycle, and history accumulation. Touch carefully; changes propagate to all consumers.

**Stream parsers** are stateless transformers. Both share the same `_parseLines` pattern (buffered UTF-8 line splitting). Keep them symmetric.

**Adding a new stream format:**
1. Create `<format>_sse_parser.dart` with the same `parse(Stream<List<int>>) → Stream<String>` API.
2. Add a variant to `ClaudeStreamFormat` in `claude_config.dart`.
3. Wire it in `ClaudeTransport._streamClaude()`.
4. Export nothing (parsers are internal).

### Testing Requirements
- Tests live in `../../test/`. Add `<file>_test.dart` for each parser.
- Use mock `StreamController<List<int>>` to feed SSE bytes.
- `ClaudeTransport` itself is not unit-tested (requires HTTP mock); integration-tested via the example app.

### Common Patterns
- `ClaudeConfig` is `const`-constructible — use it that way in tests and examples.
- `ClaudeTransport._history` is a `List<Map<String, dynamic>>` in Claude's messages format; each turn is appended after streaming completes.
- Error handling: `ClaudeAuthException` is reraised; `ClaudeApiException` appends an error message to the stream so the UI shows something.

## Dependencies

### Internal
- `claude_config.dart` ← used by `claude_transport.dart`
- `sse_parser.dart` and `openai_sse_parser.dart` ← used by `claude_transport.dart`

### External
- `genui` (^0.8.0) — `Transport`, `A2uiTransportAdapter`, `PromptBuilder`, `Catalog`, `ChatMessage`
- `http` (^1.2.0) — `http.Client`, `http.Request`, `http.StreamedResponse`

<!-- MANUAL: -->
