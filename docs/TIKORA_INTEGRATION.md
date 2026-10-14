# Tikora integration

How Marble Royale plugs into the Tikora hub, and how to test it.

> The hub itself (Tikora) is a separate project. Its protocol and integration guide are the source
> of truth — see the hub's own `docs/hub-protocol.md` and `docs/game-integration.md`.

## Connecting

The game is a WebSocket client of the hub's relay at `ws://127.0.0.1:27016/`
(override with `TIKORA_RELAY_PORT`).

Identity is injected by Tikora at launch through environment variables:

| Env var | Meaning |
|---|---|
| `TIKORA_RELAY_URL` | relay URL, e.g. `ws://127.0.0.1:27016/` |
| `TIKORA_GAME_SLUG` | `marble-royale` |
| `TIKORA_GAME_KEY` | the game's `gk_…` API key (required to receive routed **effects**) |

`TikoraHub` reads these, appends `?game=<slug>&key=<key>`, and connects. Without a key it connects as
a generic client: it still receives the broadcast **event** stream (gifts/comments/likes) but not
its own routed effects.

## Protocol (v2) — what the game uses

Server → client:
- `hello` — `{ protocol, catalog, status, integration }` (sent to every connection on open).
- `welcome` — sent after successful auth; the game replies with its `capabilities`.
- `event` — normalized gift / chat / like / follow / share / subscribe / member / roomUser.
- `effect` — `{ id, effect, payload, event }` addressed to this game only.
- `status`, `catalog`, `error`.

Client → server:
- `capabilities` — `{ effects: [{ key, label }] }` (from `tikora.manifest.json`).
- `effect:ack` — `{ id, result }`.
- `state`, `ping`, `get-catalog`, `debug:gift`, `debug:event`.

### Event shape (important fields)
```jsonc
{ "type": "gift", "username": "...", "name": "...", "avatar": "https://…",
  "userId": "...", "giftId": 5655, "giftName": "Rose", "coins": 1, "count": 1, "tier": "small" }
```
`avatar` is the viewer's profile-photo URL — used for the marble face.

### Effect shape
```jsonc
{ "id": "ef_…", "effect": "boost", "payload": { "strength": "2" },
  "event": { "type": "gift", "username": "...", "avatar": "https://…", "tier": "small" } }
```

## Registration in Tikora

The game is registered under the slug **`marble-royale`**:
- a row in the hub's `games` table (name/path/`bat_path` → `start.bat`), so it lists in the Game Store;
- a row in `game_integrations` holding its `gk_…` key;
- default gift→effect mappings seeded from `tikora.manifest.json` (`syncGameManifests`).

To (re)create the key by hand, use Tikora → **Stream Deck → Game Hub → ensure key**, or the Game Store.

## Effects & default mappings

Effects are declared in [`../tikora.manifest.json`](../tikora.manifest.json) and handled in
`Main.hub_apply_effect()`. Default mappings (rebindable in Tikora's Trigger → Effect mapper):

| Trigger | Effect |
|---|---|
| tier `small` | `boost` |
| tier `medium` | `hazard_banana` |
| tier `large` | `hazard_shell` |
| tier `epic` / `legendary` | `chaos` |
| `min_coins` 100 | `hazard_bomb` |

## Settings (the `configure` effect)

The game's runtime settings live in `Main.DEFAULT_CFG` and are **driven from the hub** — fire the
`configure` effect (Gift Gallery → Inject, a mapping, or the Game Store "Run" button) with a payload
containing any subset of:

| Payload key | Range / values | Meaning |
|---|---|---|
| `capacity` | 4–40 | simultaneous marbles (pool + start grid) |
| `round_seconds` | 20–300 | hard time-limit per round |
| `alerts` | true/false | show gift alert toasts |
| `feed` | true/false | show the event feed |
| `shake` | true/false | camera shake on big effects |

Example payload: `{ "capacity": 30, "round_seconds": 45, "shake": false }`.

Changes apply live, persist to `user://marble_royale.cfg`, and are reported back to the hub via
`report_state({ config })` on connect and after each change.

## Testing

Run the game (editor or `start.bat`) with Tikora running, then fire test events:

```
node tools/inject.cjs                 # default roster + a spread of gifts
node tools/inject.cjs alice bob carol # custom viewers
```

Equivalently, use Tikora's **Gift Gallery → Inject** or **Actions & Events → Simulator**. Debug
events are built by the relay and broadcast to every client, so the game reacts exactly as it would
to real viewers. Watch the game log for `[MarbleRoyale] join: …` / `effect '…'`.

## Troubleshooting

- **`unauthorized` then constant reconnect** — wrong/missing `gk_…` key. Copy it fresh from the hub.
- **Connects then instantly drops** — a `WebSocketPeer` buffer too small for the huge catalog
  `hello`. We set 8 MB in `tikora_hub.gd`; keep it.
- **Events arrive but no effects** — effects need a mapping for this game *and* an authenticated
  connection (key). Broadcast events arrive without a key; effects do not.
- **Relay not running** — start Tikora; watch for `[RELAY] Listening on ws://127.0.0.1:27016/`.
