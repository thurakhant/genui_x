# genui_x

[![pub package](https://img.shields.io/pub/v/genui_x.svg)](https://pub.dev/packages/genui_x)
[![pub points](https://img.shields.io/pub/points/genui_x.svg)](https://pub.dev/packages/genui_x/score)
[![likes](https://img.shields.io/pub/likes/genui_x.svg)](https://pub.dev/packages/genui_x/score)

A lightweight AI backend adapter for Google's [genui](https://pub.dev/packages/genui) (Generative UI) framework.

Connect any AI backend — Anthropic Claude, OpenAI, OpenRouter, LiteLLM, or your own proxy — to genui with a single class.

---

## How genui and genui_x fit together

```
Your App
  │
  ├── genui          ← UI engine: renders widgets, manages surfaces
  │     Catalog      ← your widget definitions
  │     Conversation ← drives the chat loop
  │     Surface      ← renders AI-generated UI in your widget tree
  │
  └── genui_x        ← backend wire: HTTP, streaming, auth
        GenuiXTransport ← implements genui's Transport interface
```

**genui** handles everything on the UI side — defining widgets, parsing A2UI JSON, and rendering surfaces. It ships no HTTP client.

**genui_x** provides the missing piece: a `Transport` that calls any AI backend, streams the response, and feeds it back into genui's rendering pipeline.

---

## Setup

### 1. Add dependencies

```yaml
# pubspec.yaml
dependencies:
  genui: ^0.8.0
  genui_x: ^0.0.11
```

### 2. Create your catalog

```dart
import 'package:genui/genui.dart';

final myCatalog = Catalog(
  [
    CatalogItem(
      name: 'WeatherWidget',
      dataSchema: S.object(
        description: 'Shows weather for a city.',
        properties: {
          'city': S.string(description: 'City name'),
          'temperature': S.number(description: 'Temp in Celsius'),
          'condition': S.string(description: 'e.g. Sunny, Rainy'),
        },
        required: ['city', 'temperature', 'condition'],
      ),
      widgetBuilder: (ctx) {
        final data = ctx.data as Map<String, dynamic>;
        return WeatherWidget(
          city: data['city'] as String,
          temperature: (data['temperature'] as num).toDouble(),
          condition: data['condition'] as String,
        );
      },
    ),
  ],
  catalogId: 'com.example.my_catalog',
);
```

### 3. Wire up the conversation

```dart
import 'package:genui/genui.dart';
import 'package:genui_x/genui_x.dart';

final transport = GenuiXTransport(
  apiKey: 'sk-ant-your-key-here',  // Never hardcode in production
  catalog: myCatalog,
  // model: 'claude-sonnet-4-6',   // Optional — default is claude-haiku-4-5
);

final controller = SurfaceController(catalogs: [myCatalog]);

final conversation = Conversation(
  controller: controller,
  transport: transport,
);

// Send a message
await conversation.sendRequest(ChatMessage.user('What is the weather in Tokyo?'));

// Render active surfaces in your widget tree
ValueListenableBuilder(
  valueListenable: conversation.state,
  builder: (context, state, _) {
    return Column(
      children: state.surfaces.map((id) =>
        Surface(surfaceContext: controller.contextFor(id)),
      ).toList(),
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

Set `enforceJsonMode: true` to pin OpenAI's response to a JSON object, which
improves A2UI compliance on smaller models. Has no effect on Anthropic or
Gemini transports.

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
import 'package:genui/genui.dart'; // for SurfaceOperations

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
- **genui alpha** — genui itself is in early development; breaking changes may occur.
