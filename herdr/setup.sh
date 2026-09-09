#!/usr/bin/env bash
# Link this repo's herdr config and claude launcher into place, and install the
# Claude Code integration herdr needs for session restore. Safe to re-run.
# WSL/Linux only; see README.md.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v herdr >/dev/null 2>&1; then
  echo "herdr is not installed. Get it from https://herdr.dev, then re-run this." >&2
  exit 1
fi

# Link a repo file into place, moving a real file aside rather than eating it.
# Matches bootstrap.ps1's *.pre-bootstrap convention.
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    [ "$(readlink -f "$dest")" = "$src" ] && { echo "==> $dest already linked"; return; }
    rm "$dest"
  elif [ -e "$dest" ]; then
    mv "$dest" "$dest.pre-bootstrap"
    echo "    moved existing $dest to $dest.pre-bootstrap"
  fi
  ln -s "$src" "$dest"
  echo "==> linked $dest"
}

link "$REPO/herdr/config.toml" "$HOME/.config/herdr/config.toml"

# ccl is the short name for claude. It has to be this wrapper and not a symlink
# to claude: a symlink puts "ccl" in argv[0] and herdr's agent detection then
# never recognises the pane. See README.md.
link "$REPO/herdr/ccl" "$HOME/.local/bin/ccl"

# The momentum helpers (m-work, m-space, m-agents) live in the repo and are
# sourced, so there is nothing to link, only a line in the local .bashrc.
BASHRC="$HOME/.bashrc"
if ! grep -q "shell/herdr-momentum.sh" "$BASHRC" 2>/dev/null; then
  cat >>"$BASHRC" <<EOF

# herdr-aware momentum helpers (source of truth: $REPO/shell/herdr-momentum.sh)
[ -f $REPO/shell/herdr-momentum.sh ] && . $REPO/shell/herdr-momentum.sh
EOF
  echo "==> added the herdr-momentum.sh source line to $BASHRC"
else
  echo "==> $BASHRC already sources herdr-momentum.sh"
fi
grep -q "shell/momentum.sh" "$BASHRC" 2>/dev/null ||
  echo "    note: $BASHRC does not source shell/momentum.sh, so m-work has no _m_newworktree to call"

# Gives herdr the session id it needs to resume panes into their conversations
# after a server restart. State still comes from screen detection.
echo "==> installing the claude integration"
herdr integration install claude 2>&1 | tail -2

herdr config check
herdr status server >/dev/null 2>&1 && herdr server reload-config >/dev/null && echo "==> reloaded the running server"

cat <<'EOF'

Done. Start a claude with `cc` and check herdr can see it:

  herdr agent list

An empty list with claude running means detection missed the pane. `herdr pane
process-info --current` shows what herdr thinks is running there; argv[0] has to
read as "claude".
EOF
