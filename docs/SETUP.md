# Fish Gamble Game — Setup Guide

## Collaborator Quickstart (5 steps)

```bash
git clone https://github.com/Dudeltron14/fish-gamble-game.git
cd fish-gamble-game
git lfs pull                        # downloads all PNG/audio assets
```
1. Open Godot 4, import `project.godot`
2. Hit **Run** — game starts in client mode and uses the official deployed server route by default: `wss://fishserver.dudeltron14.win`.
3. For most playtesting, use the public Web client at `https://fishgame.dudeltron14.win`.

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

## Local Export Checks

GitHub Actions exports with the Linux Godot CI image, which includes export templates. Local exports need matching templates installed for the local Godot version first.

Godot's command-line export form is:

```bash
godot --path /path/to/project --export-release "Preset Name" output/path
```

On Windows, prefer the console executable so export errors are visible:

```powershell
& "C:/Users/Noah/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe" --headless --path . --export-release "Linux" export/server/FishGambleGame.x86_64
& "C:/Users/Noah/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe" --headless --path . --export-release "Web" export/web/index.html
```

If this fails with missing files under `AppData/Roaming/Godot/export_templates/<version>.stable`, install export templates in Godot via:

```text
Editor -> Manage Export Templates -> Download and Install
```

The target directory must exist before export. Output paths are resolved relative to the folder containing `project.godot`, not necessarily the shell's current directory.

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

## Server Operations Runbook

Run these from the directory that contains `docker-compose.yml`, usually:

```bash
cd ~/fish-game
```

Use `sudo docker ...` if your user is not in the Docker group.

### Check Server Health

```bash
docker compose ps
docker compose images
docker compose logs --tail=100 game-server
docker compose logs --tail=100 watchtower
```

Expected:

- `game-server` is `Up` and publishes `0.0.0.0:7070->7070/tcp`.
- `watchtower` is `Up` / healthy.
- `game-server` image is `ghcr.io/dudeltron14/fish-gamble-game:latest`.

### Follow Live Logs

```bash
docker compose logs -f game-server
```

Useful when testing login, register, world spawn, and fishing. Server-side warnings such as login success, world-ready, and spawn messages should appear when clients connect.

### Manual Update

Watchtower should update automatically, but this forces an update immediately:

```bash
docker compose pull game-server
docker compose up -d --force-recreate game-server
docker compose ps
docker compose logs --tail=100 game-server
```

### Backup Player Database

Back up `data/players.db` before risky deploys or schema changes:

```bash
mkdir -p backups
cp data/players.db "backups/players-$(date +%Y%m%d-%H%M%S).db"
ls -lh backups
```

If the database file is owned by root because Docker created it, use:

```bash
sudo cp data/players.db "backups/players-$(date +%Y%m%d-%H%M%S).db"
sudo chown "$USER:$USER" backups/*.db
```

### Reset A Player Password

This keeps the player's coins, inventory, equipped gear, and hook durability. It only updates the password hash and salt in `players.db`.

Use the reusable ops script on the VM:

```bash
cd ~/fish-game
sudo python3 scripts/reset_player_password.py doodle
```

That creates a timestamped backup beside `data/players.db`, generates a temporary password, and prints it once.

Set a specific password instead:

```bash
cd ~/fish-game
sudo python3 scripts/reset_player_password.py doodle "new-password-here"
```

List existing usernames:

```bash
cd ~/fish-game
sudo python3 scripts/reset_player_password.py --list
```

If you only have the Docker deployment folder on the VM and not the repo scripts, fetch the current repo or copy `scripts/reset_player_password.py` into that folder. The script defaults to `data/players.db`, matching the Docker Compose volume.

The exported game server also supports a one-off reset command after the latest image has deployed:

Generate a temporary password:

```bash
cd ~/fish-game
sudo docker compose run --rm --no-deps --entrypoint ./FishGambleGame.x86_64 game-server --headless -- --reset-password doodle
```

The command prints the temporary password once.

Set a specific password instead:

```bash
cd ~/fish-game
sudo docker compose run --rm --no-deps --entrypoint ./FishGambleGame.x86_64 game-server --headless -- --reset-password doodle "new-password-here"
```

If the live server is running, this one-off admin container uses the same `./data:/app/data` volume and exits after updating the database.

### Restore Player Database

Stop the game server before restoring:

```bash
docker compose stop game-server
cp backups/players-YYYYMMDD-HHMMSS.db data/players.db
docker compose up -d game-server
docker compose logs --tail=100 game-server
```

Use `sudo` for the copy if `data/players.db` is root-owned.

### Pin Or Roll Back The Server Image

Tagged releases are pushed as both `latest` and the tag name, for example `v1.0.0`.

To pin the server to a known tag, edit `docker-compose.yml`:

```yaml
image: ghcr.io/dudeltron14/fish-gamble-game:v1.0.0
```

Then apply it:

```bash
docker compose pull game-server
docker compose up -d --force-recreate game-server
docker compose ps
```

Switch back to automatic latest updates by changing the image back to:

```yaml
image: ghcr.io/dudeltron14/fish-gamble-game:latest
```

### Cloudflare Tunnel Checks

The current tunnel route should point:

```text
fishserver.dudeltron14.win -> http://172.17.0.1:7070
```

Check the tunnel container logs:

```bash
docker logs <cloudflared-container-name> --tail=100
```

If Cloudflare logs say it cannot resolve `game-server`, the tunnel container is not on the Compose network that provides that DNS name. Use `http://172.17.0.1:7070` unless the tunnel is intentionally moved into the same Compose network as `game-server`.

---

## Cloudflare Tunnel WSS Route

