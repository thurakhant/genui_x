# AGENTS.md — genui_x

Multi-provider `Transport` adapter (Anthropic, OpenAI, Gemini, Ollama) for Google's [genui](https://pub.dev/packages/genui) framework. Written in Dart/Flutter.

## Commands

```bash
flutter pub get                                # install dependencies
flutter analyze                                # lint (CI uses --fatal-infos)
flutter test                                   # all tests
flutter test test/<file>_test.dart             # single test file
flutter test --name "<pattern>"                # single test by name
dart format --output=none --set-exit-if-changed .  # formatting check (CI enforces)
```

**Examples** (never hardcode keys — use `--dart-define`):
```bash
cd example && flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...
cd example && flutter run -t lib/gemini_main.dart --dart-define=GEMINI_API_KEY=...
cd example && flutter run -t lib/ollama_main.dart   # no API key
```

## Multi-package

`example/` is a standalone Flutter app with its own `pubspec.yaml`. Run commands from within it:
```bash
cd example && flutter pub get && flutter analyze && flutter test
```

## Critical A2UI protocol rules

1. **`createSurface` before `updateComponents`** — `SurfaceController` buffers components for unknown surfaces; if `createSurface` never arrives, nothing renders. `PromptBuilder.chat` already instructs this; never override it.
2. **`"id"` required on every component** — `Component.fromJson` hard-casts `json['id'] as String`. Missing `id` → crash.
3. **One component must have `"id": "root"`** — without it nothing renders.
4. **Custom catalog widgets use `"data"` wrapper** — props are nested under `"data"` key, accessed via `ctx.data` in `widgetBuilder`.

## License header

Every `.dart` source file must include:
```dart
// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause
```

## Architecture

- **`GenuiXTransport`** is the single integration point: `anthropic()`, `openai()`, `gemini()`, `ollama()` factory constructors. Owns system prompt, HTTP lifecycle, history, and error handling.
- **Adding a new stream format** touches 5 files: `<vendor>_sse_parser.dart`, `GenuiXStreamFormat` variant (in `genui_x_config.dart`), parser field + `switch` in `_streamLlm()`, vendor branch in `_buildUri()` / `_buildPayload()` and optionally a new factory. (See `lib/src/AGENTS.md`)
- **Stream parsers** (`AnthropicSseParser`, `OpenAiSseParser`, `GeminiSseParser`) are stateless, share the same `_parseLines` pattern. Keep them symmetric.
- **Gemini**: `{model}` in `endpointPath` is substituted at request time.
- **Ollama**: `maxRetries: 0` by default (local servers don't rate-limit); placeholder bearer token `"ollama"` sent for OpenAI-compat layer; `enforceJsonMode` recommended for stricter A2UI.

## Error handling

- `GenuiXAuthError` (401/403) and `GenuiXRateLimitError` (429) are **rethrown** to the caller.
- `GenuiXApiError` and unexpected errors are **surfaced as a text chunk** so the UI shows a message instead of crashing.
- 429 auto-retry with exponential backoff (configurable via `maxRetries`, default `3`).

## Testing

- Transport tests use `_MockHttpClient` / `_CapturingHttpClient` helpers in `test/genui_x_transport_test.dart`. Keep new HTTP tests in that file.
- SSE parser tests: `Stream<List<int>>` of `utf8.encode('data: {...}\n\n')` → `await stream.toList()`.
- `GenuiXConfig` is `const`-constructible — use it that way in tests.

## Release

Follow `doc/RELEASE_CHECKLIST.md`: version bump → CHANGELOG → `flutter analyze` → `flutter test` → `flutter pub publish --dry-run` → `flutter pub publish`.

## Nested AGENTS.md files

| File | Covers |
|------|--------|
| `lib/AGENTS.md` | Barrel export rules |
| `lib/src/AGENTS.md` | Implementation patterns, adding a format |
| `test/AGENTS.md` | Test conventions |
| `example/AGENTS.md` | Example app setup |
| `example/lib/AGENTS.md` | A2UI protocol details |
| `doc/AGENTS.md` | Release checklist reference |
