#!/usr/bin/env bash
# Link the Teams notifier and its watcher into place, and enable the user service.
# Safe to re-run. WSL/Linux only; see README.md.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBHOOK="$HOME/.config/herdr/teams-webhook"

if ! command -v herdr >/dev/null 2>&1; then
  echo "herdr is not installed. Run herdr/setup.sh first." >&2
  exit 1
fi
command -v jq >/dev/null 2>&1 || { echo "jq is required (sudo apt install jq)." >&2; exit 1; }

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

link "$REPO/herdr-teams/herdr-teams-notify" "$HOME/.local/bin/herdr-teams-notify"
link "$REPO/herdr-teams/herdr-teams-watch"  "$HOME/.local/bin/herdr-teams-watch"
link "$REPO/herdr-teams/herdr-teams-summary" "$HOME/.local/bin/herdr-teams-summary"
link "$REPO/herdr-teams/herdr-teams-toggle" "$HOME/.local/bin/herdr-teams-toggle"
link "$REPO/herdr-teams/herdr-teams-watch.service" \
     "$HOME/.config/systemd/user/herdr-teams-watch.service"

# The webhook URL is a bearer credential and never goes in the repo.
if [ ! -s "$WEBHOOK" ]; then
  mkdir -p "$(dirname "$WEBHOOK")"
  cat >&2 <<EOF

No webhook URL yet. Create the Power Automate flow (see README.md), then:

  printf '%s' '<paste the flow URL>' > $WEBHOOK
  chmod 600 $WEBHOOK
  bash $REPO/herdr-teams/setup.sh

EOF
  exit 1
fi
chmod 600 "$WEBHOOK"

systemctl --user daemon-reload
systemctl --user enable herdr-teams-watch.service >/dev/null 2>&1
# Restart, not just start: the scripts are symlinks into the repo, so a re-run after
# editing one is how the running watcher picks the edit up.
systemctl --user restart herdr-teams-watch.service
sleep 2

if systemctl --user is-active --quiet herdr-teams-watch.service; then
  echo "==> herdr-teams-watch is running"
else
  echo "!! service did not start. journalctl --user -u herdr-teams-watch -n 20" >&2
  exit 1
fi

cat <<'EOF'

Done. Send yourself a test card:

  herdr-teams-notify "test" "setup worked"

Then watch it decide, which is the only honest check that it is really working:

  journalctl --user -u herdr-teams-watch -f
EOF
