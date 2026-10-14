# AGENTS.md — Marble Royale

Guardrails and working rules for anyone (human or AI) changing this project.
Read this before touching code.

## 0. The golden rule — no TikTok code in this repo

All TikTok connectivity (connection, signing, gift catalog, event normalization, effect routing)
lives in the **Tikora hub** — a separate app. This game only talks to the hub over a local
WebSocket. **Never** add `tiktok-live-connector`, signature servers, login/session code, or a gift
catalog here. If a task seems to need TikTok code, it belongs in Tikora, not the game.

```
TikTok ─▶ Tikora hub (owns everything TikTok) ─▶ ws://127.0.0.1:27016 ─▶ this game
```

## 1. Don't test — write the code

**Testing is the human's job, not yours.** The fastest path is for you to ship code; the human
runs Godot and reports back. So:

- **Do not** run the game, `--import`, headless runs, `tools/inject.cjs`, `tools/screenshot.ps1`,
  or any other verification step. Don't launch Godot at all.
- Do **not** create test/screenshot artifacts, or spend turns trying to prove something works.
- Write small, correct, idiomatic GDScript/edits. Prefer the fastest, simplest implementation.
- Report plainly: **what you changed and why.** Leave verification to the human.

If you genuinely need something only a run can answer, **ask the human to run it** instead of
running it yourself.

## 2. Where code goes (respect the boundary)

| File | Responsibility | Do **not** put here |
|---|---|---|
| `scripts/tikora/tikora_hub.gd` | Hub protocol only (WebSocket client, reconnect, signals). **Reusable across games.** | game rules, marble logic |
| `scripts/tikora/tikora_controller.gd` | Translate hub signals → calls on `Main` | TikTok-specific logic |
| `scripts/main.gd` | Game controller + hub mode (`hub_join`, `hub_apply_effect`, round loop) | raw WebSocket handling |
| `scripts/marble.gd` | Marble behaviour + skins (`set_skin_tier`, `set_face_texture`) | hub code |
| `tikora.manifest.json` | Declares the game's effect vocabulary + default mappings | — |

If `tikora_hub.gd` needs a change that is game-specific, that's a smell — keep it generic.

## 3. Adding a new power-up (checklist)

1. Add the effect to `tikora.manifest.json` → `effects[]` (`key`, `label`, `kind`, optional `params`).
2. Handle the key in `Main.hub_apply_effect()`.
3. (Optional) add a `defaultMappings` entry so it works out-of-the-box.
4. Commit with a plain-language message (the human tests).

## 4. Godot gotchas (learned the hard way)

- **WebSocket buffers**: `WebSocketPeer` defaults to a 64 KiB inbound buffer. Tikora's first
  `hello` carries the whole ~900-gift catalog, which is far bigger — we raise both buffers to 8 MB
  in `tikora_hub.gd`. Do not lower this or the socket silently drops.
- **Paused tree**: races pause the scene tree during the countdown, so anything that must keep
  running while paused sets `process_mode = PROCESS_MODE_ALWAYS` (`TikoraHub`, the controller).
- **`.uid` files** are tracked by this project — commit them alongside their scripts.
- **Addons are vendored**: `addons/UniversalFade` and `addons/debug_menu` are committed and
  un-ignored in `.gitignore`. Upstream's `godot --headless --script plug.gd install` **fails on
  Godot 4.7**, so don't rely on it.
- **Do not re-add `public/`**: it was removed because it contained a filename with a trailing space
  (`public/.gdignore `) that breaks checkout on Windows.

## 5. Git discipline

- `origin` = `github.com/ambitious2223/marbles-interactive-` (push here). `upstream` = the original
  MIT Marble project (for pulling MIT updates; keep the licence intact).
- Commit after each piece with a message a non-coder understands
  (e.g. "Camera now follows the leader"). The human verifies by running it.
- Push to `origin main`. **Never force-push. Never rewrite `main` history.**
- **No secrets in the repo.** The game's `gk_…` key lives in the hub's database, not here; nothing
  in this repo should contain a real key.

## 6. Safety (this machine)

- **No download-and-execute one-liners** (`iwr`/`curl`/`wget` piped to a file or `iex`). They match
  the "ClickFix" malware signature and get quarantined. Prefer package managers; ask before
  downloading anything from the internet.
- Never touch antivirus settings or add exclusions to work around a block.

## 7. Current status / known limits

- **Works & verified:** hub connect + auth; comment→join (persistent roster, no dupes); gift→effect
  routing; tier skins; profile-photo faces; auto round loop with a time-limit guard; stream HUD
  (round status + compact corner gift toasts with avatars + event feed); lobby countdown + winner
  celebration; **20 curated levels** (length + piece mix + sky theme, sequential); **falls + respawn**
  (comment/like = free respawn after a delay, gift = instant); **viewer journey** (per-player
  profiles, welcome-back, `!me`, all-time leaderboard); **streamer camera** (auto/follow/overview +
  top-3 snap, keys configurable via hub settings); hub-driven settings (`configure`, persisted);
  resizable window + `F11` fullscreen; registered in Tikora as `marble-royale`.
- **Open / TODO:**
  - **Visual direction: clean / polished.** A retro/PS1 pass was tried and **rejected** — do not re-apply.
  - Verify a real live session launched from the Tikora **Game Store** (with real avatars).
  - `shield` effect is a no-op placeholder.
  - Missing polish: sound (boost/hazard/win cues).
  - Export presets + a built `.exe` for `start.bat` (currently dev fallback runs the editor).

**Settings (hub-driven):** defaults live in `Main.DEFAULT_CFG`; the hub can change them by firing the
`configure` effect with an optional payload — `capacity` (4-40), `round_seconds` (20-300), `alerts`,
`feed`, `shake`, `level` (1-20), and `camera` (`{cycle,next,top1,top2,top3,overview,auto}` key names).
Applied live, saved to `user://marble_royale.cfg`, reported back via `report_state`.

**Controls:** `F11` fullscreen; **camera** `C` cycle · `X` next viewer · `1/2/3` follow top‑3 ·
`O` overview · `A` auto (rebindable from the hub). Chat `!me` shows a viewer their stats.

## 8. Quick facts

- **Engine:** Godot 4.7.2 (.NET/Mono). Project targets Godot 4.4 features.
- **Game slug:** `marble-royale`
- **Relay:** `ws://127.0.0.1:27016/` (override: `TIKORA_RELAY_PORT`)
- **Env injected at launch:** `TIKORA_RELAY_URL`, `TIKORA_GAME_SLUG`, `TIKORA_GAME_KEY`
- **Autoloads:** `SettingsManager`, `Shake`, `DebugMenu`, `TikoraHub`
- **Useful:** `TIKORA_DEBUG=1` turns on `[TikoraHub]` logging.
