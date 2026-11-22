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
| `put FILE... [--platform P] [--bulk]` | Upload files. The app imports them into the library straight away |
| `remove GAME... [--yes]` | Remove games by name, file name or id. Without `--yes` it only shows what would go |
| `sync DIR [--platform P] [--ext .zip] [--bulk] [--delete] [--yes]` | Upload files in DIR the library doesn't have. Dry run without `--yes` |
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

## Choosing the platform

Pass `--platform` to `put` and `sync` whenever you know the platform. The files then import as that
platform instead of one the app guesses from the extension, and the app doesn't stop to ask on the phone:

- Extensions several platforms share (`.bin`, `.iso`, `.chd`, `.cue`, `.zip` and others) import as the
  platform you gave.
- Archives that platform runs zipped (arcade, DOS, C64, Amiga) stay zipped, without the ZIP File
  Handling dialog. Always use `--platform arcade` for MAME zips: builds made from the public source
  can't look MAME titles up, so without it every zip stops on that dialog.
- A file the platform doesn't use is rejected with the reason. That includes zipped ROMs for platforms
  that don't run zips (a `.zip` for `gba`, say): upload the ROM itself, or leave out `--platform`.

## Uploading many files

Pass `--bulk` when uploading more than a handful of files. Without it every file gets its own
"import successful" alert on the phone, and errors, the platform picker and the ZIP File Handling
dialog each wait for a tap. With `--bulk` the phone shows nothing: games import quietly, cover art is
still looked up in the background, and zips the app would have asked about are imported as they are.
Failures aren't reported anywhere, so check `library` afterwards. Games whose platform the app can't
tell import as unknown, so pass `--platform` too when you know it.

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
- `POST /library/upload` multipart `files[]` plus optional `platform=ID` and `bulk=1`, with the same
  header: saves and imports the files as that platform, without alerts when `bulk=1`. Returns
  `{accepted: [fileName], rejected: [{fileName, error}]}` before the import finishes. An unknown id
  returns 400 with the list of known ids.
- From Git Bash, set `MSYS_NO_PATHCONV=1` so `/` paths aren't rewritten.
