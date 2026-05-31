# 🎣 Fish & Gamble

A **multiplayer fishing and casino game** built in Godot 4 for a small group of friends.
Fish the island docks, upgrade your gear at the shop, and test your luck at the Blackjack table.
All game logic is server-authoritative — no cheating, just vibes.

> Runs in-browser (WebAssembly) or as a desktop client.
> Server auto-deploys to a Linux VPS via Docker + GitHub Actions.

---

![World Overview](docs/screenshots/world.png)

---

## Features

| System | Details |
|---|---|
| 🐟 **Fishing** | 4-stage minigame (Cast → Wait → React → Reel). Fish difficulty, rarity, and coin value scale with gear. |
| 🎰 **Blackjack** | Full server-side state machine. Hit, Stand, Double Down. Dealer follows standard rules (hit <17). Real card sprites. |
| 🏪 **Shop** | Buy and equip rods, bait, and hooks. Live owned count, durability tracking, gear consumption per cast. |
| 🌍 **World** | Pixel-art island. Walk to the Dock, Shop, or Casino — press E to interact. |
| 👤 **Multiplayer** | WebSocket-based. Server-authoritative. 2–8 players. See other players move around in real time. |
| 🔐 **Auth** | Username + password (double-hashed with per-user salt). SQLite persistence. 50 coin starting balance. |
| 🚀 **Auto-deploy** | Push a `v*.*.*` tag → GitHub Actions exports + builds Docker image → Watchtower auto-pulls on VPS. |

---

## Screenshots

> 📸 **Gameplay screenshots needed** — run the game and capture these:

| File to save | What to capture |
|---|---|
| `docs/screenshots/fishing.png` | Fishing minigame reel in progress (green/red catch bar visible) |
| `docs/screenshots/shop.png` | Shop overlay open showing items with owned counts |
| `docs/screenshots/blackjack.png` | Blackjack table mid-game with cards dealt |
| `docs/screenshots/hud.png` | In-game HUD showing Rod / Bait ×N / Hook N/10 |
| `docs/screenshots/login.png` | Login screen |

Save to `docs/screenshots/` and they'll appear here automatically once added.

---

## Gear & Progression

Players start with a **Starter Rod**, **1 Worm**, and **1 Basic Hook** (10 uses).

### Rods
| Rod | Cost | Effect |
|---|---|---|
| Starter Rod | Free | Baseline |
| Angler's Rod | 80c | 1.4× cast speed, 1.5× reel speed, slight rare bonus |
| Master Rod | 250c | 1.8× cast speed, 2.2× reel speed, strong rare bonus |

### Bait (consumed each cast)
| Bait | Cost | Rare % | Legendary % |
|---|---|---|---|
| Worm | 5c | 7.5% | 0.5% |
| Shiny Lure | 20c | 17% | 3% |
| Magic Bait | 60c | 30% | 15% |

### Hooks (durability depletes each cast)
| Hook | Cost | Durability | Coin bonus |
|---|---|---|---|
| Basic Hook | Free starter | 10 uses | ×1.0 |
| Golden Hook | 120c | 20 uses | ×1.3 |

### Fish
| Fish | Rarity | Coins |
|---|---|---|
| Perch | Common | 8c |
| Largemouth Bass | Uncommon | 20c |
| Golden Trout | Rare | 55c |
| Northern Pike | Rare | 70c |
| Baby Kraken | Legendary | 300c (390c with Golden Hook) |

---

## Quick Start (Playing)

> **Requires [Git LFS](https://git-lfs.com)** — assets (PNG, audio) are stored in LFS.
> Install it once, then run `git lfs install`:
> - macOS: `brew install git-lfs`
> - Arch Linux: `pacman -S git-lfs`
> - Windows: `winget install GitHub.GitLFS` (or bundled with [Git for Windows](https://gitforwindows.org))
> - Others: [git-lfs.com](https://git-lfs.com)

```bash
git clone https://github.com/Dudeltron14/fish-gamble-game.git
git lfs pull
```

1. Open **Godot 4.6.x**, import `project.godot`
2. Press **Play** → click **Host & Play** to start a local server + join instantly
3. To invite a friend on the same network, give them your IP — they enter it in the Server field and click Login (register first)

---

## Running a Dedicated Server

```bash
# Export first: Project → Export → Linux (Dedicated Server)
./FishGambleGame.x86_64 --headless --server

# Custom port
./FishGambleGame.x86_64 --headless --server --port 7070
```

---

## Docker Deployment

```bash
# On your VPS — pulls the latest image and starts with auto-updates
docker compose up -d
```

SQLite database persists in `./data/` on the host.
Watchtower checks for new images every 5 minutes and updates automatically.

See [docs/SETUP.md](docs/SETUP.md) for the full guide including Nginx WSS proxy config.

---

## Releasing a New Version

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will:
1. Export Linux server binary + Web client (Godot CI)
2. Build and push Docker image to `ghcr.io/dudeltron14/fish-gamble-game`
3. Attach web export to the GitHub Release page
4. Watchtower picks it up on the VPS within 5 minutes

---

## Adding Content

All game data lives in `.tres` resource files. **No code changes needed** to add new fish, rods, bait, or hooks.

```
# Add a new fish — just create the file:
src/resources/fish/my_new_fish.tres
```

The `ItemRegistry` autoload picks it up automatically at startup.
See [docs/FRAMEWORKS.md](docs/FRAMEWORKS.md) for the full guide.

---

## Documentation

| Doc | Contents |
|---|---|
| [FISHING.md](docs/FISHING.md) | Complete fishing system reference — every value, formula, and mechanic |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Multiplayer flow, server authority model, RPC conventions, DB schema |
| [FRAMEWORKS.md](docs/FRAMEWORKS.md) | How to add fish, rods, bait, tackle, and casino games |
| [SETUP.md](docs/SETUP.md) | Collaborator quickstart, Docker deploy, Nginx config |
| [TODO.md](docs/TODO.md) | Living task list |

---

## Tech Stack

- **Engine** — Godot 4.6.3
- **Networking** — WebSocket (`WebSocketMultiplayerPeer`), server-authoritative RPC
- **Database** — SQLite via [godot-sqlite](https://github.com/2shady4u/godot-sqlite) GDExtension
- **Assets** — Git LFS (PNG, GIF, audio, DLL)
- **Server** — Docker on Linux VPS, auto-deploy via GitHub Actions + Watchtower
- **Export** — Linux dedicated server + WebAssembly web client

---

## Project Structure

```
src/
├── autoloads/       GameManager, NetworkManager, ItemRegistry, AudioManager, NetAPI, GameServer
├── resources/       items/, fish/, rods/, baits/, tackle/  ← .tres data files
├── scenes/
│   ├── main/        Entry point (routes --server vs client)
│   ├── world/       Island map, zones, player spawning
│   ├── player/      CharacterBody2D + animations + sync
│   ├── fishing/     4-stage fishing minigame
│   ├── ui/          LoginScreen, Shop, HUD
│   └── casino/      Blackjack
└── server/          AuthServer, FishingServer, ShopServer, BlackjackServer, PlayerSession
```

---

*Built with ❤️ for a small group of friends.*
