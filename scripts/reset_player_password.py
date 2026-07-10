#!/usr/bin/env python3
"""Reset a Fish Gamble Game player password without touching gameplay data."""

from __future__ import annotations

import argparse
import hashlib
import secrets
import shutil
import sqlite3
from datetime import datetime
from pathlib import Path


def client_hash(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def server_hash(password: str, salt: str) -> str:
    return hashlib.sha256((client_hash(password) + salt).encode("utf-8")).hexdigest()


def backup_db(db_path: Path) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = db_path.with_name(f"{db_path.name}.backup-{timestamp}")
    shutil.copy2(db_path, backup_path)
    return backup_path


def reset_password(db_path: Path, username: str, password: str) -> int:
    salt = secrets.token_hex(16)
    password_hash = server_hash(password, salt)
    with sqlite3.connect(db_path) as db:
        cursor = db.execute(
            "UPDATE players SET password_hash = ?, salt = ? WHERE username = ?",
            (password_hash, salt, username),
        )
        db.commit()
        return cursor.rowcount


def list_players(db_path: Path) -> None:
    with sqlite3.connect(db_path) as db:
        rows = db.execute("SELECT username, coins FROM players ORDER BY username").fetchall()
    if not rows:
        print("No players found.")
        return
    for username, coins in rows:
        print(f"{username}\tcoins={coins}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reset a player password in data/players.db while preserving inventory and balance."
    )
    parser.add_argument("username", nargs="?", help="Player username to reset.")
    parser.add_argument("password", nargs="?", help="New password. If omitted, a temporary password is generated.")
    parser.add_argument("--db", default="data/players.db", help="Path to players.db. Default: data/players.db")
    parser.add_argument("--no-backup", action="store_true", help="Do not create a timestamped DB backup first.")
    parser.add_argument("--list", action="store_true", help="List players and exit.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    db_path = Path(args.db)
    if not db_path.exists():
        print(f"ERROR: database not found: {db_path}")
        return 2

    if args.list:
        list_players(db_path)
        return 0

    if not args.username:
        print("ERROR: username is required unless --list is used.")
        return 2

    password = args.password or f"Fish-{secrets.token_hex(9)}"
    if not args.no_backup:
        backup_path = backup_db(db_path)
        print(f"Backup created: {backup_path}")

    rows = reset_password(db_path, args.username, password)
    if rows != 1:
        print(f"ERROR: updated rows={rows}; player '{args.username}' was not found.")
        return 1

    print(f"Password reset for: {args.username}")
    print(f"New password: {password}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
