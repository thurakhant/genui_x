<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-19 -->

# example/lib/

## Purpose
Four Flutter entry points demonstrating different complexity levels and backend choices for `genui_x` integration. Each file is a complete runnable app including its own `Catalog`, `CatalogItem`, `widgetBuilder`, and chat UI.

## Key Files

| File | Description |
|------|-------------|
| `minimal_main.dart` | Simplest demo — `WeatherWidget` catalog, single-button chat, no proxy options |
| `main.dart` | Full-featured demo — `WeatherWidget` catalog with proxy/model overrides via `--dart-define`, text input chat |
| `travel_main.dart` | Travel demo — custom `TravelPlanWidget` catalog, shows `data`-wrapped component properties and list props |
| `gemini_main.dart` | Gemini-backend demo — uses `GenuiXTransport.gemini()` against the Generative Language API |

## For AI Agents

### A2UI Protocol — CRITICAL RULES
The `PromptBuilder.chat` used in `GenuiXTransport` generates a system prompt that instructs the model to:
1. First send a `createSurface` message (with unique `surfaceId` and `catalogId`).
2. Then send an `updateComponents` message populating the surface.

**Never override this by telling the model to skip `createSurface` in user messages.**  
The `SurfaceController` buffers `updateComponents` for unknown surfaces — if `createSurface` never arrives, nothing renders.

Component objects in `updateComponents` **MUST** include `"id"` (a unique string). At least one component **MUST** have `"id": "root"` — without it nothing displays. The parser hard-casts `json['id'] as String`; a missing `id` causes a `type 'Null' is not a subtype of type 'String'` crash.

### Custom CatalogItem pattern (`travel_main.dart`)
Custom widgets receive their props via the `"data"` field in the A2UI component JSON:
```json
{
  "id": "root",
  "component": "TravelPlanWidget",
  "data": { "destination": "Kyoto", "days": 3, "highlights": ["..."] }
}
```
The `widgetBuilder` accesses them via `ctx.data as Map<String, dynamic>`.

### systemPromptFragments guidelines
- Use fragments to describe **when/why** to use a widget, and to show the correct `data` shape.
- Do NOT instruct the model to skip `createSurface` or to "respond ONLY with updateComponents" — that fights the framework.
- Include `"id": "root"` in any JSON examples embedded in fragments.

### Working In This Directory
- Each file is self-contained. New demos can be added as new `*_main.dart` files.
- Keep `widgetBuilder` logic minimal — it should only cast and delegate to a proper `StatelessWidget`.
- Use `(data['field'] as num).toInt()` / `.toDouble()` for numeric fields — the model may emit integers or floats.

### Testing Requirements
```bash
cd example && flutter analyze   # static analysis
cd example && flutter test      # widget smoke tests
```

## Dependencies

### Internal
- `../AGENTS.md` — example-wide conventions

### External
- `package:genui_x` — `GenuiXTransport` (with `.openai()`, `.anthropic()`, `.gemini()` factories), `GenuiXConfig`, `GenuiXStreamFormat`
- `package:genui` — `Catalog`, `CatalogItem`, `SurfaceController`, `Conversation`, `Surface`, `ChatMessage`, `PromptBuilder`
- `package:json_schema_builder` — `S.object()`, `S.string()`, etc.

<!-- MANUAL: -->
