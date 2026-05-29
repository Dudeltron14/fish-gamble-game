# godot-sqlite Installation

AuthServer.gd requires the godot-sqlite GDExtension.

1. Go to: https://github.com/2shady4u/godot-sqlite/releases
2. Download the release matching your Godot version (4.x)
3. Extract the contents into this folder (addons/godot-sqlite/)
   - You should end up with: addons/godot-sqlite/godot_sqlite.gdextension
     and the platform binaries (win64, linux, etc.)
4. Restart Godot — the SQLite class will appear in ClassDB

The server will print an error on startup if the extension is missing.
