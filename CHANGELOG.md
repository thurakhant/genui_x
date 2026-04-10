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
