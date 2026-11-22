#!/usr/bin/env python3
"""Talk to the Manic EMU iOS app over Wi-Fi: list, upload and remove games.

The app serves this API on port 6969 while its Wi-Fi transfer screen is open:
  GET  /library[?platform=]         games in the library (JSON)
  POST /library/delete id=ID[,ID]   remove games (needs header X-Manic-EMU: 1)
  POST /library/update id=ID name= sound= haptic= orientation=
                                    rename a game or change its settings (same header)
  POST /library/upload (multipart: platform=, bulk=1, files[])
                                    upload and import as that platform, bulk without alerts (same header)
  GET  /list?path=  POST /upload (multipart: path, files[])  POST /delete path=
                                    the transfer folder: uploads waiting to be imported

Without --host or $MANIC_EMU_URL the phone is found by trying the last address that
worked (last_host.txt next to this script), then scanning the local /24 networks.
Python 3.8+, stdlib only.
"""
import argparse, json, os, socket, sys, uuid, urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = 6969
LAST_HOST = os.path.join(HERE, "last_host.txt")
TIMEOUT = 600
AGENT_HEADER = {"X-Manic-EMU": "1"}
host_in_use = None


# ---- finding the phone -------------------------------------------------------------------

def is_manic(host, timeout=2):
    """True if host answers the transfer folder listing (every app version has it)."""
    try:
        with urllib.request.urlopen(host.rstrip("/") + "/list?path=%2F", timeout=timeout) as r:
            return isinstance(json.loads(r.read().decode()), list)
    except Exception:
        return False


def local_ipv4s():
    ips = set()
    try:  # interface that routes outward; connect() on UDP sends nothing
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            ips.add(s.getsockname()[0])
    except OSError:
        pass
    try:
        ips.update(i[4][0] for i in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET))
    except OSError:
        pass
    return sorted(ip for ip in ips if ip.startswith(("10.", "192.168.")) or
                  (ip.startswith("172.") and 16 <= int(ip.split(".")[1]) <= 31))


def _port_open(ip):
    with socket.socket() as s:
        s.settimeout(0.5)
        return ip if s.connect_ex((ip, PORT)) == 0 else None


def scan():
    for own in local_ipv4s():
        base = own.rsplit(".", 1)[0]
        cands = [f"{base}.{i}" for i in range(1, 255) if f"{base}.{i}" != own]
        with ThreadPoolExecutor(128) as ex:
            for ip in filter(None, ex.map(_port_open, cands)):
                url = f"http://{ip}:{PORT}"
                if is_manic(url):
                    return url
    return None


def find_host(verbose=False):
    try:
        with open(LAST_HOST) as f:
            last = f.read().strip()
        if last and is_manic(last):
            return last
    except OSError:
        pass
    if verbose:
        print("scanning the local network for Manic EMU...", file=sys.stderr)
    url = scan()
    if url:
        try:
            with open(LAST_HOST, "w") as f:
                f.write(url + "\n")
        except OSError:
            pass
    return url


# ---- HTTP --------------------------------------------------------------------------------

def _url(host, ep, **q):
    q = {k: v for k, v in q.items() if v is not None}
    return host.rstrip("/") + "/" + ep + ("?" + urllib.parse.urlencode(q) if q else "")


def _get_json(host, ep, **q):
    with urllib.request.urlopen(_url(host, ep, **q), timeout=60) as r:
        return json.loads(r.read().decode())


def _post_form(host, ep, data, headers=None):
    req = urllib.request.Request(_url(host, ep), data=urllib.parse.urlencode(data).encode(),
                                 method="POST", headers=headers or {})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        body = r.read().decode()
        return json.loads(body) if body else {}


def norm_dir(d):
    d = "/" + d.strip("/")
    return d if d == "/" else d + "/"


def library(host, platform=None):
    return _get_json(host, "library", platform=platform.lower() if platform else None)


def pending(host):
    return [e for e in _get_json(host, "list", path="/") if not e["path"].endswith("/")]


def remove_games(host, ids):
    return _post_form(host, "library/delete", {"id": ",".join(ids)}, AGENT_HEADER)


def update_game(host, game_id, fields):
    return _post_form(host, "library/update", {"id": game_id, **fields}, AGENT_HEADER)


