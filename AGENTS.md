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

## 1. Never claim something works without proving it

Before saying a change is done, **actually run it and look at the output**:

1. **Import after code/scene changes** (catches parse errors):
   ```
   godot --headless --path . --import
   ```
2. **Run headless with the hub and inject events**, then read the log:
   ```
   # PowerShell
   $env:TIKORA_RELAY_URL="ws://127.0.0.1:27016/"
   $env:TIKORA_GAME_KEY="gk_…"            # from Tikora → Game Hub
   $env:TIKORA_DEBUG="1"
   # (run godot, then, in another shell:)
   node tools/inject.cjs
   ```
   The game prints `[TikoraHub] …` and `[MarbleRoyale] join:/effect …`.
   A run is **not** done if it shows `SCRIPT ERROR`, `Parse Error`, or `Nonexistent function`.
3. **For visual changes**, run it windowed, capture with `tools/screenshot.ps1`, and *look at the
   PNG* before describing it:
   ```
   powershell -ExecutionPolicy Bypass -File tools/screenshot.ps1 -ProcessId <pid> -Out shot.png
   ```
4. Report in plain language: **what you built, what you verified** (specifics: "ran headless,
   injected `alice` + a Rose gift, saw `join: alice` and `effect 'boost'` with no errors"), **and
   what is still untested.**

Fix errors and re-verify up to 3 times before asking for help.

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
4. Re-import, run, and test with `tools/inject.cjs` or the Tikora Trigger → Effect mapper.
5. Commit with a plain-language message.

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
- Commit after each verified piece with a message a non-coder understands
  (e.g. "Camera now follows the leader").
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
  routing; tier skins; profile-photo faces; camera follows the leader; auto round loop with a
  time-limit guard; stream HUD (round status + compact corner gift toasts with avatars + event feed);
  lobby countdown + winner celebration; **hub-driven settings** (`configure` effect, persisted);
  resizable window + `F11` fullscreen; per-round track variety; registered in Tikora as `marble-royale`.
- **Open / TODO:**
  - **Visual direction: clean / polished.** A retro/PS1 pass (low-res + dither + fog) was tried and
    **rejected by the owner** — do **not** re-apply it. Prefer clean rendering + on-screen polish.
  - Verify a real live session launched from the Tikora **Game Store** (with real avatars).
  - `shield` effect is a no-op placeholder.
  - Missing polish: sound (boost/hazard/win cues); dedicated kill-feed.
  - Export presets + a built `.exe` for `start.bat` (currently dev fallback runs the editor).

**Settings (hub-driven):** defaults live in `Main.DEFAULT_CFG`; the hub can change them by firing the
`configure` effect with an optional payload — `capacity` (4-40), `round_seconds` (20-300), `alerts`,
`feed`, `shake`. Applied live, saved to `user://marble_royale.cfg`, reported back via `report_state`.

**Controls:** `F11` toggles fullscreen; the window is resizable (stretch mode `viewport`).

## 8. Quick facts

- **Engine:** Godot 4.7.2 (.NET/Mono). Project targets Godot 4.4 features.
- **Game slug:** `marble-royale`
- **Relay:** `ws://127.0.0.1:27016/` (override: `TIKORA_RELAY_PORT`)
- **Env injected at launch:** `TIKORA_RELAY_URL`, `TIKORA_GAME_SLUG`, `TIKORA_GAME_KEY`
- **Autoloads:** `SettingsManager`, `Shake`, `DebugMenu`, `TikoraHub`
- **Useful:** `TIKORA_DEBUG=1` turns on `[TikoraHub]` logging.
