# Architecture

## Overview

Fish Gamble Game is a server-authoritative multiplayer game. The server validates every game action; clients handle input and rendering only.

```
Browser/Desktop Client          Linux Server (Docker)
──────────────────────          ─────────────────────
LoginScreen.tscn                World.tscn (headless)
  │ WebSocket (wss://)            │
  └─────────────────────────────► GameServer (autoload)
                                    ├── AuthServer    (SQLite)
                                    ├── FishingServer
                                    ├── ShopServer
                                    └── BlackjackServer
```

## Autoloads (always present, both server and client)

| Autoload | Role |
|---|---|
| `GameManager` | Scene transitions, coin balance, equipped items, signals |
| `NetworkManager` | WebSocket peer setup, multiplayer signals |
| `ItemRegistry` | Loads all `.tres` files at startup into dictionaries |
| `AudioManager` | Music + SFX pool (8 players) |
| `NetAPI` | All RPCs — c2s (client→server) and s2c (server→client) |
| `GameServer` | Session management; instantiates server-only scripts on `init_server()` |

## Multiplayer flow

1. **Server starts:** `Main.gd` detects `--server` → starts WebSocket → calls `GameServer.init_server()` → changes scene to `World.tscn`
2. **Client starts:** `Main.gd` → `LoginScreen.tscn`
3. **Login:** client sends `request_login` RPC → `AuthServer` validates, loads coins + inventory → `notify_login`
4. **World entry:** client changes to `World.tscn` → sends `c2s_world_ready` → server spawns `Player` node → `MultiplayerSpawner` replicates to all peers
5. **Position sync:** each player's `MultiplayerSynchronizer` syncs `position`, `flip_h`, `animation`, `player_name` from authority (owner) to all others

## Server authority model

- Server **never** trusts client-supplied game-state values (coins, fish caught, etc.)
- Clients send **intent** (request_login, c2s_fishing_start, c2s_bj_bet)
- Server validates zone, balance, session state before acting
- Server sends **result** back to the specific peer (rpc_id)

## RPC naming conventions

| Prefix | Direction | Example |
|---|---|---|
| `request_` | client → server (auth) | `request_login` |
| `c2s_` | client → server (gameplay) | `c2s_fishing_start` |
| `notify_` | server → client | `notify_fishing_result` |

## Scene layout

```
Main.tscn (entry point)
├── --server → World.tscn (server-side, headless)
└── --client → LoginScreen.tscn → World.tscn (after login)

World.tscn
├── TileMapLayer        (visual world — painted manually)
├── Zones/
│   ├── DockZone        (Area2D — triggers fishing)
│   ├── ShopZone        (Area2D — triggers shop)
│   └── CasinoZone      (Area2D — triggers blackjack)
├── SpawnPoint          (Marker2D — player start position)
├── Players/            (MultiplayerSpawner watches this)
│   └── {peer_id}       (Player.tscn instances, one per connected player)
└── HUD                 (CanvasLayer — coin counter, zone hints, equipped)
```

## Database schema (SQLite)

```sql
players  (id, username, password_hash, salt, coins, created_at, last_login)
inventory (player_id, item_id, quantity)  -- UNIQUE(player_id, item_id)
```

Password: client SHA-256s the raw password, server re-hashes with a stored salt.
Sessions: in-memory only (Dictionary peer_id → PlayerSession). Players re-authenticate on reconnect.