def load_names(source):
    """Map ROM name -> full title from `mame -listfull`. `source` is a MAME executable, or a text file
    holding that command's output (lines like: mslug3  "Metal Slug 3 (NGM-2560)")."""
    if os.path.splitext(source)[1].lower() == ".exe" or (os.name != "nt" and os.access(source, os.X_OK)):
        import subprocess
        exe = os.path.abspath(source)  # Windows won't start a relative path written with /
        text = subprocess.run([exe, "-listfull"], capture_output=True, text=True, encoding="utf-8",
                              errors="replace", check=True, cwd=os.path.dirname(exe)).stdout
    else:
        with open(source, encoding="utf-8", errors="replace") as f:
            text = f.read()
    names = {}
    for line in text.splitlines():
        rom, _, rest = line.strip().partition(" ")
        rest = rest.strip()
        if rom and rest.startswith('"') and rest.endswith('"') and len(rest) > 1:
            names[rom.lower()] = rest[1:-1]
    return names


def upload(host, local_file, platform=None, bulk=False, title=None, remote_dir="/"):
    """Upload one file. With a platform, bulk or title it goes through /library/upload: a platform
    imports it as that platform (arcade zips skip the app's ZIP File Handling dialog), bulk shows
    nothing on the phone, and title becomes the name shown in the library and searched for cover art.
    Otherwise it uses /upload and the app guesses the platform and shows its usual alerts."""
    platform = platform.lower() if platform else None
    hinted = platform is not None or bulk or title is not None
    boundary = uuid.uuid4().hex
    name = os.path.basename(local_file).replace('"', "_")
    size = os.path.getsize(local_file)
    fields = ({"platform": platform, "bulk": "1" if bulk else None, "name": title} if hinted
              else {"path": norm_dir(remote_dir)})
    head = "".join(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n"
                   f"Content-Type: text/plain; charset=utf-8\r\n\r\n{v}\r\n"
                   for k, v in fields.items() if v is not None)
    head = (
        head +
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"files[]\"; filename=\"{name}\"\r\n"
        f"Content-Type: application/octet-stream\r\n\r\n"
    ).encode()
    tail = f"\r\n--{boundary}--\r\n".encode()

    def gen():
        yield head
        with open(local_file, "rb") as f:
            while chunk := f.read(1 << 20):
                yield chunk
        yield tail

    req = urllib.request.Request(_url(host, "library/upload" if hinted else "upload"), data=gen(), method="POST",
                                 headers=AGENT_HEADER if hinted else {})
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    req.add_header("Content-Length", str(len(head) + size + len(tail)))
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            r.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        if hinted and e.code in (404, 405):
            raise RuntimeError("this app version has no /library/upload; update Manic EMU, "
                               "or upload without --platform and --bulk") from None
        raise RuntimeError(f"Manic EMU returned {e.code}: {body}") from None


# ---- commands ----------------------------------------------------------------------------

def stem(name):
    return os.path.splitext(name)[0].lower()


def resolve(games, query):
    """Games matching an id, a file name, or a name (exact, else unique substring)."""
    q = query.lower()
    for key in ("id", "fileName", "name"):
        hits = [g for g in games if g[key].lower() == q]
        if hits:
            return hits
    hits = [g for g in games if stem(g["fileName"]) == stem(query)]
    return hits or [g for g in games if q in g["name"].lower() or q in g["fileName"].lower()]


def fmt_size(n):
    if n is None:
        return ""
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1000 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1000


def print_games(games):
    for g in games:
        print(f"{g['platform']:<10} {fmt_size(g.get('size')):>9}  {g['name']}  [{g['fileName']}]  id={g['id']}")
    print(f"{len(games)} game(s)")


