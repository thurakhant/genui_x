# genui_x

[![pub package](https://img.shields.io/pub/v/genui_x.svg)](https://pub.dev/packages/genui_x)
[![pub points](https://img.shields.io/pub/points/genui_x.svg)](https://pub.dev/packages/genui_x/score)
[![likes](https://img.shields.io/pub/likes/genui_x.svg)](https://pub.dev/packages/genui_x/score)
[![CI](https://github.com/thurakhant/genui_x/actions/workflows/ci.yml/badge.svg)](https://github.com/thurakhant/genui_x/actions/workflows/ci.yml)

> **The missing backend for [A2UI](https://a2ui.org/) generative UI in Flutter.** One transport, every major LLM — Anthropic Claude, OpenAI, Google Gemini, local Ollama, or any OpenAI-compatible proxy.

**▶️ [Try it live](https://thurakhant.github.io/genui_x/)** — paste your own Anthropic API key and watch a prompt stream into a rendered widget. Nothing to install; your key never leaves the browser tab.

<!--
  Demo GIF placeholder — record ~15 s of `example/lib/travel_main.dart`
  (prompt → streamed widget) and drop the file at `screenshots/demo.gif`,
  then uncomment the line below.

![genui_x demo](screenshots/demo.gif)
-->

```dart
final transport = GenuiXTransport.anthropic(  // or .openai() / .gemini() / .ollama()
  apiKey: const String.fromEnvironment('CLAUDE_API_KEY'),
  catalog: myCatalog,
);
```

[`a2ui_flutter`](https://pub.dev/packages/a2ui_flutter) defines *what* the AI can render. `genui_x` connects it to *who* generates it.

## Provider matrix

| Provider | Factory | Streaming | JSON mode | Auth header | Default model |
|---|---|:-:|:-:|---|---|
| Anthropic Claude | `GenuiXTransport.anthropic()` | ✅ | n/a (Claude is JSON-friendly) | `x-api-key` | `claude-haiku-4-5-20251001` |
| OpenAI / OpenRouter / LiteLLM | `GenuiXTransport.openai()` | ✅ | ✅ via `enforceJsonMode` | `Authorization: Bearer` | `gpt-4o-mini` |
| Google Gemini | `GenuiXTransport.gemini()` | ✅ | n/a (uses `systemInstruction`) | `x-goog-api-key` | `gemini-2.5-flash` |
| Ollama (local) | `GenuiXTransport.ollama()` | ✅ | ✅ via `enforceJsonMode` | `Authorization: Bearer` (placeholder) | `llama3.2` |
| Custom proxy | `GenuiXTransport(...)` | ✅ | via `requestBodyOverrides` | configurable | configurable |

All providers share the same retry-on-429, cancel, `clearHistory`, `isLoading`, `debug`, and `debugVerbose` controls.

---

## How A2UI and genui_x fit together

```
Your App
  │
  ├── a2ui_flutter            ← UI engine: renders widgets, manages surfaces
  │     CatalogImplementation ← your widget definitions
  │     MessageProcessor      ← applies A2UI messages to surfaces
  │     A2uiSurface           ← renders AI-generated UI in your widget tree
  │
  └── genui_x                 ← backend wire: HTTP, streaming, auth
        GenuiXTransport       ← prompts any LLM and streams its text and A2UI messages
```

**a2ui_flutter** (with [`a2ui_core`](https://pub.dev/packages/a2ui_core)) handles everything on the UI side — defining widgets, applying A2UI messages, and rendering surfaces. It ships no HTTP client.

**genui_x** provides the missing piece: a transport that calls any AI backend, prompts it with your catalog through [`a2ui_agent`](https://pub.dev/packages/a2ui_agent), streams the response, and hands the parsed A2UI messages to your renderer.

---

## Setup

### 1. Add dependencies

```yaml
# pubspec.yaml
dependencies:
  a2ui_core: ^0.6.0
  a2ui_flutter: ^0.2.0
  json_schema_builder: ^0.1.7
  genui_x: ^0.0.14
```

### 2. Create your catalog

```dart
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

final myCatalog = CatalogImplementation(
  id: 'com.example.my_catalog',
  components: [
    ComponentImplementation(
      name: 'WeatherWidget',
      schema: S.object(
        description: 'Shows weather for a city.',
        properties: {
          'city': S.string(description: 'City name'),
          'temperature': S.number(description: 'Temp in Celsius'),
          'condition': S.string(description: 'e.g. Sunny, Rainy'),
        },
        required: ['city', 'temperature', 'condition'],
      ),
      builder: (context, node, props, buildChild) {
        return WeatherWidget(
          city: props.string('city') ?? '',
          temperature: props.number('temperature') ?? 0,
          condition: props.string('condition') ?? '',
        );
      },
    ),
  ],
);
```

### 3. Wire up the conversation

```dart
import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:genui_x/genui_x.dart';

final transport = GenuiXTransport(
  apiKey: 'sk-ant-your-key-here',  // Never hardcode in production
  catalog: myCatalog,
  // model: 'claude-sonnet-4-6',   // Optional — default is claude-haiku-4-5
);

final processor = MessageProcessor<ComponentImplementation>(
  catalogs: [myCatalog],
  validationConfig: ValidationConfig.relaxed, // a surface streams in over several messages
  reportErrorsOnly: true,
);

final surfaces = ValueNotifier<List<SurfaceModel<ComponentImplementation>>>(const []);
processor.model.onSurfaceCreated.subscribe((surface) {
  surfaces.value = [...surfaces.value, surface];
});

// Apply the A2UI messages the model writes. A block the model got wrong
// arrives as an error.
transport.incomingMessages.listen(
  (message) => processor.processMessages(AgentToRendererMessagePayload.of(message)),
  onError: (Object error) => debugPrint('A2UI error: $error'),
);
// The model's text outside its A2UI blocks.
transport.incomingText.listen((text) => debugPrint(text));

// Send a message
await transport.sendRequest('What is the weather in Tokyo?');

// Render active surfaces in your widget tree
ValueListenableBuilder(
  valueListenable: surfaces,
  builder: (context, surfaces, _) {
    return Column(
      children: [
        for (final surface in surfaces)
          A2uiSurface(key: ObjectKey(surface), surface: surface),
      ],
    );
  },
);
```

---

## Backends

### Anthropic Claude (default)

```dart
final transport = GenuiXTransport(
  apiKey: 'sk-ant-your-key',
  catalog: myCatalog,
  model: 'claude-sonnet-4-6', // optional
);
```

### OpenAI

```dart
final transport = GenuiXTransport.openai(
  apiKey: 'sk-your-openai-key',
  catalog: myCatalog,
  // model: 'gpt-4o',          // optional — default is gpt-4o-mini
  // enforceJsonMode: true,    // optional — sets response_format to json_object
);
```

`enforceJsonMode: true` pins OpenAI's response to a JSON object. The model
writes A2UI as `<a2ui-json>` blocks inside its text, which a reply pinned to
one JSON object cannot hold, so leave it off for generative UI. Has no effect
on Anthropic or Gemini transports.

### Google Gemini

```dart
final transport = GenuiXTransport.gemini(
  apiKey: 'your-google-api-key',
  catalog: myCatalog,
  // model: 'gemini-2.5-pro',  // optional — default is gemini-2.5-flash
);
```

Sends `x-goog-api-key`, posts to
`/v1beta/models/{model}:streamGenerateContent?alt=sse`, and parses Gemini's
`candidates[*].content.parts[*].text` SSE stream. Override `baseUrl` to
point at a Vertex AI gateway or your own proxy.

### Ollama (local models)

```dart
final transport = GenuiXTransport.ollama(
  catalog: myCatalog,
  // model: 'llama3.2',                  // optional — default
  // baseUrl: 'http://localhost:11434',  // optional — default
);
```

Wraps `GenuiXTransport.openai()` against Ollama's OpenAI-compatible
endpoint. No API key is required by Ollama, but a placeholder bearer token
(`ollama`) is sent so the OpenAI-compat layer accepts the request. Pull
the model first with `ollama pull llama3.2`.

### OpenRouter / LiteLLM / custom proxy

```dart
final transport = GenuiXTransport.openai(
  apiKey: 'sk-or-your-key',
  catalog: myCatalog,
  baseUrl: 'https://openrouter.ai/api',
  model: 'anthropic/claude-3.5-sonnet',
);
```

For a fully custom proxy with non-standard headers:

```dart
final transport = GenuiXTransport(
  apiKey: 'your-key',
  catalog: myCatalog,
  baseUrl: 'https://your-proxy.example.com',
  endpointPath: '/v1/chat/completions',
  apiKeyHeader: 'authorization',
  apiKeyPrefix: 'Bearer ',
  streamFormat: GenuiXStreamFormat.openai,
);
```

---

## Surface operations

By default the AI can only **create** new surfaces. Use `surfaceOperations` to
allow updates or deletion:

```dart
final transport = GenuiXTransport(
  apiKey: 'your-key',
  catalog: myCatalog,
  surfaceOperations: SurfaceOperations.createAndUpdate(dataModel: false),
  // SurfaceOperations.all(dataModel: true)      — create + update + delete + data model
  // SurfaceOperations.updateOnly(dataModel: false) — update only
);
```

---

## Client data model

Pass app-state context so the AI knows about the current user or session:

```dart
final transport = GenuiXTransport(
  apiKey: 'your-key',
  catalog: myCatalog,
  clientDataModel: {
    'userName': 'Alice',
    'plan': 'pro',
    'locale': 'en-US',
  },
);
```

---

## Transport controls

### Cancel an in-flight request

```dart
transport.cancel();
```

### Clear conversation history

```dart
transport.clearHistory();
```

### Loading state

```dart
ValueListenableBuilder<bool>(
  valueListenable: transport.isLoading,
  builder: (context, loading, _) {
    return loading ? const CircularProgressIndicator() : const SizedBox.shrink();
  },
);
```

### Debug logging

```dart
final transport = GenuiXTransport(
  apiKey: 'your-key',
  catalog: myCatalog,
  debug: true, // prints request URL, status code, and errors to console
  // debugVerbose: true, // optional — logs raw SSE frames and parser chunk previews
);
```

---

## Models

| Provider | Model | Notes |
|----------|-------|-------|
| Claude | `claude-haiku-4-5-20251001` | Default — fast, low cost |
| Claude | `claude-sonnet-4-6` | Balanced quality/cost |
| Claude | `claude-opus-4-6` | Highest quality |
| OpenAI | `gpt-4o-mini` | Default for `.openai()` |
| OpenAI | `gpt-4o` | Higher quality |
| Gemini | `gemini-2.5-flash` | Default for `.gemini()` — fast, low cost |
| Gemini | `gemini-2.5-pro` | Higher quality |
| Ollama | `llama3.2` | Default for `.ollama()` — local |
| Ollama | any local model slug | e.g. `qwen2.5-coder`, `mistral` |
| OpenRouter | any model slug | via `GenuiXTransport.openai(baseUrl: ...)` |

---

## Example

See the [`example/`](example/) folder for working apps:

```bash
# Claude (default)
cd example
flutter run --dart-define=CLAUDE_API_KEY=sk-ant-your-key-here

# Minimal
flutter run -t lib/minimal_main.dart --dart-define=CLAUDE_API_KEY=sk-ant-your-key-here

# OpenAI-compatible proxy
flutter run -t lib/proxy_main.dart \
  --dart-define=PROXY_BASE_URL=https://openrouter.ai/api \
  --dart-define=PROXY_API_KEY=sk-or-your-key \
  --dart-define=PROXY_MODEL=anthropic/claude-3.5-sonnet

# Google Gemini
flutter run -t lib/gemini_main.dart \
  --dart-define=GEMINI_API_KEY=your-google-api-key

# Ollama (local — no API key)
flutter run -t lib/ollama_main.dart
# or with overrides:
flutter run -t lib/ollama_main.dart \
  --dart-define=OLLAMA_BASE_URL=http://192.168.1.50:11434 \
  --dart-define=OLLAMA_MODEL=qwen2.5-coder
```

---

## API key security

**Never hardcode your API key in client-side code.**

- During development, pass it via `--dart-define=API_KEY=...`
- In production, route through your own backend proxy and set `baseUrl` to your proxy URL

---

## Limitations

- **Streaming only** — non-streaming mode is not supported.
- **Flutter Web** — direct API calls to Anthropic or OpenAI will fail due to CORS. Use `baseUrl` to route through a backend proxy.
- **A2UI SDKs are pre-1.0** — `a2ui_core`, `a2ui_flutter` and `a2ui_agent` are in early development; breaking changes may occur.

---

## Troubleshooting

- **HTTP 200 but no UI yet** — `200` means the stream opened. UI appears only after valid A2UI chunks (`createSurface` + `updateComponents`) are parsed.
- **Proxy SSE format differences** — `genui_x` accepts both `data: {...}` and `data:{...}` SSE line formats used by OpenAI-compatible proxies.
- **Catalog ID mismatch** — ensure the model emits the same `catalogId` that your `MessageProcessor` registered.
- **Component props shape** — properties go flat next to `id` and `component`. A component that wraps them under `data` fails the catalog schema and arrives on `incomingMessages` as an error.
