# Architecture

How Marble Royale is put together, and where the Tikora boundary sits.

## The big picture

```
                 ┌────────────────────────── Tikora hub (separate app) ──────────────────────────┐
TikTok LIVE ───▶ │ tiktok.cjs → relay.cjs (ws://127.0.0.1:27016) → effects.cjs (trigger→effect)   │
                 └───────────────────────────────────────────────┬──────────────────────────────┘
                                                                 │ events + routed effects (JSON over WS)
                                                                 ▼
   ┌──────────────────────────────────────── Marble Royale (this repo, Godot) ─────────────────────────────┐
   │  TikoraHub (autoload) ──signals──▶ TikoraController ──calls──▶ Main (hub mode) ──▶ marbles / camera   │
   └───────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

The game never speaks to TikTok. It speaks the hub's local protocol and nothing else.

## Godot project

- **Scene**: `scenes/main.tscn` — `Menu`, `Race` (procedural track), `MarblePool` (reused marbles),
  `Overlay` (ranking UI), `Countdown`, `Podium`, and the cameras. Entry: `scripts/main.gd` (`Main`).
- **Autoloads** (`project.godot`): `SettingsManager`, `Shake`, `DebugMenu`, **`TikoraHub`**.
- **Engine**: Godot 4 (.NET); project `config/features` targets 4.4, developed on 4.7.

## Scripts and responsibilities

| Script | Role |
|---|---|
| `scripts/tikora/tikora_hub.gd` | **Reusable** hub client. Owns the `WebSocketPeer`, reconnect/backoff, heartbeat, and re-emits the hub protocol as signals (`hub_connected`, `gift_received`, `effect_received`, …). Knows nothing about marbles. |
| `scripts/tikora/tikora_controller.gd` | Bridges `TikoraHub` signals to the game: comment → `Main.hub_join()`, gift → tier skin, effect → `Main.hub_apply_effect()`, downloads profile photos. |
| `scripts/main.gd` | Game controller. Adds **hub mode**: persistent roster, effect handling, auto round loop, and the camera-follow logic. |
| `scripts/marble.gd` | A marble. Adds **skins**: `set_skin_tier()` (colour + glow) and `set_face_texture()` (profile photo). |
| `scripts/race.gd`, `scripts/power.gd`, `scripts/camera/*.gd` | Upstream base: procedural track, boost pads, cameras. |

## Hub mode (what `Main` does when the hub connects)

1. `TikoraController` sees `TikoraHub.hub_connected` and calls `Main.enable_hub_mode()`.
2. `enable_hub_mode()` grows the marble pool to `START_ROWS*START_COLS` (24) and starts a round.
3. **A round** (`start_hub_round()`): build a track, re-spawn the persistent roster, run the
   countdown (scene tree paused), then race.
4. **Joins** (`hub_join`): a comment adds the viewer to the roster and drops their marble in
   immediately if a race is running; one marble per viewer per round.
5. **Effects** (`hub_apply_effect`): each effect key maps to a physics action (boost, hazards, …).
6. **End of round**: shortly after the first marble finishes, restart (auto-loop).

## Camera

`MarbleCamera` follows a target at a fixed distance. In hub mode `Main._process` keeps the target on
the **current leader** (`Ranking._first_marble`) and makes sure the follow camera is the active one
whenever a marble is visible (the base otherwise fell back to the wide overview and stayed there).

## Marble capacity

The base shipped a fixed 14-slot start grid and a small pool. We widened the grid
(`START_ROWS` × `START_COLS`) and grow the pool at runtime in `_ensure_marble_capacity()` — currently
24 marbles. Raise the constants to go higher.

## Skins

- **Tier** → colour + emissive glow (`Marble.set_skin_tier`), tier stored per viewer and re-applied
  each round.
- **Photo** → the viewer's TikTok `avatar` URL is downloaded by the controller and applied as the
  marble's albedo texture (`Marble.set_face_texture`).
