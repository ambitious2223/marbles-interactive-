<div align="center">

# 🎱 Marble Royale

**A live TikTok marble race for the [Tikora](https://github.com/ambitious2223) hub.**

Viewers drop into the race by commenting; gifts fire power-ups at themselves or the leader;
big gifters get glowing tier skins and their real TikTok profile photo wrapped onto their marble.

</div>

> **Built on the MIT-licensed [Marble](https://github.com/MechanicalFlower/Marble) by MechanicalFlower.**
> This fork keeps that licence and adds a live, hub-driven mode. See [Attribution](#attribution--license).

---

## What it is

A 3D marble-race game in **Godot 4**, played by a live audience rather than a keyboard:

- **Join for free** — any comment spawns that viewer's marble (one per viewer, persistent across rounds).
- **Gifts drive the action** — the hub routes a gift to a power-up: boost, banana, shell, bomb, chaos, and more.
- **Skins show status** — your gift tier becomes your marble's colour + glow; your TikTok profile photo becomes your marble's face.
- **Cinematic-ish camera** follows the leader so the stream always watches the action.
- **Auto round loop** — lobby → countdown → race → podium → restart, hands-free for the streamer.

## How it plays on stream

```
TikTok comment ─▶ Tikora hub ─▶ viewer's marble spawns in the next race
TikTok gift    ─▶ Tikora hub ─▶ routed effect ─▶ power-up on the sender's / leader's marble
TikTok likes   ─▶ Tikora hub ─▶ (broadcast event, available to the game)
```

The game runs in its own native window (or export); Tikora launches it and injects the connection
details. **The game contains no TikTok code** — the hub owns all of that. See
[`docs/TIKORA_INTEGRATION.md`](docs/TIKORA_INTEGRATION.md).

## Requirements

- **Godot 4** with **.NET (Mono)** — developed against **4.7.2**.
- **Tikora** (the desktop hub) running locally, for the live connection.
- Windows for the current `start.bat` launcher (the Godot project itself is cross-platform).

## Running it

### From Tikora (the intended way)
The game is registered in Tikora as the slug **`marble-royale`**. Launch it from **Game Store → Marble Royale**.
Tikora starts [`start.bat`](start.bat) and injects `TIKORA_RELAY_URL`, `TIKORA_GAME_SLUG`, `TIKORA_GAME_KEY`.

### From the Godot editor
Open `project.godot` in the Godot .NET editor and press **F5**. With Tikora running it will connect
automatically (generic mode, no key) and start a hub round. Without Tikora it falls back to the
normal local menu.

### Testing without a live stream
Inject events into Tikora's relay (Gift Gallery → Inject, or Actions & Events → Simulator). The game
reacts exactly as it would to real viewers. See [`docs/TIKORA_INTEGRATION.md`](docs/TIKORA_INTEGRATION.md#testing).

## Effects (the game's vocabulary)

Declared in [`tikora.manifest.json`](tikora.manifest.json) and handled in `Main.hub_apply_effect()`:

| Effect | What it does |
|---|---|
| `boost` | shove the sender's marble forward |
| `shield` | (reserved) |
| `hazard_shell` / `hazard_bomb` | slow/blast the current leader |
| `hazard_banana` / `slow_leader` | slow the current leader |
| `freeze_pack` | brief mass slow across the field |
| `magnet` | pull rivals back toward the sender |
| `teleport` | short forward phase for the sender |
| `spawn_decoys` | spawn extra decoy marbles |
| `chaos` | rattle every marble (big-gift spectacle) |
| `grant_skin` | give the sender a skin tier |
| `use_avatar_face` | wrap the sender's profile photo onto their marble |

**Default gift mappings** (seeded into the hub from the manifest) — tier `small`→boost,
`medium`→banana, `large`→shell, `epic`/`legendary`→chaos, `100+ coins`→bomb. The streamer can
rebind any of these in Tikora's Trigger → Effect mapper.

## Project layout

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full map. The short version:

```
scripts/tikora/tikora_hub.gd         # reusable Tikora hub client (WebSocket, protocol v2)
scripts/tikora/tikora_controller.gd  # bridges hub events into the game
scripts/main.gd                      # game controller + hub mode (joins, effects, rounds)
scripts/marble.gd                    # marble: tier skins + profile-photo face
tikora.manifest.json                 # effects + default mappings declared to the hub
start.bat                            # launcher Tikora runs (injects env)
```

## Working on it

Read [`AGENTS.md`](AGENTS.md) — it has the guardrails, conventions, and the run/verify workflow.

## Attribution & license

- Based on **Marble** © MechanicalFlower, licensed **MIT** (see [`LICENSE.md`](LICENSE.md) and [`CREDITS.md`](CREDITS.md)).
- Bundled addons: **UniversalFade** (MIT), **godot-debug-menu** (MIT), **gd-plug** (MIT), **export-build-info**.
- Marble Royale additions © ambitious2223, released under the same MIT licence.
