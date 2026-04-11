# genui_x examples

Three runnable entry points — pick the one that matches your setup.

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
