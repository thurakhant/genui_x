<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-19 -->

# lib/

## Purpose
Public-facing library root. Re-exports the package's public API surface via a single barrel file. Only `GenuiXTransport` and `GenuiXConfig` (plus the supporting enum, errors, and selected `genui` re-exports) are exported — internal parsing details stay hidden.

## Key Files

| File | Description |
|------|-------------|
| `genui_x.dart` | Barrel export — exposes `GenuiXTransport`, `GenuiXConfig`, `GenuiXStreamFormat`, `GenuiXAuthError`, `GenuiXApiError`, `GenuiXRateLimitError`, plus `PromptFragments` / `SurfaceOperations` re-exported from `package:genui` |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `src/` | Internal implementation modules (see `src/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- **Only edit `genui_x.dart`** to add or remove public exports.
- Never put implementation logic here; it belongs in `src/`.
- Every new public symbol added to `src/` must be re-exported here if it is intended for package consumers.

### Common Patterns
- Single `export` line per source file. No `show`/`hide` filters unless intentional API narrowing is needed (the `genui` re-export uses `show` to keep the surface explicit).

<!-- MANUAL: -->
