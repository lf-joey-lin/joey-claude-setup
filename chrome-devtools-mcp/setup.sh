#!/usr/bin/env bash
# Point the chrome-devtools MCP plugin at a browser that exists on this machine.
# Without this its tools fail on every call with "Target closed". Safe to re-run,
# and it has to be re-run after a plugin update. WSL/Linux only; see README.md.
set -euo pipefail

# Install the plugin first if it is missing, so this works on a fresh machine.
if [ ! -f "$HOME/.claude/plugins/installed_plugins.json" ] ||
   ! grep -q chrome-devtools-mcp "$HOME/.claude/plugins/installed_plugins.json"; then
  echo "==> installing chrome-devtools-mcp"
  claude plugin install chrome-devtools-mcp@claude-plugins-official 2>&1 | tail -1
fi

# Prefer the playwright chromium: it is already dependency-validated, and Chrome
# stable is not installed under WSL. Highest build number wins.
CHROME=""
for c in $(ls -d "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux64/chrome 2>/dev/null | sort -V -r); do
  [ -x "$c" ] && CHROME="$c" && break
done
if [ -z "$CHROME" ]; then
  for c in google-chrome chromium chromium-browser; do
    CHROME="$(command -v "$c" 2>/dev/null || true)"
    [ -n "$CHROME" ] && break
  done
fi
if [ -z "$CHROME" ]; then
  echo "No browser found. Install one, e.g. npx playwright install --with-deps chromium" >&2
  exit 1
fi
echo "==> browser $CHROME"

python3 - "$CHROME" <<'PY'
import json, os, shutil, sys, glob

chrome = sys.argv[1]
home = os.path.expanduser("~")

# Read the real install path rather than guessing the version out of the cache tree.
paths = []
try:
    with open(f"{home}/.claude/plugins/installed_plugins.json") as f:
        for name, entries in json.load(f).get("plugins", {}).items():
            if name.startswith("chrome-devtools-mcp@"):
                paths += [e["installPath"] for e in entries if e.get("installPath")]
except (OSError, ValueError, KeyError):
    pass
paths += glob.glob(f"{home}/.claude/plugins/cache/*/chrome-devtools-mcp/*")

seen, patched = set(), 0
for root in paths:
    cfg = os.path.join(root, ".claude-plugin", "plugin.json")
    if cfg in seen or not os.path.isfile(cfg):
        continue
    seen.add(cfg)

    with open(cfg) as f:
        d = json.load(f)
    server = d.get("mcpServers", {}).get("chrome-devtools")
    if server is None:
        print(f"    no chrome-devtools server in {cfg}, skipped")
        continue

    # Keep the package spec the plugin shipped; drop only the flags we own, so a
    # re-run does not stack duplicates and a version bump is picked up for free.
    args, drop = [], 0
    for a in server.get("args", []):
        if drop:
            drop -= 1
            continue
        if a == "--executablePath":
            drop = 1
            continue
        if a == "--headless":
            continue
        args.append(a)
    server["args"] = args + ["--executablePath", chrome, "--headless"]

    # First patch keeps a pristine copy; later runs must not overwrite it.
    bak = cfg + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(cfg, bak)

    tmp = cfg + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, indent=2)
        f.write("\n")
    json.load(open(tmp))
    os.replace(tmp, cfg)

    print(f"==> patched {cfg}")
    patched += 1

if not patched:
    sys.exit("no chrome-devtools-mcp plugin.json found; is the plugin installed?")
PY

cat <<'EOF'

Done. Restart Claude Code: MCP servers are spawned at session start.

Check it worked with a chrome-devtools list_pages call. "Protocol error
(Target.setDiscoverTargets): Target closed" means it is still launching its own
Chrome, so the patch did not load.
EOF
