# Managing your library over Wi-Fi

Manic EMU can run a small web server on your iPhone or iPad. While it's on, a computer on the same
Wi-Fi can upload games, see what's in your library and remove games. You don't need a cable,
iTunes or the Files app.

There are three ways to use it:

| | Good for | Needs |
|---|---|---|
| [Browser](#1-from-a-browser) | Uploading a few games, removing games | Any web browser |
| [Command line](#2-from-the-command-line) | Big uploads, whole folders, arcade sets | Python 3.8 or later |
| [AI agent](#3-with-an-ai-agent) | Asking in plain English | An agent that supports skills, such as Claude Code |

Only upload games you're legally allowed to use. See the [anti-piracy policy](../ANTI_PIRACY.md).

## Turn it on

1. Open Manic EMU and go to the **Import** tab.
2. Turn on **WiFi**. The app shows an address such as `192.168.1.20:6969`.
3. Keep Manic EMU open and in front. iOS pauses the server when the app goes to the background or
   the phone locks.

Your computer must be on the same Wi-Fi network as the phone.

## 1. From a browser

Type the address from the app into a browser on your computer, starting with `http://`
(for example `http://192.168.1.20:6969`).

- **Upload games:** use the upload button, or drag files onto the page. Each file is imported into
  your library as soon as it arrives, and the phone shows the usual import alerts.
- **See your library:** **Games in your library** lists every game with its platform and size.
  Type in the filter box to search by name or platform, and press **Refresh** after changes on the
  phone.
- **Remove a game:** press **Remove** next to it and confirm. This works the same as **Remove Game**
  in the app: the ROM, saves, save states and cheats are deleted from the phone. **It can't be
  undone.**

## 2. From the command line

`skills/manic-emu/manic_emu.py` is a single Python script with no packages to install. Download the
[`skills/manic-emu`](../skills/manic-emu) folder, then run the script from a terminal. Use
`python3` on macOS and Linux, and `python` on Windows.

The script finds the phone on your network by itself and remembers its address for next time.

### Everyday commands

```sh
python3 manic_emu.py library                      # list every game
python3 manic_emu.py library --platform gba       # just one platform
python3 manic_emu.py find-game zelda              # search by name
python3 manic_emu.py info "Tetris"                # size, play time, saves, cheats

python3 manic_emu.py put Tetris.gb Pokemon.gbc    # upload files
python3 manic_emu.py remove "Tetris"              # shows what would be removed
python3 manic_emu.py remove "Tetris" --yes        # actually removes it

python3 manic_emu.py update "Tetris" --name "Tetris DX" --orientation landscape
```

`remove`, and `sync` further down, only show what they would do until you add `--yes`.

### Tell it the platform

Several platforms share file extensions such as `.bin`, `.iso`, `.chd`, `.cue` and `.zip`. Without
help the app guesses, and sometimes stops to ask on the phone. Add `--platform` to put the games on
the right system:

```sh
python3 manic_emu.py put "Crash Bandicoot.chd" --platform ps1
```

Common platform ids are `nes`, `snes`, `gb`, `gbc`, `gba`, `ds`, `3ds`, `n64`, `md`, `ps1`, `psp`
and `arcade`. `library` shows the ids your games use. An unknown id is rejected with the list of
valid ones.

### Upload a whole folder

`sync` uploads only the files your library doesn't already have:

```sh
python3 manic_emu.py sync ~/ROMs/GBA --platform gba          # preview
python3 manic_emu.py sync ~/ROMs/GBA --platform gba --yes    # upload
```

- `--bulk` imports quietly with no alerts on the phone. Use it for more than a handful of files,
  otherwise every game pops up its own "import successful" alert. Cover art is still downloaded.
  Errors aren't shown either, so run `library` afterwards to check.
- `--ext .zip` only looks at files with that extension.
- `--delete` also removes games of that platform that aren't in the folder, so the phone matches
  the folder exactly. It always needs `--platform`, so other platforms are never touched.

### Arcade (MAME) games

Arcade zips need two extra options:

```sh
python3 manic_emu.py sync ~/ROMs/MAME --platform arcade --bulk --names ~/mame/mame.exe --yes
```

- `--platform arcade` keeps each zip as it is, without the phone stopping on the
  **ZIP File Handling** dialog for every game.
- `--names` gives each game its full title (`Metal Slug 3`) instead of its zip name (`mslug3`),
  which also lets cover art search find its box art. Point it at a MAME executable, or at a text
  file saved from `mame -listfull`. Names only apply to games new to your library. Use
  `update --name` for games already there.

### Other commands

| Command | Does |
|---|---|
| `find` | Print the phone's address |
| `pending` | Uploads that haven't been imported yet |
| `cancel NAME...` | Cancel an upload that hasn't been imported |
| `update GAME --sound on\|off` | Turn a game's sound on or off |
| `update GAME --haptic off\|soft\|light\|medium\|heavy\|rigid` | Vibration for on-screen buttons |

Run `python3 manic_emu.py --help`, or `python3 manic_emu.py COMMAND --help`, for every option.

## 3. With an AI agent

The `skills/manic-emu` folder is also a skill for AI agents. With it, an agent such as Claude Code
can run the commands above for you.

1. Turn on WiFi in Manic EMU as described [above](#turn-it-on).
2. Give your agent the skill. In Claude Code, say
   `Install the skill from https://github.com/Manic-EMU/ManicEMU/tree/main/skills/manic-emu`,
   or copy the `manic-emu` folder into `~/.claude/skills/`.
3. Ask it things like:
   - "What games are on my Manic EMU?"
   - "Upload the GBA ROMs in my Downloads folder to Manic EMU"
   - "Remove Pac-Man from Manic EMU"

The agent always shows you which games it would remove and waits for you to confirm.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Manic EMU not found" | Open the **Import** tab with **WiFi** on, keep the app in front, and check both devices are on the same Wi-Fi. If it still fails, pass the address from the app: `--host http://192.168.1.20:6969` |
| It worked, then stopped | The phone locked or Manic EMU went to the background. Bring the app back to the front. |
| A game landed on the wrong platform | Remove it and upload it again with `--platform` |
| Arcade games ask about ZIP handling | Upload them with `--platform arcade` |
| Arcade games have short names and no covers | Upload them with `--names`, or rename them with `update --name` |
| A game can't be removed or updated | It's open on the phone. Close the game and try again. |
| Git Bash on Windows mangles paths | Run `export MSYS_NO_PATHCONV=1` first |

## Is it safe?

- The server only runs while **WiFi** is turned on in the Import tab and Manic EMU is in front.
  Turn it off when you're done.
- Anyone on the same Wi-Fi can open the page while it's running, so only turn it on at home or on
  networks you trust.
- Requests that change your library need a special header, which other websites can't send. A
  page you visit on the internet can't remove or upload games behind your back.
- With iCloud sync on, games you remove are removed from your other devices too.
