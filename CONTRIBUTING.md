# Contributing

Thanks for helping with Brindle. The project is close to a closed beta, so the most useful contributions are focused fixes, clean reproduction notes, and small pull requests that other contributors can understand quickly.

## Source Of Truth

- `docs/SHIP_CHECKLIST.md` is the launch gate. Only put active pre-launch decisions there.
- `docs/RELEASE_NOTES.md` is the completed closed-beta status.
- `docs/PLAYTEST_FEEDBACK.md` is the playtest report and triage workflow.
- `docs/TODO.md` is for deferred backlog and saved implementation notes.

Avoid duplicating the same checklist item across multiple docs. If a bug becomes launch-blocking, promote it into `docs/SHIP_CHECKLIST.md` and link the matching PR.

## Local Setup

Use Godot 4.7.1 and Git LFS. GitHub hosts source and pull requests; `lfs.dudeltron14.win` hosts the LFS objects.

```bash
git lfs install
git lfs pull
```

LFS downloads are public. To add or replace an LFS-tracked asset, ask a maintainer for a Forgejo account on `lfs.dudeltron14.win`; Git Credential Manager will ask you to sign in once when your first push needs LFS write access. Do not add GitHub LFS credentials or use GitHub's LFS storage.

Open `project.godot` in Godot for client work. Server and Web deployment details live in `docs/SETUP.md`.

## Branch And PR Rules

- Use one branch and one pull request per feedback item or bug.
- Target normal feature/fix PRs at `staging`, not `master`.
- `staging` is the shared pre-production branch. Merged changes auto-build the staging Docker images for playtesting.
- Use `staging2` directly when a contributor needs an isolated rapid-iteration lane that will not disturb the main staging environment.
- `master` is production. Only merge `staging` into `master` after the staging web client/server have been tested and signed off.
- Keep PRs small enough to review without guessing what changed.
- Do not mix economy tuning, UI polish, and networking fixes in the same PR.
- Do not commit local databases, temporary exports, or unrelated generated files.
- Include screenshots or server logs when the bug is visual, networked, or hard to reproduce.

## Issue Lifecycle

Keep an issue open after its PR merges into `staging`. Add a comment with the staging commit/PR and apply the `status: staging` label so contributors know it is awaiting QA, not done.

Close the issue only after the tested `staging` change is promoted to `master` and production is verified. If staging testing finds a regression, keep the issue open, update the same comment thread, and fix it on `staging`.

Recommended branch names:

```text
feedback/<short-description>
fix/<short-description>
docs/<short-description>
```

Recommended PR titles:

```text
[Feedback] Fix shop equip state after login
[Fix] Prevent blackjack forfeit from hiding player
[Docs] Add playtest triage workflow
```

## Staging And Release Flow

Use this flow for most work:

```text
1. Create a feature/fix branch from staging.
2. Open a PR into staging.
3. Merge after review.
4. Wait for the Staging GitHub Action to publish :staging images.
5. Pull/recreate the staging containers on the VM.
6. Test https://fishgame-staging.dudeltron14.win against wss://fishserver-staging.dudeltron14.win.
7. When staging is good, open and merge a `staging` → `master` PR for production.
```

For Alex's isolated environment, work directly on `staging2` so every push deploys to that lane:

```text
staging2 branch
  -> commit directly to staging2
  -> staging2 auto-builds :staging2 images
  -> test https://fishgame-staging2.dudeltron14.win against wss://fishserver-staging2.dudeltron14.win
  -> inspect live server logs at https://admin-staging2.dudeltron14.win
  -> when good, PR staging2 into master
  -> after production is confirmed, merge master back into staging
```

Helpful commands:

```bash
git fetch origin
git checkout staging
git pull --ff-only origin staging
git checkout -b feedback/<short-description>
```

For staging2 work, commit directly to the `staging2` branch:

```bash
git fetch origin
git checkout staging2
git pull --ff-only origin staging2
# make the staging2 change directly
git add <changed-files>
git commit -m "fix: short description"
git push origin staging2
```

After a PR merges into `staging`, update the staging VM stack:

```bash
cd ~/fish-game
sudo docker compose -f docker-compose.staging.yml pull
sudo docker compose -f docker-compose.staging.yml up -d
sudo docker compose -f docker-compose.staging.yml ps
```

The same compose file also runs the isolated staging2 services:

```bash
cd ~/fish-game
sudo docker compose -f docker-compose.staging.yml pull game-server-staging2 web-client-staging2 admin-staging2
sudo docker compose -f docker-compose.staging.yml up -d game-server-staging2 web-client-staging2 admin-staging2
sudo docker compose -f docker-compose.staging.yml ps
```

Use `https://admin-staging2.dudeltron14.win` for staging2 troubleshooting. That dashboard is filtered to the staging2 game server and uses a Dozzle username/password instead of Cloudflare Access. The all-server dashboard at `https://admin-servers.dudeltron14.win` includes production, staging, staging2, and Watchtower logs and should be limited to owner/admin users.

Only production release managers should promote a tested branch to master. For Noah's main lane, open a `staging` → `master` PR, verify it has no conflicts, and merge it after review. Do not push directly to `master`.

For Alex's lane, promote `staging2 -> master` only after the staging2 environment has been tested and approved:

```bash
git checkout master
git pull --ff-only origin master
git merge --ff-only origin/staging2
git push origin master
```

After production is confirmed good, sync production back into Noah's staging lane:

```bash
git checkout staging
git pull --ff-only origin staging
git merge origin/master
git push origin staging
```

## Verification

For code or scene changes, run the Godot headless load check before opening a PR:

```powershell
& 'C:\Users\Noah\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --quit
```

For networking changes, also test against the Docker server or clearly say why that was not possible.
