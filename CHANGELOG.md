## 0.0.14

* **Fix:** OpenAI-compatible backends (OpenAI, OpenRouter, LiteLLM, Ollama)
  now receive the system prompt as a `system`-role message instead of a
  top-level `system` field, which the Chat Completions API ignores. Before
  this fix the A2UI catalog and surface-operation instructions never reached
  the model on those providers, so generative UI output was unreliable.
  Anthropic (top-level `system`) and Gemini (`systemInstruction`) were
  already correct and are unchanged.
* Add a provider wire-format conformance test suite
  (`test/provider_conformance_test.dart`) that decodes the request body and
  asserts each provider's exact payload shape, locking the contract above so
  the system prompt can't silently move to the wrong field again.
* Internal: centralise each provider's wire identity (endpoint path, auth
  header, key prefix, stream format) into a single `_ProviderProfile` table
  instead of hand-copying those constants into every factory. No behavioural
  change — purely makes adding or maintaining a backend safer.
* Add `debugVerbose` to `GenuiXConfig` and all `GenuiXTransport` constructors
  and factories. When combined with `debug: true`, it logs parser selection,
  raw SSE `data:` lines, and safe-truncated chunk previews to help diagnose
  proxy stream issues.

## 0.0.13

* Upgrade dependency to `genui: ^0.9.2` in both the package and example app.
* Upgrade transport dependency to `http: ^1.6.0`.
* Improve SSE parser compatibility for OpenAI-compatible proxies by accepting
  both `data: {...}` and `data:{...}` line formats.
* Harden transport error handling by skipping empty outbound messages and
  surfacing API errors as user-safe text chunks.
* Harden travel example rendering against model output variance:
  register both `travel-catalog` and legacy `travel` IDs, accept flat or
  nested (`data`) props, and add safe fallbacks for missing fields.
* Smooth travel example waiting UX by keeping progress visible until a real
  UI/text result is rendered.
* Add troubleshooting notes in README for 200-with-delayed-UI behavior,
  proxy SSE formatting differences, catalog ID mismatches, and prop shape
  compatibility.

## 0.0.12

* Add `GenuiXTransport.ollama()` factory — thin wrapper around
  `GenuiXTransport.openai()` configured for Ollama's OpenAI-compatible
  endpoint. Defaults to `http://localhost:11434` and `llama3.2`. No API key
  required (a placeholder bearer token is sent so the OpenAI-compat layer
  accepts the request). Disables retries by default (`maxRetries: 0`) since
  local servers don't rate-limit.
* Add `example/lib/ollama_main.dart` — runnable local-Ollama chat demo
  with `enforceJsonMode: true` for stricter A2UI compliance from local
  models. Supports `OLLAMA_BASE_URL` and `OLLAMA_MODEL` `--dart-define`s.
* README overhaul for discoverability — new tagline, provider matrix table
  (Anthropic / OpenAI / Gemini / Ollama / custom proxy at a glance), CI
  badge, demo-GIF placeholder block, Ollama backend section, and Ollama
  example run instructions.
* `pubspec.yaml` — add `homepage` and `documentation` URLs, refresh
  `topics` to `[genui, llm, claude, gemini, openai]` (drop redundant
  `flutter` and broad `ai`), and stage a commented-out `screenshots:`
  block for the demo GIF.
* No public API removals or signature changes; existing call sites for
  `.anthropic()`, `.openai()`, and `.gemini()` are byte-identical.

## 0.0.11

* Add `GenuiXTransport.gemini()` factory — pre-configures Google's Generative
  Language API endpoint (`/v1beta/models/{model}:streamGenerateContent?alt=sse`),
  the `x-goog-api-key` header, and the Gemini SSE format. Works with
  `gemini-2.5-flash`, `gemini-2.5-pro`, and Vertex AI / proxy endpoints that
  mirror the Generative Language API surface.
* Add `GenuiXStreamFormat.gemini` and a Gemini SSE parser (`GeminiSseParser`)
  that extracts text from `candidates[*].content.parts[*].text`.
* Add `enforceJsonMode` option on `GenuiXTransport.openai()` and
  `GenuiXConfig` — when `true`, injects `response_format: {"type": "json_object"}`
  for tighter A2UI compliance on OpenAI and OpenAI-compatible backends.
  Respects user-supplied `requestBodyOverrides['response_format']`.
* Add `example/lib/gemini_main.dart` — runnable Gemini chat demo.
* Add GitHub Actions CI (`.github/workflows/ci.yml`) running
  `flutter analyze` and `flutter test` on push and pull request.
* Refactor request building: extract `_buildUri()` and `_buildPayload()`
  in `GenuiXTransport` to keep provider-specific logic isolated. The
  Anthropic and OpenAI request shapes are unchanged; this is a non-breaking
  internal cleanup that supports the new Gemini path.
