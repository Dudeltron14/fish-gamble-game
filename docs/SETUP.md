# Fish Gamble Game — Setup Guide

## Collaborator Quickstart (5 steps)

```bash
git clone https://github.com/Dudeltron14/fish-gamble-game.git
cd fish-gamble-game
git lfs pull                        # downloads all PNG/audio assets
```
1. Open Godot 4, import `project.godot`
2. Hit **Run** — game starts in client mode, connect to server at `localhost:7070`

---

## Running the Server Locally

```bash
# From the Godot editor — run with --server flag:
# Project → Export → Linux/X11 → Export Project → export/server/
./export/server/FishGambleGame.x86_64 --headless --server

# Or with a custom port:
./export/server/FishGambleGame.x86_64 --headless --server --port 7070
```

---

## Docker Deployment (Linux VPS)

**Prerequisites:** Docker + Docker Compose installed on the server.

```bash
# 1. Pull the latest image (or let Watchtower do it automatically)
docker compose pull

# 2. Start server + Watchtower (auto-updates on new releases)
docker compose up -d

# 3. Check logs
docker compose logs -f game-server
```

The SQLite database is persisted in `./data/` on the host — it survives container restarts and image updates.

---

## Nginx Config (WSS proxy + web client hosting)

Add this to your Nginx server block. Replace `yourdomain.com`:

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # WebSocket proxy (game server)
    location /ws {
        proxy_pass http://localhost:7070;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 3600s;
    }

    # Web client (HTML5 export)
    location / {
        root /var/www/fish-game;
        index index.html;
        try_files $uri $uri/ /index.html;

        # Required headers for Godot Web export
        add_header Cross-Origin-Opener-Policy "same-origin";
        add_header Cross-Origin-Embedder-Policy "require-corp";
    }
}
```

> Get a free TLS cert: `certbot --nginx -d yourdomain.com`

---

## Releasing a New Version

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically:
1. Export Linux server binary + Web client (via `barichello/godot-ci:4.6.3`)
2. Build and push Docker image to `ghcr.io/dudeltron14/fish-gamble-game`
3. Attach web export files to the GitHub Release
4. Watchtower on your VPS pulls the new image within 5 minutes

---

## One-Time Setup (before first release)

In Godot editor, create two export presets via **Project → Export**:

| Preset name | Platform | Notes |
|---|---|---|
| `Linux/X11` | Linux | Enable **Dedicated Server** mode |
| `Web` | Web | Leave defaults |

Save — this creates `export_presets.cfg` in the project root. Commit it.
