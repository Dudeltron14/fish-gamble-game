# 🎣 Fish & Gamble

A **multiplayer fishing and casino game** built in Godot 4 for a small group of friends.
Fish the island docks, upgrade your gear at the shop, and test your luck at the Blackjack table.
Coin-affecting gameplay is server-authoritative; movement position is server-simulated from client input.

> Runs in-browser at `https://fishgame.dudeltron14.win`.
> Web client and server auto-deploy through GitHub Actions, Docker images, Cloudflare, and Watchtower.

---

![World Overview](docs/screenshots/world.png)

---

## Features

| System | Details |
|---|---|
| 🐟 **Fishing** | 4-stage minigame (Cast → Wait → React → Reel). 17 catchables, synced bobbers, splash VFX, and visible catch popups. |
| 🎰 **Blackjack** | Full server-side state machine. Hit, Stand, Double Down. Dealer follows standard rules (hit <17). Real card sprites with flip reveals. |
| 🏪 **Shop** | Buy and equip rods, bait, and hooks. Live owned count, durability tracking, gear consumption per cast. |
| 🌍 **World** | Pixel-art island. Walk to the Dock, Shop, or Casino — press E to interact. |
| 👤 **Multiplayer** | WebSocket-based. Public clients connect to the official server at `wss://fishserver.dudeltron14.win`. |
| 🔐 **Auth** | Username + password (double-hashed with per-user salt). SQLite persistence. 50 coin starting balance. |
| 🚀 **Auto-deploy** | Push/merge to `staging` publishes `:staging` Docker images for QA. Merge verified `staging` into `master` to publish production `:latest` images. |

---

## Screenshots

| Login | World |
|---|---|
| ![Login screen](docs/screenshots/login.png) | ![World overview](docs/screenshots/world.png) |

| Fishing | Shop | Blackjack |
|---|---|---|
| ![Fishing minigame](docs/screenshots/fishing.png) | ![Fish shop](docs/screenshots/shop.png) | ![Blackjack table](docs/screenshots/blackjack.png) |

---

## Gear & Progression

Players start with a **Starter Rod**, **10 Worm uses**, and **1 Basic Hook** (10 durability).

### Rods
| Rod | Cost | Effect |
|---|---|---|
| Starter Rod | Free | Baseline |
| Angler's Rod | 80c | 1.4× cast speed, 1.5× reel speed, slight rare bonus |
| Master Rod | 250c | 1.8× cast speed, 2.2× reel speed, strong rare bonus |

### Bait (consumed each cast)
| Bait | Cost | Rare % | Legendary % |
|---|---|---|---|
| Worm | 5c | 0% | 0% |
| Glow Grub | 25c | 14% | 1% |
| Magic Bait | 60c | 40% | 15% |

### Hooks (durability depletes each cast)
| Hook | Cost | Durability | Coin bonus |
|---|---|---|---|
| Basic Hook | 15c / free starter | 10 uses | ×1.0 |
| Shiny Lure | 60c | 15 uses | ×1.15 |
| Golden Hook | 120c | 20 uses | ×1.3 |

### Fish
| Catch | Rarity | Coins |
|---|---|---|
| Freshwater Snail | Common | 3c |
| Perch | Common | 9c |
| Tropical Bluegill | Common | 10c |
| Mossback Bass | Common | 12c |
| Largemouth Bass | Uncommon | 20c |
| Red Dock Crab | Uncommon | 20c |
| Silver Shad | Uncommon | 22c |
| Sunset Conch | Uncommon | 18c |
| Pearl Clam | Rare | 49c |
| Golden Trout | Rare | 56c |
| Northern Pike | Rare | 73c |
| Baby Kraken | Legendary | 650c (845c with Golden Hook) |
| Sunken Chest | Legendary | 330c |
| Ancient Key | Legendary | 375c |

Junk catches currently include Old Boot, Tin Can, and Clump of Seaweed for 0c.

---

## Quick Start (Playing)

