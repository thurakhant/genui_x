<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-19 -->

# example/lib/

## Purpose
Five Flutter entry points demonstrating different complexity levels and backend choices for `genui_x` integration. Each file is a complete runnable app including its own `CatalogImplementation`, `ComponentImplementation`, `builder`, and chat UI.

## Key Files

| File | Description |
|------|-------------|
| `minimal_main.dart` | Simplest demo — `WeatherWidget` catalog, single-button chat, no proxy options |
| `main.dart` | Full-featured demo — `WeatherWidget` catalog with proxy/model overrides via `--dart-define`, text input chat |
| `travel_main.dart` | Travel demo — custom `TravelPlanWidget` catalog with list props |
| `gemini_main.dart` | Gemini-backend demo — uses `GenuiXTransport.gemini()` against the Generative Language API |
| `ollama_main.dart` | Local Ollama demo — uses `GenuiXTransport.ollama()`, no API key required |
| `proxy_main.dart` | Generic OpenAI-compatible proxy demo (LiteLLM, OpenRouter, etc.) configured via `--dart-define` |

## For AI Agents

### A2UI Protocol — CRITICAL RULES
The `a2ui_agent` prompt used in `GenuiXTransport` instructs the model to:
1. First send a `createSurface` message (with unique `surfaceId` and `catalogId`).
2. Then send an `updateComponents` message populating the surface.

**Never override this by telling the model to skip `createSurface` in user messages.**  
An `updateComponents` for a surface that does not exist yet is rejected — if `createSurface` never arrives, nothing renders.

Component objects in `updateComponents` **MUST** include `"id"` (a unique string). At least one component **MUST** have `"id": "root"` — without it nothing displays. A component without `id` is rejected.

### Custom ComponentImplementation pattern (`travel_main.dart`)
Custom widgets receive their props flat in the A2UI component JSON:
```json
{
  "id": "root",
  "component": "TravelPlanWidget",
  "destination": "Kyoto", "days": 3, "highlights": ["..."]
}
```
The `builder` reads them through `props` (`props.string('destination')`, `props.number('days')`, `props.list('highlights')`).

### Catalog instructions guidelines
- Use the catalog's `instructions` to describe **when/why** to use a widget, and to show the correct property shape.
- Do NOT instruct the model to skip `createSurface` or to "respond ONLY with updateComponents" — that fights the framework.
- Include `"id": "root"` in any JSON examples embedded in fragments.

### Working In This Directory
- Each file is self-contained. New demos can be added as new `*_main.dart` files.
- Keep `builder` logic minimal — it should only read `props` and delegate to a proper `StatelessWidget`.
- `props.number('field')` returns a `double?` whether the model emits an integer or a float; call `.toInt()` for integer fields.

### Testing Requirements
```bash
cd example && flutter analyze   # static analysis
cd example && flutter test      # widget smoke tests
```

## Dependencies

### Internal
- `../AGENTS.md` — example-wide conventions

### External
- `package:genui_x` — `GenuiXTransport` (with `.openai()`, `.anthropic()`, `.gemini()`, `.ollama()` factories), `GenuiXConfig`, `GenuiXStreamFormat`
- `package:a2ui_flutter` — `CatalogImplementation`, `ComponentImplementation`, `ComponentProps`, `A2uiSurface`
- `package:a2ui_core` — `MessageProcessor`, `SurfaceModel`, `AgentToRendererMessagePayload`
- `package:json_schema_builder` — `S.object()`, `S.string()`, etc.

<!-- MANUAL: -->