The current deployed game route is:

```text
wss://fishserver.dudeltron14.win
```

Cloudflare Tunnel should route that hostname to the Docker-published game server:

```text
http://172.17.0.1:7070
```

Use the host bridge address above when `cloudflared` is running in its own Docker container. Using `http://game-server:7070` only works if the tunnel container shares the same Docker Compose network and service DNS.

Quick checks:

```bash
docker compose ps
docker compose logs -f game-server
docker logs <cloudflared-container-name> --tail=100
```

From a client machine, a successful WebSocket test to `wss://fishserver.dudeltron14.win` confirms Cloudflare can reach the origin and the Godot server accepts WebSocket traffic.

---

## Proxmox / Docker Web Client

The intended public browser client is:

```text
https://fishgame.dudeltron14.win
```

Use the `web-client` Docker service for the static Godot Web export. The Linux Docker game server remains separate at `wss://fishserver.dudeltron14.win`.

GitHub Actions publishes two GHCR images on every push to `master`:

```text
ghcr.io/dudeltron14/fish-gamble-game:latest
ghcr.io/dudeltron14/fish-gamble-game-web:latest
```

On the Proxmox Linux VM, update `docker-compose.yml` so it has both services:

```yaml
services:
  game-server:
    image: ghcr.io/dudeltron14/fish-gamble-game:latest
    restart: unless-stopped
    ports:
      - "7070:7070"
    volumes:
      - ./data:/app/data
    environment:
      - GODOT_HEADLESS=1

  web-client:
    image: ghcr.io/dudeltron14/fish-gamble-game-web:latest
    restart: unless-stopped
    ports:
      - "8080:80"

  watchtower:
    image: containrrr/watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --interval 300 --cleanup
```

Pull and start:

```bash
cd ~/fish-game
sudo docker compose pull
sudo docker compose up -d
sudo docker compose ps
```

Local VM checks:

```bash
curl -I http://localhost:8080
curl -I http://localhost:8080/index.pck
```

Expected headers include:

```text
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Cloudflare Tunnel public hostname routes:

```text
fishserver.dudeltron14.win -> http://172.17.0.1:7070
fishgame.dudeltron14.win   -> http://172.17.0.1:8080
```

Use the host bridge address above when `cloudflared` is running in its own Docker container. If `cloudflared` is moved into the same Compose network, the web route can instead target `http://web-client:80`.

Quick verification after a deploy:

```text
https://fishgame.dudeltron14.win
wss://fishserver.dudeltron14.win
```

Open the web client, then register or log in. The page should load the latest Web export and connect over WSS to the Docker game server.

If the web page loads but networking fails, verify the game server separately with:

```text
wss://fishserver.dudeltron14.win
```

---

## Staging Server

Use staging to test PR branches before anything reaches production `master`.

Staging uses separate Docker images, ports, database, and Cloudflare hostnames:

```text
Server image: ghcr.io/dudeltron14/fish-gamble-game:staging
Web image:    ghcr.io/dudeltron14/fish-gamble-game-web:staging
Server port:  7071 -> container 7070
Web port:     8081 -> container 80
Database:     ./data-staging/players.db
```

### Build A Branch For Staging

In GitHub:

1. Go to **Actions**.
2. Open the **Staging** workflow.
3. Click **Run workflow**.
4. Use:

```text
ref: pr-001-002-camera-zoom-blackjack
image_tag: staging
staging_server_url: wss://fishserver-staging.dudeltron14.win
```

The workflow exports the requested ref, patches the Web client to use the staging WSS URL, and pushes `:staging` Docker images to GHCR.

### Start Staging On The VM

From the VM:

```bash
cd ~/fish-game

# after the Staging workflow finishes
sudo docker compose -f docker-compose.staging.yml pull
sudo docker compose -f docker-compose.staging.yml up -d
sudo docker compose -f docker-compose.staging.yml ps
```

Follow staging logs:

```bash
sudo docker compose -f docker-compose.staging.yml logs -f game-server-staging
```

Local VM checks:

```bash
curl -I http://localhost:8081
curl -I http://localhost:8081/index.pck
```

### Cloudflare Tunnel Routes

Add two public hostname routes to the existing Cloudflare Tunnel:

```text
fishserver-staging.dudeltron14.win -> http://172.17.0.1:7071
fishgame-staging.dudeltron14.win   -> http://172.17.0.1:8081
```

Then test:

```text
https://fishgame-staging.dudeltron14.win
wss://fishserver-staging.dudeltron14.win
```

### Promote After Staging Passes

When staging passes, merge the PR to `master`. Production will then build and deploy the normal `:latest` images.

If staging fails, leave `master` alone, fix the PR branch, rerun the **Staging** workflow, and pull staging again.

---

## Optional Nginx Config (WSS proxy + web client hosting)

Cloudflare Tunnel is the active deployment path. Keep this Nginx example only if we later host the Web client and `/ws` proxy directly on the VPS.

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
2. Build and push Docker images to `ghcr.io/dudeltron14/fish-gamble-game` and `ghcr.io/dudeltron14/fish-gamble-game-web`
3. Optionally deploy the Web client to Cloudflare Pages if Cloudflare secrets are configured
4. Attach web export files to the GitHub Release for tagged releases
5. Watchtower on your VPS pulls the new images within 5 minutes

---

## One-Time Setup (before first release)

In Godot editor, create these export presets via **Project → Export**:

| Preset name | Platform | Notes |
|---|---|---|
| `Linux/X11` | Linux | Enable **Dedicated Server** mode |
| `Web` | Web | Leave defaults |

Save — this creates `export_presets.cfg` in the project root. Commit it.