> **Requires [Git LFS](https://git-lfs.com)** — large assets such as PNGs, audio, and native binaries are stored in LFS.
> Install it once, then run `git lfs install`:
> - macOS: `brew install git-lfs`
> - Arch Linux: `pacman -S git-lfs`
> - Windows: `winget install GitHub.GitLFS` or install [Git for Windows](https://gitforwindows.org)
> - Others: see [git-lfs.com](https://git-lfs.com)

```bash
git clone https://github.com/Dudeltron14/fish-gamble-game.git
cd fish-gamble-game
git lfs pull
```

1. To play the latest deployed Web build, open `https://fishgame.dudeltron14.win`
2. Register or log in from the main menu; the client connects to `wss://fishserver.dudeltron14.win`.
3. For local development, open **Godot 4.6.x**, import `project.godot`, and press **Play** to run the client.
4. Run a dedicated server separately when testing server changes locally.

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
# On your VPS — pulls the latest server + Web client images and starts with auto-updates
docker compose up -d
```

The Compose stack runs:

- `game-server` from `ghcr.io/dudeltron14/fish-gamble-game:latest`
- `web-client` from `ghcr.io/dudeltron14/fish-gamble-game-web:latest`
- `watchtower` for automatic image updates

SQLite database persists in `./data/` on the host.
Watchtower checks for new images every 5 minutes and updates automatically.

The current public routes are `https://fishgame.dudeltron14.win` for the Web client and `wss://fishserver.dudeltron14.win` for the game server. See [docs/SETUP.md](docs/SETUP.md) for the full deployment guide.

---

## Deploying And Releasing

Use `staging` as the shared pre-production branch. Feature branches should be reviewed and merged into `staging` first. Every push to `staging` builds and pushes fresh `:staging` Docker images for the game server and Web client. The staging VM stack runs those images on separate ports and a separate database.

When staging has been playtested and signed off, merge `staging` into `master`. Every push to `master` builds and pushes production `:latest` Docker images. Watchtower on the VPS should pick production images up automatically.

Deployment flow:

```text
feature/fix branch
  -> pull request into staging
  -> staging auto-builds ghcr.io/...:staging
  -> test https://fishgame-staging.dudeltron14.win
  -> merge staging into master when production-ready
  -> production auto-builds ghcr.io/...:latest
  -> test https://fishgame.dudeltron14.win
```

Use a version tag when you also want a GitHub Release with attached Web export files:

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will:
1. Export Linux server binary + Web client (Godot CI)
2. Build and push Docker images to `ghcr.io/dudeltron14/fish-gamble-game` and `ghcr.io/dudeltron14/fish-gamble-game-web`
3. Publish `:staging` from the `staging` branch or `:latest` from `master`
4. Deploy the Web client to Cloudflare Pages when the Cloudflare secrets are configured
5. Attach Web export files to the GitHub Release page for version tags
6. Watchtower picks up new Docker images on the VPS within 5 minutes

---

## Contributing And Playtesting

New contributors should start with [CONTRIBUTING.md](CONTRIBUTING.md). Use one branch and one pull request per feedback item or bug so active fixes stay easy to review. Target normal feature/fix PRs at `staging`, not `master`; `master` is for production releases after staging passes.

Playtester reports should follow [docs/PLAYTEST_FEEDBACK.md](docs/PLAYTEST_FEEDBACK.md). Launch-blocking findings belong in [docs/SHIP_CHECKLIST.md](docs/SHIP_CHECKLIST.md); completed closed-beta status lives in [docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md).

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
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contributor setup, branch naming, PR expectations, and verification checklist |
| [PLAYTEST_FEEDBACK.md](docs/PLAYTEST_FEEDBACK.md) | Playtester report template and triage flow for one-feedback-item-per-PR fixes |
| [FISHING.md](docs/FISHING.md) | Complete fishing system reference — every value, formula, and mechanic |
| [SHIP_CHECKLIST.md](docs/SHIP_CHECKLIST.md) | Current launch gate and deferred scope decisions |
| [RELEASE_NOTES.md](docs/RELEASE_NOTES.md) | Launch-candidate completed work and current scope |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Multiplayer flow, server authority model, RPC conventions, DB schema |
| [FRAMEWORKS.md](docs/FRAMEWORKS.md) | How to add fish, rods, bait, tackle, and casino games |
| [SETUP.md](docs/SETUP.md) | Collaborator quickstart, Docker deploy, Nginx config |
| [TODO.md](docs/TODO.md) | Non-release backlog and saved implementation notes |

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
