# genui_x examples

Five runnable entry points — pick the one that matches your setup.

---

## Basic — direct Claude API

```bash
flutter run --dart-define=CLAUDE_API_KEY=sk-ant-your-key
```

Full chat app with a weather widget catalog.

---

## Minimal — simplest possible example

```bash
flutter run -t lib/minimal_main.dart --dart-define=CLAUDE_API_KEY=sk-ant-your-key
```

Single-button app. Best starting point for new users.

---

## Proxy — OpenAI-compatible backend

For LiteLLM, OpenRouter, or any custom proxy:

```bash
flutter run -t lib/proxy_main.dart \
  --dart-define=PROXY_BASE_URL=https://your-proxy.example.com \
  --dart-define=PROXY_API_KEY=your-key \
  --dart-define=PROXY_MODEL=gpt-4o
```

Shows `GenuiXStreamFormat.openai`, `authorization` header, and `Bearer ` prefix.

---

## Gemini — Google's Generative Language API

```bash
flutter run -t lib/gemini_main.dart \
  --dart-define=GEMINI_API_KEY=your-google-api-key
```

Uses `GenuiXTransport.gemini()`, the `x-goog-api-key` header, and the
`streamGenerateContent?alt=sse` endpoint.

---

## Ollama — local model, no API key

```bash
# 1. Pull a model first (one-time):
ollama pull llama3.2

# 2. Run the example:
flutter run -t lib/ollama_main.dart

# Optional overrides:
flutter run -t lib/ollama_main.dart \
  --dart-define=OLLAMA_BASE_URL=http://192.168.1.50:11434 \
  --dart-define=OLLAMA_MODEL=qwen2.5-coder
```

Uses `GenuiXTransport.ollama()` against Ollama's OpenAI-compatible
endpoint with `enforceJsonMode: true` for stricter A2UI output.