def fmt_duration(seconds):
    if not seconds:
        return "never"
    h, m = divmod(seconds // 60, 60)
    return f"{h}h {m}m" if h else f"{m}m"


def print_info(games):
    for g in games:
        print(f"{g['name']}  ({g.get('platformName') or g['platform']})")
        print(f"  file:        {g['fileName']}  {fmt_size(g.get('size'))}")
        print(f"  id:          {g['id']}")
        print(f"  imported:    {g.get('importDate', '')[:10]}")
        print(f"  last played: {(g.get('lastPlayed') or 'never')[:10]}")
        print(f"  play time:   {fmt_duration(g.get('playTimeSeconds'))}")
        print(f"  save:        {'yes' if g.get('hasSave') else 'no'}, "
              f"{g.get('saveStates', 0)} save state(s), {g.get('cheats', 0)} cheat(s)")
        if "sound" in g:
            print(f"  settings:    sound {'on' if g['sound'] else 'off'}, haptic {g.get('haptic')}, "
                  f"orientation {g.get('orientation')}")


def cmd_remove(host, queries, platform, yes):
    games = library(host, platform)
    chosen, problems = {}, []
    for q in queries:
        hits = resolve(games, q)
        if not hits:
            problems.append(f"no game matches {q!r}")
        elif len(hits) > 1:
            problems.append(f"{q!r} matches {len(hits)} games: " + ", ".join(f"{g['name']} ({g['platform']}, id={g['id']})" for g in hits[:10]))
        else:
            chosen[hits[0]["id"]] = hits[0]
    if problems:
        print("\n".join(problems), file=sys.stderr)
        print("nothing removed: use an exact name, file name or id, or add --platform", file=sys.stderr)
        return 1
    print("will remove (ROM, saves, save states and cheats):")
    print_games(list(chosen.values()))
    if not yes:
        print("dry run: pass --yes to remove them")
        return 0
    return report(remove_games(host, list(chosen)))


def report(r):
    for g in r.get("deleted", []):
        print(f"removed {g['name']}")
    for i in r.get("inUse", []):
        print(f"not removed, being played on the phone: {i}")
    for i in r.get("notFound", []):
        print(f"not found: {i}")
    for i in r.get("failed", []):
        print(f"failed: {i}")
    return 1 if r.get("failed") or r.get("inUse") else 0


def cmd_update(host, query, platform, fields):
    if not fields:
        print("nothing to update: pass --name, --sound, --haptic or --orientation", file=sys.stderr)
        return 1
    hits = resolve(library(host, platform), query)
    if len(hits) != 1:
        print(f"no game matches {query!r}" if not hits else
              f"{query!r} matches {len(hits)} games: " + ", ".join(f"{g['name']} ({g['platform']}, id={g['id']})" for g in hits[:10]),
              file=sys.stderr)
        return 1
    print_info([update_game(host, hits[0]["id"], fields)])
    return 0


def cmd_sync(host, local_dir, platform, exts, delete_extra, yes, bulk=False, names=None):
    lib = library(host, platform)
    have = {stem(g["fileName"]) for g in library(host)} | {stem(e["name"]) for e in pending(host)}
    local = {}
    for n in sorted(os.listdir(local_dir)):
        p = os.path.join(local_dir, n)
        if os.path.isfile(p) and not n.startswith(".") and (not exts or os.path.splitext(n)[1].lower() in exts):
            local[stem(n)] = p
    to_up = [p for s, p in local.items() if s not in have]
    to_del = [g for g in lib if stem(g["fileName"]) not in local] if delete_extra else []
    print(f"local={len(local)} library={len(lib)} upload={len(to_up)} remove={len(to_del)}")
    names = names or {}
    for p in to_up:
        title = names.get(stem(os.path.basename(p)))
        print(f"  upload {os.path.basename(p)} ({os.path.getsize(p) / 1e6:.1f} MB)" + (f" as {title!r}" if title else ""))
    for g in to_del:
        print(f"  remove {g['name']} [{g['fileName']}]")
    if not yes:
        print("dry run: pass --yes to apply")
        return 0
    failed = []
    for i, p in enumerate(to_up, 1):
        print(f"[{i}/{len(to_up)}] upload {os.path.basename(p)}", flush=True)
        try:
            upload(host, p, platform, bulk, names.get(stem(os.path.basename(p))))
        except Exception as e:
            print(f"  FAILED: {e}", flush=True)
            failed.append(os.path.basename(p))
    rc = report(remove_games(host, [g["id"] for g in to_del])) if to_del else 0
    if failed:
        print("failed uploads: " + ", ".join(failed))
        return 1
    return rc


NAMES_HELP = ("MAME executable, or a file of its -listfull output: new arcade games get their full "
              "titles, which cover art search looks for")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", default=os.environ.get("MANIC_EMU_URL"),
                    help="server URL, e.g. http://192.168.1.20:6969 (default: $MANIC_EMU_URL, else found on the network)")
    sp = ap.add_subparsers(dest="cmd", required=True)
    sp.add_parser("find", help="print the phone's address")
    s = sp.add_parser("library", help="list games in the library")
    s.add_argument("--platform", help="platform id, e.g. gba, snes, arcade")
    s.add_argument("--json", action="store_true")
    s = sp.add_parser("info", help="details for games matching a name, file name or id")
    s.add_argument("query"); s.add_argument("--platform")
    s = sp.add_parser("find-game", help="search the library by name")
    s.add_argument("query"); s.add_argument("--platform")
    s = sp.add_parser("put", help="upload files; the app imports them into the library")
    s.add_argument("files", nargs="+")
    s.add_argument("--platform", help="import as this platform id, e.g. arcade, gba, ps1 (arcade zips skip the app's zip dialog)")
    s.add_argument("--bulk", action="store_true", help="import without any alerts or dialogs on the phone")
    s.add_argument("--names", help=NAMES_HELP)
    s = sp.add_parser("remove", help="remove games from the library (dry run without --yes)")
    s.add_argument("games", nargs="+", help="name, file name or id")
    s.add_argument("--platform"); s.add_argument("--yes", action="store_true")
    s = sp.add_parser("update", help="rename a game or change its sound, haptics or orientation")
    s.add_argument("game", help="name, file name or id"); s.add_argument("--platform")
    s.add_argument("--name", help="new display name")
    s.add_argument("--sound", choices=["on", "off"])
    s.add_argument("--haptic", choices=["off", "soft", "light", "medium", "heavy", "rigid"])
    s.add_argument("--orientation", choices=["auto", "portrait", "landscape"])
    sp.add_parser("pending", help="list uploads not yet imported")
    s = sp.add_parser("cancel", help="delete an upload not yet imported")
    s.add_argument("names", nargs="+")
    s = sp.add_parser("sync", help="upload local files missing from the library (dry run without --yes)")
    s.add_argument("local_dir")
    s.add_argument("--platform", help="compare with this platform's games and import uploads as it "
                                      "(required with --delete)")
    s.add_argument("--bulk", action="store_true", help="import without any alerts or dialogs on the phone")
    s.add_argument("--names", help=NAMES_HELP)
    s.add_argument("--ext", action="append", help="only these extensions, e.g. --ext .zip")
    s.add_argument("--delete", action="store_true", help="also remove library games of --platform that aren't in local_dir")
    s.add_argument("--yes", action="store_true")
    a = ap.parse_args()
    names = load_names(a.names) if getattr(a, "names", None) else {}

    global host_in_use
    h = a.host or find_host(verbose=True)
    if not h:
        print("Manic EMU not found on the local network. In the app, open the Import tab and turn "
              "on WiFi, keep the app open, and retry, or pass --host with the address it shows.", file=sys.stderr)
        return 2
    host_in_use = h

    if a.cmd == "find":
        print(h)
    elif a.cmd == "library":
        games = library(h, a.platform)
        print(json.dumps(games, indent=1)) if a.json else print_games(games)
    elif a.cmd == "info":
        games = resolve(library(h, a.platform), a.query)
        print_info(games) if games else print(f"no game matches {a.query!r}")
    elif a.cmd == "find-game":
        print_games(resolve(library(h, a.platform), a.query))
    elif a.cmd == "put":
        for f in a.files:
            print(f"upload {f}", flush=True)
            upload(h, f, a.platform, a.bulk, names.get(stem(os.path.basename(f))))
    elif a.cmd == "remove":
        return cmd_remove(h, a.games, a.platform, a.yes)
    elif a.cmd == "update":
        fields = {k: v for k, v in (("name", a.name), ("sound", a.sound), ("haptic", a.haptic),
                                    ("orientation", a.orientation)) if v is not None}
        return cmd_update(h, a.game, a.platform, fields)
    elif a.cmd == "pending":
        for e in pending(h):
            print(f"{fmt_size(e.get('size')):>9}  {e['name']}")
    elif a.cmd == "cancel":
        for n in a.names:
            _post_form(h, "delete", {"path": "/" + n.lstrip("/")})
            print(f"cancelled {n}")
    elif a.cmd == "sync":
        if a.delete and not a.platform:
            ap.error("--delete needs --platform, so games of other platforms are never removed")
        exts = {x.lower() if x.startswith(".") else "." + x.lower() for x in a.ext} if a.ext else None
        return cmd_sync(h, a.local_dir, a.platform, exts, a.delete, a.yes, a.bulk, names)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except urllib.error.HTTPError as e:
        print(f"Manic EMU returned {e.code}: {e.read().decode(errors='replace')}", file=sys.stderr)
        if e.code == 404:
            print("This app version may not support the library API yet; update Manic EMU.", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Cannot reach Manic EMU at {host_in_use}: in the app, turn on Import > WiFi, keep the app open, and retry. ({e.reason})",
              file=sys.stderr)
        sys.exit(2)
