# herdr-aware momentum helpers: m-work, m-space, m-agents.
#
# Sourced from ~/.bashrc alongside momentum.sh, whose _m_root and _m_newworktree
# these call. The source line is added by herdr/setup.sh; herdr/README.md has the rest
# of the workflow. Every function no-ops when herdr is missing, so the file is
# safe to source on a box without it (Windows, today).
#
# Why these exist: m-newwork ends with cd + claude in whichever pane you were
# standing in, so herdr files that agent under that pane's space. These give
# each worktree its own space instead, which is what turns the sidebar's agent
# panel into a real queue across parallel work.

_m_herdr() { command -v herdr >/dev/null 2>&1; }

# momentum-better-mobile-header -> better-mobile-header, then down to a legal
# agent name ([a-z][a-z0-9_-]{0,31}).
_m_herdr_name() {
  local n="${1##*/}"
  n="${n#momentum-}"
  n="$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-')"
  n="${n#-}"
  printf '%s\n' "${n:0:32}"
}

# m-space [dir] - adopt a worktree as its own herdr space, laid out the way every
# worktree space wants to be: reviewr on tab 1, the worktree's claude on tab 2.
# Defaults to the worktree you are standing in.
m-space() {
  _m_herdr || { echo "m-space: no herdr on this box" >&2; return 1; }
  local main dir name opened ws review_pane review_tab created agent_pane
  main="$(_m_root)/momentum"
  dir="$(cd "${1:-$PWD}" 2>/dev/null && pwd)" || { echo "m-space: no such directory" >&2; return 1; }
  name="$(_m_herdr_name "$dir")"

  opened="$(herdr worktree open --cwd "$main" --path "$dir" --label "$name" --focus)" || return 1
  if [ "$(printf '%s' "$opened" | jq -r '.result.already_open')" = true ]; then
    echo "m-space: $name already has a space"
    return 0
  fi

  ws="$(printf '%s' "$opened" | jq -r '.result.workspace.workspace_id')"
  review_pane="$(printf '%s' "$opened" | jq -r '.result.root_pane.pane_id')"
  review_tab="$(printf '%s' "$opened" | jq -r '.result.tab.tab_id')"

  # Claude gets built first even though it ends up second. Tab order is creation
  # order and the root tab is already first, so nothing here can reorder them,
  # and `agent start` blocks until its pane is ready - which is also the time the
  # root pane's shell needs before it can be typed into.
  created="$(herdr tab create --workspace "$ws" --cwd "$dir" --label claude --focus)" || return 1
  agent_pane="$(printf '%s' "$created" | jq -r '.result.root_pane.pane_id')"
  if ! herdr agent start "$name" --kind claude --pane "$agent_pane" >/dev/null; then
    echo "m-space: space is up but claude did not start in $agent_pane" >&2
    return 1
  fi

  # The binary, not the plugin action: the action only ever opens a new tab, and
  # this one has to be the first. pane.sh finds a reviewr pane by its process, so
  # ctrl+alt+v still closes and reopens this one. auto_open is off in the plugin
  # config to keep the event from adding a third tab.
  herdr pane run "$review_pane" herdr-reviewr >/dev/null ||
    echo "m-space: reviewr did not start in $review_pane" >&2
  herdr tab rename "$review_tab" reviewr >/dev/null 2>&1

  echo "m-space: $name -> $agent_pane"
}

# m-work <short description> - the herdr version of m-newwork: new branch and
# worktree, its own space, claude already running in it.
m-work() {
  _m_herdr || { echo "m-work: no herdr on this box" >&2; return 1; }
  if [ "$#" -eq 0 ]; then
    echo "usage: m-work <short description of the work>" >&2
    return 1
  fi

  local new
  new="$(_m_newworktree "$@")" || return 1

  # A fresh worktree has no node_modules, so nothing in ui-app can lint, test or
  # run until this finishes. Do it before the space, so claude opens on a tree
  # that is ready to work in. A failure here is not fatal: the worktree is fine
  # and npm install can be re-run by hand.
  if [ -f "$new/src/ui-app/package.json" ]; then
    echo "m-work: npm install in src/ui-app"
    ( cd "$new/src/ui-app" && npm install ) ||
      echo "m-work: npm install failed in $new/src/ui-app; run it by hand" >&2
  fi

  m-space "$new"
}

# m-agents - the agent panel, from any pane.
m-agents() {
  _m_herdr || return 1
  herdr agent list |
    jq -r '.result.agents[] | [.agent_status, .workspace_id, (.name // .pane_id), (.terminal_title_stripped // "")] | @tsv' |
    column -t -s "$(printf '\t')"
}
