<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-06 | Updated: 2026-04-06 -->

# lib/

## Purpose
Public-facing library root. Re-exports the package's public API surface via a single barrel file. Only `ClaudeTransport` and `ClaudeConfig` (plus the supporting enums/exceptions) are exported — internal parsing details stay hidden.

## Key Files

| File | Description |
|------|-------------|
| `genui_x.dart` | Barrel export — exposes `ClaudeTransport`, `ClaudeConfig`, `ClaudeStreamFormat`, `ClaudeApiException`, `ClaudeAuthException` |

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
- Single `export` line per source file. No `show`/`hide` filters unless intentional API narrowing is needed.

<!-- MANUAL: -->
