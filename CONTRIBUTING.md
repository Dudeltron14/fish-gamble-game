# Contributing

Thanks for helping with Fish & Gamble. The project is close to a closed beta, so the most useful contributions are focused fixes, clean reproduction notes, and small pull requests that other contributors can understand quickly.

## Source Of Truth

- `docs/SHIP_CHECKLIST.md` is the launch gate. Only put active pre-launch decisions there.
- `docs/RELEASE_NOTES.md` is the completed closed-beta status.
- `docs/PLAYTEST_FEEDBACK.md` is the playtest report and triage workflow.
- `docs/TODO.md` is for deferred backlog and saved implementation notes.

Avoid duplicating the same checklist item across multiple docs. If a bug becomes launch-blocking, promote it into `docs/SHIP_CHECKLIST.md` and link the matching PR.

## Local Setup

Use Godot 4.6.3 and Git LFS.

```bash
git lfs install
git lfs pull
```

Open `project.godot` in Godot for client work. Server and Web deployment details live in `docs/SETUP.md`.

## Branch And PR Rules

- Use one branch and one pull request per feedback item or bug.
- Keep PRs small enough to review without guessing what changed.
- Do not mix economy tuning, UI polish, and networking fixes in the same PR.
- Do not commit local databases, temporary exports, or unrelated generated files.
- Include screenshots or server logs when the bug is visual, networked, or hard to reproduce.

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

## Verification

For code or scene changes, run the Godot headless load check before opening a PR:

```powershell
& 'C:\Users\Noah\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
```

For networking changes, also test against the Docker server or clearly say why that was not possible.