* Internal rename pass — no public API change. `lib/src/claude_transport.dart`
  → `genui_x_transport.dart`, `lib/src/claude_config.dart` →
  `genui_x_config.dart`, `lib/src/sse_parser.dart` →
  `anthropic_sse_parser.dart` (class `ClaudeSseParser` → `AnthropicSseParser`).
  Internal `_streamClaude()` / `_toClaudeMessage()` / `_sseParser` are now
  `_streamLlm()` / `_toMessage()` / `_anthropicSseParser`. Test files renamed
  to match. AGENTS.md docs updated. The public surface
  (`GenuiXTransport`, `GenuiXConfig`, `GenuiXStreamFormat`, errors) is
  unchanged.

## 0.0.10

* Add `GenuiXTransport.anthropic()` factory constructor — mirrors `.openai()` with explicit Anthropic defaults (`x-api-key` header, `/v1/messages` endpoint, Anthropic SSE format).
* Add automatic retry on 429 responses with exponential backoff — configurable via `maxRetries` (default `3`). Respects `Retry-After` header when present.

## 0.0.9

* Add `GenuiXTransport.openai()` factory constructor — pre-configures `Authorization: Bearer` header, `/v1/chat/completions` endpoint, and OpenAI SSE format. Works with OpenAI, OpenRouter, LiteLLM, and any OpenAI-compatible proxy.
* Add `surfaceOperations` (`SurfaceOperations?`) to `GenuiXTransport` and `GenuiXConfig` — use `PromptBuilder.custom()` to control which A2UI operations (create, update, delete) the AI may perform. Defaults to `PromptBuilder.chat()` (create-only) when not set.
* Add `clientDataModel` (`Map<String, Object?>?`) to `GenuiXTransport` and `GenuiXConfig` — inject app-state context (user profile, active session, domain data) into the system prompt.
* Add `GenuiXRateLimitError` — thrown on 429 responses. Exposes `retryAfter: int?` parsed from the `Retry-After` header.
* Re-export `PromptFragments` and `SurfaceOperations` from `genui_x.dart` — users no longer need a separate `import 'package:genui/genui.dart'` to configure the transport.
* Remove Flutter upper-bound constraint (`<4.0.0`) per pub.dev deprecation guidance.
* Overhaul README — add genui/genui_x architecture diagram, backend examples, `surfaceOperations` and `clientDataModel` usage.

## 0.0.8

* Improve doc comments on all public APIs — `GenuiXTransport`, `GenuiXConfig`, `GenuiXStreamFormat`, `GenuiXAuthError`, `GenuiXApiError`.
* Add `example/lib/proxy_main.dart` — runnable example for OpenAI-compatible backends (LiteLLM, OpenRouter, custom proxy).
* Update `example/README.md` to document all three entry points.

## 0.0.7

* Rename `ClaudeTransport` → `GenuiXTransport`, `ClaudeConfig` → `GenuiXConfig`, `ClaudeStreamFormat` → `GenuiXStreamFormat` — names no longer imply Claude-only.
* Rename `ClaudeAuthException` → `GenuiXAuthError` and `ClaudeApiException` → `GenuiXApiError` for provider-neutral naming.
* Add `cancel()` to `ClaudeTransport` — abort an in-flight request and reset `isLoading`.
* Add `clearHistory()` to `ClaudeTransport` — reset conversation history without creating a new transport.
* Add `debug: bool` to `ClaudeConfig` and `ClaudeTransport` — prints request URL, model, status code, and errors via `debugPrint`.
* Add transport-level tests: error handling, streaming (Anthropic + OpenAI), `isLoading` state, `cancel()`, `clearHistory()`.

## 0.0.5

* Add `systemPromptFragments` to `ClaudeTransport` and `ClaudeConfig` — inject persona, domain restrictions, or date context into the system prompt.
* Add `isLoading` (`ValueNotifier<bool>`) to `ClaudeTransport` — drive loading indicators without manually tracking conversation state.
* Tighten SDK constraint to `>=3.10.0 <4.0.0` and Flutter to `>=3.35.7 <4.0.0` to match genui 0.8.0 requirements.

## 0.0.4

* Rename main library export to `genui_x.dart` — import with `package:genui_x/genui_x.dart`.
* Add `requestBodyOverrides` to `ClaudeTransport` and `ClaudeConfig` for provider-specific JSON-mode support.
* Add travel demo example app and minimal example app.
* Fix `baseUrl` resolution in example apps.

## 0.0.3

* Add OpenAI-style stream format support and parser.
* Allow selecting stream format via ClaudeConfig.
* Document OpenAI-style proxy configuration.
* Add request body overrides for JSON-mode responses.

## 0.0.2

* Add configurable endpoint path and request headers for proxies/LiteLLM.
* Document proxy usage and authorization header support.

## 0.0.1

* Initial release of the Claude transport adapter for genui.
* Includes ClaudeTransport, configuration, and SSE parsing.
* Adds a Flutter example app and basic tests.
