# chrome-devtools MCP on WSL

The `chrome-devtools-mcp` plugin launches its own Chrome stable. WSL has no Chrome
stable, and the plugin ships no `--executablePath`, so the server starts fine, lists
its tools, and then fails every single call with:

```
Protocol error (Target.setDiscoverTargets): Target closed
```

That reads like a broken MCP server rather than a missing browser, which is why it
went unfixed for a while. `setup.sh` points it at a browser that exists.

## Usage

```bash
bash chrome-devtools-mcp/setup.sh
```

Then restart Claude Code. MCP servers are spawned at session start, so a running
session never picks up a change here.

It installs the plugin if it is missing, so it also works on a fresh machine. Safe to
re-run, and re-running is the fix for most of the failure modes below.

## What it does

Adds two args to the plugin's own `.claude-plugin/plugin.json`, the file that spawns
the server:

```json
"args": [
  "chrome-devtools-mcp@1.7.0",
  "--executablePath", "/home/joey/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome",
  "--headless"
]
```

The browser is the playwright chromium already in `~/.cache/ms-playwright`, highest
build number first. It is there for the momentum e2e suite, and it is
dependency-validated, which a hand-unpacked Chrome would not be. A system
`google-chrome` or `chromium` on `PATH` is the fallback.

`--headless` because WSL has no display by default.

The script keeps whatever `chrome-devtools-mcp@<ver>` spec the plugin shipped and
replaces only the two flags it owns, so a re-run cannot stack duplicates and a
version bump needs no edit here. First run copies the original to `plugin.json.bak`;
later runs leave that copy alone.

## Why this is a script and not a file in the repo

Two absolute machine-specific paths, same reasoning as the vue `tsdk` in
`language-servers/`: the plugin install path carries the plugin version, and the
browser path carries the playwright build number.

Worse, the file being patched lives in `~/.claude/plugins/cache/`, which the repo
deliberately does not track and which Claude Code owns. It is not a file that can be
symlinked into place.

## Things that bite

- **A plugin update wipes it.** The patch lives in the plugin's cache directory, so
  installing a new version restores the unpatched `plugin.json` and `Target closed`
  comes straight back. Re-run `setup.sh`.
- **A playwright update wipes it too.** `--executablePath` carries the build number,
  so a new `chromium-<n>` leaves the old path dangling. Symptom is a browser launch
  failure rather than `Target closed`. Re-run `setup.sh`.
- **Corporate TLS.** Something on this network MITMs TLS, so an https page can die on
  a "Your connection is not private" interstitial. Driving chromium directly, add
  `--ignore-certificate-errors`. Through the MCP server, local dev over `http` and the
  Laserfiche dev hosts have been fine without it.
- **File writes are confined to the OS temp dir.** The server warns that the client
  did not negotiate the MCP roots capability, so screenshot and trace paths outside
  temp are rejected. `--allow-unrestricted-paths` lifts it; not set here.

## A user-scoped server would survive updates

`claude mcp add` puts the same command outside the plugin cache, where a plugin update
cannot reach it. Not done, because the tool names change with it: everything becomes
`mcp__chrome-devtools__*` instead of `mcp__plugin_chrome-devtools-mcp_chrome-devtools__*`,
and the plugin's own skills (`chrome-devtools`, `troubleshooting`, `a11y-debugging`)
name the plugin form. Worth revisiting if the re-run after updates gets annoying.
