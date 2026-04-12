## 0.0.9

* Add `surfaceOperations` (`SurfaceOperations?`) to `GenuiXTransport` and `GenuiXConfig` — use `PromptBuilder.custom()` to control which A2UI operations (create, update, delete) the AI may perform. Defaults to `PromptBuilder.chat()` (create-only) when not set.
* Add `clientDataModel` (`Map<String, Object?>?`) to `GenuiXTransport` and `GenuiXConfig` — inject app-state context (user profile, active session, domain data) into the system prompt.
* Add transport-level tests for `surfaceOperations` and `clientDataModel` — verify prompt content changes with different configurations.

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
