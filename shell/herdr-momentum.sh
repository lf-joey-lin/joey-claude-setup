# herdr-aware momentum helpers: m-work, m-space, m-agents.
#
# Sourced from ~/.bashrc alongside momentum.sh, whose _m_root and _m_skill these
# call. The source line is added by herdr/setup.sh; herdr/README.md has the rest
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

# m-space [dir] - adopt a worktree as its own herdr space, with claude running
# in it. Defaults to the worktree you are standing in.
m-space() {
  _m_herdr || { echo "m-space: no herdr on this box" >&2; return 1; }
  local main dir name opened pane
  main="$(_m_root)/momentum"
  dir="$(cd "${1:-$PWD}" 2>/dev/null && pwd)" || { echo "m-space: no such directory" >&2; return 1; }
  name="$(_m_herdr_name "$dir")"

  opened="$(herdr worktree open --cwd "$main" --path "$dir" --label "$name" --focus)" || return 1
  if [ "$(printf '%s' "$opened" | jq -r '.result.already_open')" = true ]; then
    echo "m-space: $name already has a space"
    return 0
  fi

  pane="$(printf '%s' "$opened" | jq -r '.result.root_pane.pane_id')"
  if herdr agent start "$name" --kind claude --pane "$pane" >/dev/null; then
    echo "m-space: $name -> $pane"
  else
    echo "m-space: space is up but claude did not start in $pane" >&2
    return 1
  fi
}

# m-work <short description> - the herdr version of m-newwork: new branch and
# worktree, its own space, claude already running in it.
m-work() {
  _m_herdr || { echo "m-work: no herdr on this box" >&2; return 1; }
  if [ "$#" -eq 0 ]; then
    echo "usage: m-work <short description of the work>" >&2
    return 1
  fi

  local main before after new
  main="$(_m_root)/momentum"

  # Same before/after diff m-newwork uses, so nothing has to be parsed out of
  # Claude's output. Keep the two in step if either changes.
  before="$(git -C "$main" worktree list --porcelain | awk '/^worktree /{print $2}')"
  _m_skill "/new-work $*" || return 1
  after="$(git -C "$main" worktree list --porcelain | awk '/^worktree /{print $2}')"
  new="$(comm -13 <(printf '%s\n' "$before" | sort) <(printf '%s\n' "$after" | sort) | head -n 1)"

  if [ -z "$new" ] || [ ! -d "$new" ]; then
    echo "m-work: no new worktree appeared, so setup did not finish" >&2
    return 1
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
