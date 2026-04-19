# AGENTS.md - Development Guide for genui_x

This document provides guidelines for agentic coding agents working on this codebase.

## Project Overview

`genui_x` is a Dart/Flutter package that provides a `ClaudeTransport` adapter connecting Anthropic's Claude API to Google's genui (Generative UI) framework. The package enables dynamic UI generation using Claude's AI capabilities.

## Build, Lint, and Test Commands

### Prerequisites
```bash
flutter pub get
```

### Running Tests

**Run all tests:**
```bash
flutter test
```

**Run a single test file:**
```bash
flutter test test/genui_x_test.dart
```

**Run a single test (by name):**
```bash
flutter test --name "has correct defaults"
```

### Linting

The project uses `flutter_lints` (see `analysis_options.yaml`).

```bash
flutter analyze
```

### Running the Example

```bash
cd example
flutter run --dart-define=CLAUDE_API_KEY=sk-ant-your-key-here
```

---

## Release Workflow

Follow `docs/RELEASE_CHECKLIST.md` for every versioned release.

---

## Code Style Guidelines

### General Conventions

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart)
- Use `package:flutter_lints/flutter.yaml` (already configured in `analysis_options.yaml`)
- Keep lines under 80 characters when practical

### License Headers

Every source file must include the BSD-3-Clause license header:
```dart
// Copyright 2025 genui_x contributors.
// SPDX-License-Identifier: BSD-3-Clause
```

### Imports

- Use package imports for external packages: `import 'package:genui/genui.dart';`
- Use relative imports for internal files: `import 'genui_x_config.dart';`
- Group imports in this order: dart:, external packages, internal packages
- Use `as` prefix for package aliases when needed

```dart
import 'dart:async';
import 'dart:convert';

import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;

import 'anthropic_sse_parser.dart';
import 'genui_x_config.dart';
```

### Naming Conventions

- **Classes**: `PascalCase` (e.g., `GenuiXTransport`, `GenuiXApiError`)
- **Constants**: `camelCase` with `k` prefix for const objects (e.g., `kDefaultModel`)
- **Variables/Methods**: `camelCase` (e.g., `apiKey`, `sendRequest`)
- **Files**: `snake_case`. Public/package-namespaced files use the `genui_x_` prefix (e.g., `genui_x_transport.dart`, `genui_x_config.dart`); per-vendor parsers use the vendor name (e.g., `anthropic_sse_parser.dart`, `openai_sse_parser.dart`, `gemini_sse_parser.dart`)
- **Private members**: prefix with `_` (e.g., `_config`, `_history`)

### Type Annotations

- Use explicit return types on public methods
- Prefer `const` constructors where possible
- Use typed `List`, `Map` instead of raw generics where it improves clarity

```dart
// Good
class GenuiXConfig {
  const GenuiXConfig({
    required this.apiKey,
    this.model = 'claude-haiku-4-5-20251001',
  });

  final String apiKey;
  final String model;
}
```

### Documentation

- Document public classes and constructors with doc comments (`///`)
- Document parameters in constructor signatures when not obvious
- Keep documentation concise but complete

```dart
/// A [Transport] implementation that streams A2UI JSON from a configurable
/// LLM backend (Anthropic, OpenAI-compatible, or Gemini).
class GenuiXTransport implements Transport {
  /// Creates a [GenuiXTransport].
  ///
  /// [apiKey] is required. All other parameters are optional.
  /// [catalog] defines the UI components the AI can generate.
  GenuiXTransport({
    required String apiKey,
    required Catalog catalog,
  });
}
```

### Error Handling

- Use custom exception classes for domain-specific errors
- Implement `toString()` for all exception types
- Prefer specific exception types over generic `Exception`

```dart
class GenuiXApiError implements Exception {
  const GenuiXApiError(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'GenuiXApiError($statusCode): $message';
}
```

### Null Safety

- Avoid `!` operator; use proper null handling instead
- Use late initialization only when initialization is guaranteed before use
- Prefer nullable types with proper null checks over late initialization

### Testing

- Use `flutter_test` package
- Group related tests with `group()`
- Use descriptive test names that explain expected behavior

```dart
group('GenuiXConfig', () {
  test('has correct defaults', () {
    const config = GenuiXConfig(apiKey: 'test-key');
    expect(config.model, 'claude-haiku-4-5-20251001');
  });
});
```

### Async/Await

- Prefer `async`/`await` over raw `Future` chains
- Handle errors with `try`/`catch` blocks
- Use `rethrow` for errors that need to propagate

```dart
try {
  await for (final chunk in _streamLlm()) {
    _adapter.addChunk(chunk);
  }
} on GenuiXAuthError {
  rethrow;
} on GenuiXApiError catch (e) {
  _adapter.addChunk('\n\nSorry, I encountered an error: ${e.message}');
}
```

---

## A2UI Protocol — Critical Rules

The genui framework (`package:genui` ^0.8.0) uses the **A2UI v0.9 protocol** for AI→UI communication:

1. **`createSurface` before `updateComponents`**: The model must always emit `createSurface` (with `surfaceId` + `catalogId`) before `updateComponents`. `SurfaceController` buffers `updateComponents` for unknown surfaces — if `createSurface` never arrives, nothing renders. `PromptBuilder.chat` already instructs this; never override it in user messages.

2. **`"id"` is required in every component**: `Component.fromJson` hard-casts `json['id'] as String`. A missing `id` throws `type 'Null' is not a subtype of type 'String'`. Always include `"id"` in JSON examples in system prompt fragments.

3. **One component must have `"id": "root"`**: Without a root component, nothing renders. Include `"id": "root"` in catalog examples.

4. **Custom catalog widgets use a `"data"` wrapper**: Component props for custom `CatalogItem`s are nested under a `"data"` key and accessed via `ctx.data` in `widgetBuilder`.

Example well-formed `updateComponents`:
```json
{
  "version": "v0.9",
  "updateComponents": {
    "surfaceId": "<id from createSurface>",
    "components": [
      {
        "id": "root",
        "component": "MyWidget",
        "data": { "field": "value" }
      }
    ]
  }
}
```

---

## Architecture Notes

### Main Components

| File | Purpose |
|------|---------|
| `lib/genui_x.dart` | Public exports |
| `lib/src/genui_x_transport.dart` | Main `Transport` implementation (`GenuiXTransport`) with `.openai()`, `.anthropic()`, `.gemini()` factories |
| `lib/src/genui_x_config.dart` | `GenuiXConfig` value object and `GenuiXStreamFormat` enum |
| `lib/src/anthropic_sse_parser.dart` | Anthropic Messages API SSE parser |
| `lib/src/openai_sse_parser.dart` | OpenAI Chat Completions SSE parser |
| `lib/src/gemini_sse_parser.dart` | Gemini `streamGenerateContent` SSE parser |

### Key Interfaces

- `Transport` - genui's transport interface (from `package:genui`)
- `GenuiXTransport` - main implementation
- `GenuiXConfig` - configuration holder
- `AnthropicSseParser` / `OpenAiSseParser` / `GeminiSseParser` - per-vendor SSE parsers (internal)

### Dependencies

- `genui` (^0.8.0) - Generative UI framework
- `http` (^1.2.0) - HTTP client for API calls
- `flutter_test` - Testing framework
- `flutter_lints` - Linting rules
