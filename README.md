# genui_x

[![pub package](https://img.shields.io/pub/v/genui_x.svg)](https://pub.dev/packages/genui_x)
[![pub points](https://img.shields.io/pub/points/genui_x.svg)](https://pub.dev/packages/genui_x/score)
[![likes](https://img.shields.io/pub/likes/genui_x.svg)](https://pub.dev/packages/genui_x/score)

A lightweight Claude AI adapter for Google's [genui](https://pub.dev/packages/genui) (Generative UI) framework.

Use Anthropic's Claude as the AI engine for genui — no changes to the core framework needed.

---

## What it does

`genui_x` provides `ClaudeTransport`, a drop-in implementation of genui's `Transport` interface. It connects Claude's Messages API to the genui rendering pipeline so that Claude can dynamically build Flutter UIs from your widget catalog.

**How it works:**

1. `ClaudeTransport` sends the full A2UI widget schema to Claude as a system prompt.
2. Claude responds with A2UI JSON blocks (e.g. `createSurface`, `updateComponents`) embedded in its text output.
3. genui's built-in `A2uiParserTransformer` extracts these blocks and renders the widgets — automatically.

No tool-calling setup required. No custom parsers. Just plug in your API key.

---

## Setup

### 1. Add dependencies

```yaml
# pubspec.yaml
dependencies:
  genui: ^0.8.0
  genui_x: ^0.0.4
```

### 2. Create your catalog

```dart
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

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

final transport = ClaudeTransport(
  apiKey: 'sk-ant-your-key-here',  // Never hardcode in production
  catalog: myCatalog,
  // model: 'claude-sonnet-4-6',   // Optional — default is claude-haiku-4-5
  // baseUrl: 'https://my-proxy',  // Optional — for proxy backends
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

## API key security

**Never hardcode your API key in client-side code.**

Recommended approaches:
- Pass it via `--dart-define=CLAUDE_API_KEY=sk-ant-...` during development.
- In production, route through your own backend proxy and set `baseUrl` to your proxy URL.

You can use `.env.example` as a template for local development values.

### Using LiteLLM or a proxy

If your proxy uses Authorization headers or a custom path, configure the
transport like this:

```dart
final transport = ClaudeTransport(
  apiKey: 'your-key',
  catalog: myCatalog,
  baseUrl: 'https://your-proxy.example.com',
  endpointPath: '/v1/messages',
  apiKeyHeader: 'authorization',
  apiKeyPrefix: 'Bearer ',
);
```

For OpenAI-style streaming endpoints, set the stream format and path:

```dart
final transport = ClaudeTransport(
  apiKey: 'your-key',
  catalog: myCatalog,
  baseUrl: 'https://your-proxy.example.com',
  endpointPath: '/v1/chat/completions',
  apiKeyHeader: 'authorization',
  apiKeyPrefix: 'Bearer ',
  streamFormat: ClaudeStreamFormat.openai,
  requestBodyOverrides: const {
    'response_format': {'type': 'json_object'},
  },
);
```

---

## Models

| Model | Speed | Cost | Recommended for |
|-------|-------|------|-----------------|
| `claude-haiku-4-5-20251001` | Fast | Low | Default, prototyping |
| `claude-sonnet-4-6` | Balanced | Medium | Production quality |
| `claude-opus-4-6` | Slow | High | Complex UIs |

---

## Example

See the [`example/`](example/) folder for a working chat app that renders a
`WeatherWidget` dynamically when the user asks about weather.

```bash
cd example
flutter run --dart-define=CLAUDE_API_KEY=sk-ant-your-key-here
```

Minimal example:

```bash
cd example
flutter run -t lib/minimal_main.dart --dart-define=CLAUDE_API_KEY=sk-ant-your-key-here
```

---

## Limitations

- **Streaming only** — non-streaming mode is not supported.
- **Flutter Web** — direct API calls to Anthropic will fail due to CORS. Use the `baseUrl` parameter to route through a backend proxy.
- **genui alpha** — genui itself is in early development; breaking changes may occur.
