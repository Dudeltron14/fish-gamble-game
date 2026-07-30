# Multiplayer tables

`TableManager` owns reusable table state: table ID, game ID, zone, seats, public seat state, phase, and turn order. Game servers own rules, payouts, and hidden information.

## Add a table

Register it during the game server's `_ready`:

```gdscript
_tables().register_table("poker_harbor_1", "poker", "CasinoZone", 6)
```

Use `watch` when a client opens a table, then `join` only when it takes a seat. `recipients` returns seated players plus spectators. Use `leave` and `unwatch` on close/disconnect. Use `set_phase`, `set_turn_order`, `next_turn_peer`, `set_seat_public`, and `snapshot` for shared public state. Never put hidden cards, seeds, or private inventory in `public` state.

## Blackjack pattern

`BlackjackServer` registers `blackjack_harbor_1`, owns its committed shoe and hand rules, then publishes a snapshot after every public change. The server alone accepts actions from `current_turn_peer` and resolves the dealer once after all seated hands are done.

## Local two-client test

Run `./scripts/play_local_two_clients.ps1`. It starts one local server and two clients, then closes both child processes when the foreground client exits. `./scripts/play_local_client.ps1 -Clients 2` remains equivalent.
