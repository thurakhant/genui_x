<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-19 -->

# lib/src/

## Purpose
Internal implementation of the `genui_x` package. Contains the HTTP transport layer, configuration model, and three SSE stream parsers (Anthropic Messages API, OpenAI Chat Completions, and Google Gemini `streamGenerateContent`). Nothing here is exported directly; all public symbols flow through `lib/genui_x.dart`.

## Key Files

| File | Description |
|------|-------------|
| `genui_x_config.dart` | Immutable `GenuiXConfig` value object — holds API key, model, base URL, endpoint path, token limit, auth header names, stream format, retry policy, JSON-mode toggle, surface operations, and client data model |
| `genui_x_transport.dart` | Main `Transport` implementation (`GenuiXTransport`). Manages conversation history, builds the system prompt via `PromptBuilder`, builds provider-specific request URI/payload via `_buildUri()` / `_buildPayload()`, streams chunks from the configured backend, and pipes them to `A2uiTransportAdapter`. Exposes `.openai()`, `.anthropic()`, `.gemini()`, and `.ollama()` factory constructors (the last is a thin wrapper around `.openai()` for local Ollama servers) |
| `anthropic_sse_parser.dart` | `AnthropicSseParser` — parses Anthropic Messages API SSE stream (`content_block_delta` / `text_delta` events) |
| `openai_sse_parser.dart` | `OpenAiSseParser` — parses OpenAI chat-completions SSE stream (`choices[0].delta.content`) |
| `gemini_sse_parser.dart` | `GeminiSseParser` — parses Gemini `streamGenerateContent?alt=sse` stream (`candidates[*].content.parts[*].text`) |

## For AI Agents

### Working In This Directory

**License header required** on every file:
```dart
// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause
```

**`GenuiXTransport` is the integration point** — it owns the system prompt construction, HTTP request lifecycle, and history accumulation. Touch carefully; changes propagate to all consumers.

**Stream parsers** are stateless transformers. All three share the same `_parseLines` pattern (buffered UTF-8 line splitting). Keep them symmetric.

**Adding a new stream format:**
1. Create `<vendor>_sse_parser.dart` with the same `parse(Stream<List<int>>) → Stream<String>` API.
2. Add a variant to `GenuiXStreamFormat` in `genui_x_config.dart`.
3. Add a parser field on `GenuiXTransport` and wire it into the `switch` in `_streamLlm()`.
4. Add a vendor branch to `_buildUri()` (if the URI shape differs) and `_buildPayload()` (if the body shape differs).
5. Optionally add a `GenuiXTransport.<vendor>()` factory mirroring `.openai()` / `.anthropic()` / `.gemini()` / `.ollama()`.
6. Export nothing (parsers are internal).

### Testing Requirements
- Tests live in `../../test/`. Add `<file>_test.dart` for each parser.
- Use a `Stream<List<int>>` of `utf8.encode('data: {...}\n\n')` payloads to exercise parsers directly.
- `GenuiXTransport` is unit-tested via `_MockHttpClient` and `_CapturingHttpClient` helpers in `test/genui_x_transport_test.dart`.

### Common Patterns
- `GenuiXConfig` is `const`-constructible — use it that way in tests and examples.
- `GenuiXTransport._history` is a `List<Map<String, dynamic>>` in the `{role, content}` shape (Anthropic + OpenAI compatible). The Gemini path converts each entry to `{role, parts: [{text}]}` at request time via `_toGeminiContent()`.
- Error handling: `GenuiXAuthError` and `GenuiXRateLimitError` are rethrown to the caller; `GenuiXApiError` and unexpected errors are surfaced as a text chunk so the UI shows something instead of crashing.

## Dependencies

### Internal
- `genui_x_config.dart` ← used by `genui_x_transport.dart`
- `anthropic_sse_parser.dart`, `openai_sse_parser.dart`, and `gemini_sse_parser.dart` ← used by `genui_x_transport.dart`

### External
- `genui` (^0.8.0) — `Transport`, `A2uiTransportAdapter`, `PromptBuilder`, `Catalog`, `ChatMessage`, `SurfaceOperations`
- `http` (^1.2.0) — `http.Client`, `http.Request`, `http.StreamedResponse`

<!-- MANUAL: -->
