---
name: manic-emu
description: See, upload, remove and sync games in the Manic EMU iOS emulator app over Wi-Fi. Use when the user mentions Manic EMU, or asks what games are on their iPhone/iPad emulator, to put ROMs on it, or to remove games from it. Never use a browser for this.
---

# Manic EMU over Wi-Fi

Manic EMU runs a small web server on the phone (port 6969) while its WiFi import is on. Drive it
with the bundled script (Python 3.8+, no packages needed):

```
python "<this skill folder>/manic_emu.py" [--host URL] <command>
```

**Don't ask for the address first.** The script finds the phone on the local network by itself and
remembers it. If it exits with "not found", ask the user to open Manic EMU, go to the **Import** tab,
turn on **WiFi** and keep the app open, then retry. Only if it still fails, ask for the address shown
under WiFi (for example `192.168.1.20:6969`) and pass `--host http://192.168.1.20:6969`.

| Command | Does |
|---|---|
| `library [--platform P] [--json]` | List games: platform, size, name, file name, id |
| `info GAME` | Details: size, import date, last played, play time, save, save states, cheats |
| `update GAME [--name N] [--sound on\|off] [--haptic H] [--orientation O]` | Rename a game or change its settings |
| `find-game QUERY` | Search the library by name |
| `put FILE...` | Upload files. The app imports them into the library straight away |
| `remove GAME... [--yes]` | Remove games by name, file name or id. Without `--yes` it only shows what would go |
| `sync DIR [--platform P] [--ext .zip] [--delete] [--yes]` | Upload files in DIR the library doesn't have. Dry run without `--yes` |
| `pending` / `cancel NAME...` | Uploads not yet imported, and cancelling them |
| `find` | Print the phone's address |

Platform ids are the app's own, such as `nes`, `snes`, `gb`, `gbc`, `gba`, `ds`, `3ds`, `n64`, `md`,
`ps1`, `psp`, `arcade`. `library` shows the ids in use.

## Removing games

- Removing a game deletes its ROM, saves, save states and cheats from the phone, the same as
  Remove Game in the app. It can't be undone. Run `remove` without `--yes` first, show the user the
  list, and add `--yes` only after they confirm.
- If a name matches more than one game, nothing is removed. Use the file name or id from `library`.
- A game that's being played on the phone isn't removed. Ask the user to close it and retry.
- With iCloud sync on, the removal syncs to the user's other devices too.

## Updating games

- `--name` changes the name shown in the app. The ROM file keeps its name.
- `--haptic` is the vibration when on-screen buttons are pressed. `--orientation` locks the game screen.
- A game that's being played can't be updated. Ask the user to close it and retry.

## Syncing a folder

- Matching is by file name without the extension, so `Tetris.gb` locally matches `Tetris.gb` in the
  library. Games the app renamed on import (for example ROMs it unzipped) may show as missing.
- `--delete` also removes library games of `--platform` that aren't in the folder. It needs
  `--platform`, so other platforms are never touched. Show the dry run and get a yes first.
- Big uploads take a while: run the real sync in the background.

## Raw API

For anything the script doesn't cover:

- `GET /library[?platform=gba]`: JSON array of `{id, name, fileName, platform, platformName, size, importDate, lastPlayed,
  playTimeSeconds, hasSave, saveStates, cheats}`. `size` and `lastPlayed` are left out when unknown.
- `POST /library/delete` form `id=ID[,ID...]` with header `X-Manic-EMU: 1`: returns
  `{deleted: [{id, name}], notFound, inUse, failed}`.
- `GET /list?path=/`, `POST /upload` (multipart `path`, `files[]`), `POST /delete` `path=`: the transfer
  folder, which only holds uploads until the app imports them.
- `POST /library/update` form `id=ID` plus any of `name=`, `sound=true|false`,
  `haptic=off|soft|light|medium|heavy|rigid`, `orientation=auto|portrait|landscape`, with the same
  header: returns the updated game. Listings include `sound`, `haptic` and `orientation` too.
- From Git Bash, set `MSYS_NO_PATHCONV=1` so `/` paths aren't rewritten.
