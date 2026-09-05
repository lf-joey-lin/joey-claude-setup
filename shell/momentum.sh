# momentum workspace shortcuts: m-newwork, m-teardown, m-dev, m-cd.
#
# m-newwork runs its skill headless in ~/m-code/momentum and then leaves the
# shell somewhere useful, which is the part a Claude session cannot do for
# itself. m-teardown, m-dev and m-cd are plain git/process wrappers with no
# Claude in them.
#
# Source from ~/.bashrc. Bash only; the Windows side has no equivalent yet.

_m_root() { printf '%s\n' "${MOMENTUM_ROOT:-$HOME/m-code}"; }

# Run a skill headless from the default worktree, with git-only tools allowed.
_m_skill() {
  local main="$(_m_root)/momentum"
  if [ ! -e "$main/.git" ]; then
    echo "no momentum checkout at $main" >&2
    return 1
  fi
  ( cd "$main" && claude -p "$1" --model sonnet \
      --allowedTools "Bash(git:*),Bash(gh:*),Bash(jj:*),Bash(uname:*)" )
}

# m-newwork <short description>
#
# Sets up the branch/worktree, then drops you into it with Claude running.
# The worktree is found by diffing `git worktree list` around the run, so
# nothing has to be parsed out of Claude's output.
m-newwork() {
  if [ "$#" -eq 0 ]; then
    echo "usage: m-newwork <short description of the work>" >&2
    return 1
  fi

  local main="$(_m_root)/momentum"
  local before after branch_before branch_after new dir=""
  before="$(git -C "$main" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')"
  branch_before="$(git -C "$main" branch --show-current 2>/dev/null)"

  _m_skill "/new-work $*" || return 1

  after="$(git -C "$main" worktree list --porcelain | awk '/^worktree /{print $2}')"
  branch_after="$(git -C "$main" branch --show-current)"
  new="$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) | head -n 1)"

  if [ -n "$new" ] && [ -d "$new" ]; then
    dir="$new"                                    # new worktree
  elif [ "$branch_before" != "$branch_after" ]; then
    dir="$main"                                   # branched in place
  fi

  if [ -z "$dir" ]; then
    echo "m-newwork: no new branch or worktree appeared, so setup did not finish; staying in $PWD" >&2
    return 1
  fi

  cd "$dir" || return 1
  claude -n "$*"
}

# --- m-teardown: the worktree sweep, as a table ------------------------------
#
# Plain shell, no Claude in it. The table lists every momentum worktree with a
# verdict on whether it can go, and d removes the selected one after a y.
#
#   m-teardown           the table: up/down select, d tear down, D force,
#                        r rescan, p land main, q quit
#   m-teardown <name>    gate that one worktree and remove it after a y/n
#   m-teardown this      the worktree the shell is standing in
#   m-teardown --pull    land momentum on a fresh main and pull manta
#
# The verdict is the same gate the teardown skill applies: a clean tree, nothing
# unpushed, and a PR that is merged or absent. Working one out costs a `gh pr
# list`, so a scan runs behind the table and writes its answers to a cache the
# redraw reads back - the same split m-dev uses to keep slow work off the frame.

_m_td_state() { printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/m-teardown"; }
_m_td_status_file() { printf '%s\n' "$(_m_td_state)/status"; }
_m_td_action_log() { printf '%s\n' "$(_m_td_state)/action.log"; }
_m_td_action_pid() { printf '%s\n' "$(_m_td_state)/action.pid"; }

# The worktrees this may act on: the default one, which is only ever landed on
# main, and its direct momentum-<desc> siblings. gnhf keeps real momentum
# worktrees of its own a few directories further down; the filter is on the path
# rather than the name, because by name they look like everything else.
_m_td_targets() {
  local root label branch dir
  root="$(_m_root)"
  _m_dev_worktrees | while read -r label branch dir; do
    case "$dir" in
      "$root"/momentum)     printf '%s %s %s\n' "$label" "$branch" "$dir" ;;
      "$root"/momentum-*/*) ;;
      "$root"/momentum-*)   printf '%s %s %s\n' "$label" "$branch" "$dir" ;;
    esac
  done
}

_M_TD_WT_CACHE=""
_m_td_rows() {
  local -n out="$1"
  local line
  if [ -z "$_M_TD_WT_CACHE" ] || [ "${2:-}" = fresh ]; then
    _M_TD_WT_CACHE="$(_m_td_targets)"
  fi
  out=()
  while IFS= read -r line; do
    [ -n "$line" ] && out+=("$line")
  done <<<"$_M_TD_WT_CACHE"
  [ "${#out[@]}" -gt 0 ]
}

_m_td_branch_of() {
  local row label branch dir
  local -a rows
  _m_td_rows rows || return 1
  for row in "${rows[@]}"; do
    read -r label branch dir <<<"$row"
    [ "$dir" = "$1" ] && { printf '%s\n' "$branch"; return 0; }
  done
  return 1
}

# The pull request for one branch, as "<number> <state>", or the word `none` when
# the branch has none and `down` when gh could not answer. Those three are not
# interchangeable: no PR is a normal end state for an abandoned worktree, while a
# gh that cannot answer proves nothing and must not read as one.
_m_td_pr_of() {
  local out
  out="$( cd "$(_m_root)/momentum" && gh pr list --head "$1" --state all --limit 1 \
            --json number,state --jq '.[] | "\(.number) \(.state)"' 2>/dev/null )" \
    || { printf 'down\n'; return 0; }
  [ -n "$out" ] && printf '%s\n' "$out" || printf 'none\n'
}

# _m_td_branch_check <branch> <pr> -> "<SAFE|KEEP><tab><reason>".
#
# Is every commit on this branch somewhere other than this worktree? The refs
# live in the default worktree, so this holds even for a worktree whose
# directory has already gone.
_m_td_branch_check() {
  local branch="$1" pr="$2" main n ahead num state upstream_gone=""
  main="$(_m_root)/momentum"

  if git -C "$main" rev-parse --verify --quiet "$branch@{upstream}" >/dev/null 2>&1; then
    n="$(git -C "$main" rev-list --count "$branch@{upstream}..$branch" 2>/dev/null)"
    [ "${n:-0}" -gt 0 ] && { printf 'KEEP\t%s unpushed commit(s)\n' "$n"; return 0; }
  elif [ -z "$(git -C "$main" config --get "branch.$branch.merge" 2>/dev/null)" ]; then
    printf 'KEEP\tnever pushed, origin has no copy\n'
    return 0
  else
    # Pushed once, and origin/<branch> has since gone. That is exactly what
    # GitHub does to a head branch on merge, so it is safe only when the PR
    # really did merge; the case below is what decides that.
    upstream_gone=1
  fi

  ahead="$(git -C "$main" rev-list --count "origin/main..$branch" 2>/dev/null)"
  read -r num state <<<"$pr"
  case "$state" in
    MERGED) printf 'SAFE\tPR #%s merged\n' "$num"; return 0 ;;
    OPEN)   printf 'KEEP\tPR #%s still open\n' "$num"; return 0 ;;
    CLOSED) printf 'KEEP\tPR #%s closed unmerged\n' "$num"; return 0 ;;
  esac
  case "$pr" in
    down) printf 'KEEP\tgh could not say whether a PR exists\n'; return 0 ;;
  esac
  [ -n "$upstream_gone" ] && { printf 'KEEP\tno PR and origin/%s is gone\n' "$branch"; return 0; }
  if [ "${ahead:-0}" -gt 0 ]; then
    printf 'SAFE\tno PR, %s commit(s) ahead of main, all pushed\n' "$ahead"
  else
    printf 'SAFE\tno PR, nothing ahead of main\n'
  fi
}

# _m_td_check <dir> <branch> <pr> -> "<VERDICT><tab><detail>".
#
# SAFE means every gate passed: nothing uncommitted, and the branch is on origin
# with a merged PR or none at all. KEEP means one of them stopped it, and the
# detail says which. GONE is a worktree git already calls prunable - its
# directory has been deleted from under it - where the record goes either way and
# only the branch is in question. Nothing here writes.
_m_td_check() {
  local dir="$1" branch="$2" pr="$3" main n verdict reason
  main="$(_m_root)/momentum"

  [ "$dir" = "$main" ] && { printf 'BASE\tdefault worktree, never removed\n'; return 0; }
  [ "$branch" = detached ] && { printf 'KEEP\tdetached head, no branch to check\n'; return 0; }

  IFS=$'\t' read -r verdict reason < <(_m_td_branch_check "$branch" "$pr")

  if [ ! -d "$dir" ]; then
    if [ "$verdict" = SAFE ]; then
      printf 'GONE\tprunable, record and branch both go\n'
    else
      printf 'GONE\tprunable, branch stays: %s\n' "$reason"
    fi
    return 0
  fi

  n="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)"
  [ "${n:-0}" -gt 0 ] && { printf 'KEEP\tdirty, %s uncommitted file(s)\n' "$n"; return 0; }

  printf '%s\t%s\n' "$verdict" "$reason"
}

# Every verdict, written a line at a time so the table fills in as it goes.
# One `gh pr list` covers every branch at once; only a branch older than that
# page costs a lookup of its own.
_m_td_scan() {
  local main label branch dir pr line b n s ok=1
  local -A pr_num=() pr_state=()
  main="$(_m_root)/momentum"
  mkdir -p "$(_m_td_state)"
  : >"$(_m_td_status_file)"

  echo "reading pull requests ..."
  if line="$( cd "$main" && gh pr list --state all --limit 200 \
                --json number,state,headRefName \
                --jq '.[] | [.headRefName, .number, .state] | @tsv' 2>&1 )"; then
    while IFS=$'\t' read -r b n s; do
      [ -n "$b" ] || continue
      [ -n "${pr_num[$b]}" ] && continue          # the list is newest first
      pr_num["$b"]="$n" pr_state["$b"]="$s"
    done <<<"$line"
    echo "${#pr_num[@]} branches have a pull request"
  else
    ok=""
    echo "gh pr list failed, so no verdict can rest on a PR:"
    echo "$line"
  fi

  while read -r label branch dir; do
    echo "checking $label ..."
    if [ -n "${pr_state[$branch]}" ]; then
      pr="${pr_num[$branch]} ${pr_state[$branch]}"
    elif [ -n "$ok" ]; then
      pr="$(_m_td_pr_of "$branch")"
    else
      pr=down
    fi
    printf '%s\t%s\n' "$dir" "$(_m_td_check "$dir" "$branch" "$pr")" >>"$(_m_td_status_file)"
  done < <(_m_td_targets)
  echo "scan finished"
}

# The scan's answers, cached in this shell for the redraw. One read of the file
# per pass rather than one per row.
_M_TD_ST_CACHE=""
_m_td_status_load() { _M_TD_ST_CACHE="$(cat "$(_m_td_status_file)" 2>/dev/null)"; }
_m_td_status() {
  local line rest
  while IFS= read -r line; do
    case "$line" in
      "$1"$'\t'*)
        rest="${line#*$'\t'}"
        printf '%-4s %s' "${rest%%$'\t'*}" "${rest#*$'\t'}"
        return 0 ;;
    esac
  done <<<"$_M_TD_ST_CACHE"
  printf '%-4s %s' '?' 'checking ...'
}

_m_td_verdict() {
  local st
  st="$(_m_td_status "$1")"
  printf '%s\n' "${st%% *}"
}

# Remove one worktree and its branch. Runs behind the table, so everything it
# has to say goes to stdout and ends up in the pane.
#
# It re-decides the branch for itself rather than trusting the verdict on screen:
# the removal is the destructive half, and by the time it runs the scan behind
# that verdict may be minutes old.
_m_td_remove() {
  local label="$1" dir="$2" branch="$3" force="${4:-}" main out verdict="" reason=""
  main="$(_m_root)/momentum"

  case "$branch" in
    ''|detached|main) branch="" ;;
    *) IFS=$'\t' read -r verdict reason < <(_m_td_branch_check "$branch" "$(_m_td_pr_of "$branch")")
       echo "branch $branch: $verdict  $reason" ;;
  esac

  if [ ! -d "$dir" ]; then
    echo "$dir is already gone, pruning the record"
    git -C "$main" worktree prune
  elif [ -n "$force" ]; then
    git -C "$main" worktree remove --force "$dir" || { echo "worktree remove --force failed"; return 1; }
    git -C "$main" worktree prune
    echo "worktree gone"
  else
    if ! out="$(git -C "$main" worktree remove "$dir" 2>&1)"; then
      echo "$out"
      echo "git refused this one; D forces it"
      return 1
    fi
    git -C "$main" worktree prune
    echo "worktree gone"
  fi

  if [ -z "$branch" ]; then
    :
  elif [ "$verdict" != SAFE ] && [ -z "$force" ]; then
    echo "keeping branch $branch: $reason"
  else
    if out="$(git -C "$main" branch -d "$branch" 2>&1)"; then
      echo "$out"
    else
      # -d only sees a merge when the SHAs match, which a squash or a rebase
      # merge never does. The check above already proved origin holds the work.
      echo "branch -d refused, deleting with -D (squash or rebase merge)"
      git -C "$main" branch -D "$branch"
    fi
  fi

  git -C "$main" fetch --prune --quiet origin && echo "pruned stale remote refs"
  echo "done: $label"
}

# Land the default worktree on a fresh main, and bring manta's main up to date.
# --ff-only on purpose: a diverged main fails loudly instead of quietly building
# a merge commit.
_m_td_land() {
  local root main manta n
  root="$(_m_root)"
  main="$root/momentum"

  n="$(git -C "$main" status --porcelain 2>/dev/null | wc -l)"
  if [ "${n:-0}" -gt 0 ]; then
    echo "momentum: $n uncommitted file(s) in the default worktree, leaving it where it is"
  else
    echo "momentum: checkout main, pull"
    git -C "$main" checkout main && git -C "$main" pull --ff-only origin main
  fi

  manta="$root/manta"
  if [ -e "$manta/.git" ]; then
    echo "manta: checkout main, pull"
    git -C "$manta" checkout main && git -C "$manta" pull --ff-only origin main
  fi
  echo "done"
}

# --- the table ---------------------------------------------------------------

# _m_td_table <sel> [busy-dir] [busy-text]. The busy row is the one an action is
# working on, and says so rather than showing a verdict the action is in the
# middle of invalidating.
_m_td_table() {
  local sel="$1" busy="$2" busytext="$3" i=0 row label branch dir lw=8 bw=6 st mark
  local -a rows
  _m_td_rows rows || { echo "  no momentum worktrees found"; return 1; }

  for row in "${rows[@]}"; do
    read -r label branch dir <<<"$row"
    [ "${#label}" -gt "$lw" ] && lw="${#label}"
    [ "${#branch}" -gt "$bw" ] && bw="${#branch}"
  done

  printf '  %-3s %-*s %-*s %s\n' '#' "$lw" WORKTREE "$bw" BRANCH VERDICT
  for row in "${rows[@]}"; do
    i=$((i + 1))
    read -r label branch dir <<<"$row"
    if [ -n "$busy" ] && [ "$dir" = "$busy" ]; then
      st="$busytext"
    else
      st="$(_m_td_status "$dir")"
    fi
    [ "$i" = "$sel" ] && mark='>' || mark=' '
    printf '%s %-3s %-*s %-*s %s\n' "$mark" "$i" "$lw" "$label" "$bw" "$branch" "$st"
  done
}

_M_TD_SHELL_FILE="${BASH_SOURCE[0]}"

# Run a function detached and print its pid, so the table stays up while a scan
# or a removal runs. Its own session: a plain background job would print bash's
# job notice across the frame, and a session can be signalled as a group.
_m_td_action_start() {
  local log pidf waited=0
  log="$(_m_td_action_log)"
  pidf="$(_m_td_action_pid)"
  mkdir -p "$(_m_td_state)" 2>/dev/null
  : >"$log" 2>/dev/null
  rm -f "$pidf"
  MOMENTUM_ROOT="$(_m_root)" \
    setsid --fork bash -c 'echo $$ >"$1"; . "$2"; shift 2; "$@"' \
      m-teardown "$pidf" "$_M_TD_SHELL_FILE" "$@" >>"$log" 2>&1 </dev/null
  while [ ! -s "$pidf" ] && [ "$waited" -lt 40 ]; do
    sleep 0.05
    waited=$((waited + 1))
  done
  cat "$pidf" 2>/dev/null
}

# Resolve the worktree the shell is standing in, for `m-teardown this`.
_m_teardown_this() {
  local root="$(_m_root)" top
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "m-teardown: $PWD is not a git worktree, so 'this' names nothing" >&2
    return 1
  }
  case "$top" in
    "$root"/momentum-*/*)
      echo "m-teardown: $top is nested under the root, not a top-level worktree" >&2
      return 1 ;;
    "$root"/momentum-*) ;;
    "$root"/momentum)
      echo "m-teardown: $top is the default worktree, which teardown never removes" >&2
      return 1 ;;
    *)
      echo "m-teardown: $top is not a $root/momentum-<desc> worktree" >&2
      return 1 ;;
  esac
  printf '%s\n' "${top#"$root"/momentum-}"
}

# One worktree, gated and removed in the foreground. The path a name on the
# command line takes; the table uses the same two functions behind an action.
_m_td_one() {
  local name="$1" force="$2" root main label dir branch pr verdict detail ans out err
  root="$(_m_root)"
  main="$root/momentum"

  # _m_dev_resolve does the name/branch/number matching for both tools, so its
  # complaints have to be re-badged before they reach a m-teardown user.
  if ! err="$( { out="$(_m_dev_resolve "$name")"; } 2>&1 )"; then
    printf '%s\n' "${err//m-dev:/m-teardown:}" >&2
    return 1
  fi
  read -r label dir <<<"$out"
  case "$dir" in
    "$root"/momentum-*/*|"$root"/momentum)
      echo "m-teardown: $dir is not a worktree this removes" >&2
      return 1 ;;
    "$root"/momentum-*) ;;
    *)
      echo "m-teardown: $dir is not a $root/momentum-<desc> worktree" >&2
      return 1 ;;
  esac
  branch="$(_m_td_branch_of "$dir")"

  if [ -n "$force" ]; then
    echo "$label ($branch): forced, no checks - uncommitted and unpushed work goes with it"
  else
    echo "checking $label ..."
    pr="$(_m_td_pr_of "$branch")"
    IFS=$'\t' read -r verdict detail < <(_m_td_check "$dir" "$branch" "$pr")
    echo "$label ($branch): $verdict  $detail"
    case "$verdict" in
      SAFE|GONE) ;;
      *) echo "not removed. --force overrides."; return 1 ;;
    esac
  fi

  read -r -p "tear down $label? [y/N] " ans </dev/tty || return 1
  case "$ans" in y|Y) ;; *) echo "left alone"; return 1 ;; esac

  # Standing in it would break every command after the removal.
  case "$PWD/" in "$dir"/*) cd "$main" || return 1 ;; esac
  _m_td_remove "$label" "$dir" "$branch" "$force"
}

m-teardown() {
  local root main a arg="" force="" pull="" sel=1 key
  root="$(_m_root)"
  main="$root/momentum"
  if [ ! -e "$main/.git" ]; then
    echo "no momentum checkout at $main" >&2
    return 1
  fi
  mkdir -p "$(_m_td_state)" 2>/dev/null
  _M_TD_WT_CACHE=""                  # a worktree may have come or gone since last time

  for a in "$@"; do
    case "$a" in
      --force|-f) force=1 ;;
      --pull|-p)  pull=1 ;;
      --yes|-y)   ;;                 # the y at the prompt is the confirmation now
      this)       arg="$(_m_teardown_this)" || return 1 ;;
      -*)         echo "m-teardown: unknown option $a" >&2; return 1 ;;
      *)          arg="$a" ;;
    esac
  done

  [ -n "$pull" ] && { _m_td_land; return $?; }
  [ -n "$arg" ] && { _m_td_one "$arg" "$force"; return $?; }

  # Interactive. The table owns the top of the screen and the keys always act on
  # the selected row; the scan and any removal run detached behind it, with their
  # output tailed into the pane underneath, so nothing ever covers the list.
  local frame last="" dirty=1 wt_stale=1 note="" excluded=0 rc=0 waits=0
  local job="" what="" kind="" busy_dir="" busy_text="" seq="" ch="" traps="" bail=""
  local cf_dir="" cf_label="" cf_branch="" cf_verdict="" cf_force=""
  local label branch dir st atext used avail nl
  local -a rows

  job="$(cat "$(_m_td_action_pid)" 2>/dev/null)"
  if _m_dev_action_alive "$job"; then
    what="an action started earlier" kind=other
  else
    job="$(_m_td_action_start _m_td_scan)"
    what="scan" kind=scan
  fi

  traps="$(trap -p WINCH INT)"
  _M_TD_RESIZED=0 _M_TD_QUIT=0
  trap '_M_TD_RESIZED=1' WINCH
  trap '_M_TD_QUIT=1' INT
  _m_dev_size
  _m_dev_screen_on

  while :; do
    if [ "$_M_TD_RESIZED" = 1 ]; then
      _M_TD_RESIZED=0
      _m_dev_size
      dirty=1
    fi

    if [ -n "$job" ] && ! _m_dev_action_alive "$job"; then
      note="$what: done"
      job="" busy_dir="" busy_text=""
      wt_stale=1 dirty=1
      # A removal changed what every other verdict was worked out against, and
      # the row that just went has to leave the table, so the list is re-read
      # and the scan runs again on its own.
      if [ "$kind" = remove ]; then
        job="$(_m_td_action_start _m_td_scan)"
        what="scan" kind=scan
      else
        kind=""
      fi
    fi

    if [ "$wt_stale" = 1 ]; then
      _m_td_rows rows fresh || { bail="m-teardown: no momentum worktrees found"; break; }
      excluded=$(( $(_m_dev_worktrees | wc -l) - ${#rows[@]} ))
      wt_stale=0
    fi
    [ "$sel" -gt "${#rows[@]}" ] && sel="${#rows[@]}"
    [ "$sel" -lt 1 ] && sel=1

    _m_td_status_load

    frame="momentum worktrees - what is safe to tear down"$'\n\n'
    frame+="$(_m_td_table "$sel" "$busy_dir" "$busy_text")"$'\n\n'
    if [ -n "$cf_dir" ]; then
      if [ -n "$cf_force" ]; then
        frame+="  FORCE tear down $cf_label ($cf_branch)? uncommitted and unpushed work goes with it.  y / anything else"
      elif [ "$cf_verdict" = GONE ]; then
        frame+="  prune $cf_label ($cf_branch)? its directory is already deleted.  y / anything else"
      else
        frame+="  tear down $cf_label ($cf_branch) and delete its branch?  y / anything else"
      fi
    else
      frame+="  up/down select   d tear down   D force   r rescan   p land main   q quit"
    fi
    [ "$excluded" -gt 0 ] && frame+=$'\n'"  $excluded other momentum worktree(s) elsewhere (gnhf) are never touched"
    [ -n "$job" ] && frame+=$'\n'"  running: $what"
    [ -n "$note" ] && frame+=$'\n'"  $note"

    used=$(( 5 + ${#rows[@]} ))
    [ "$excluded" -gt 0 ] && used=$((used + 1))
    [ -n "$job" ] && used=$((used + 1))
    [ -n "$note" ] && used=$((used + 1))
    avail=$(( _M_DEV_ROWS - used ))

    if [ "$avail" -ge 4 ]; then
      atext="$(_m_dev_pane "$(_m_td_action_log)" "$_M_DEV_COLS" "$((avail - 2))")"
      if [ -n "$atext" ]; then
        frame+=$'\n'"$(_m_dev_rule 'm-teardown' "$_M_DEV_COLS")"$'\n'"$atext"
      fi
    fi

    if [ "$dirty" = 1 ] || [ "$frame" != "$last" ]; then
      printf '\033[H%s\033[J' "$(_m_dev_fit "$_M_DEV_COLS" "$_M_DEV_ROWS" "$frame")"
      last="$frame" dirty=0
    fi

    # Always a timed read: bash only runs a trap once the builtin returns, so a
    # blocking one would swallow Ctrl+C, and there is a screen to hand back
    # before this can return. A key leaves at once; otherwise the wait ends about
    # once a second, which is what keeps the pane and the verdicts moving.
    waits=0
    while :; do
      IFS= read -rsn1 -t 0.25 key && break
      rc=$?
      [ "$_M_TD_QUIT" = 1 ] && break 2
      [ "$rc" -le 128 ] && break 2                 # eof, not a timeout
      [ "$_M_TD_RESIZED" = 1 ] && continue 2
      waits=$((waits + 1))
      [ "$waits" -ge 4 ] && continue 2
    done
    [ "$_M_TD_QUIT" = 1 ] && break
    note=""

    # A pending confirmation answers to y and nothing else. Every other key
    # cancels it rather than doing its own job, so a stray keystroke can only
    # ever call the removal off.
    if [ -n "$cf_dir" ]; then
      if [ "$key" = y ] || [ "$key" = Y ]; then
        case "$PWD/" in
          "$cf_dir"/*) cd "$main" && note="stepped out of $cf_label into $main" ;;
        esac
        what="tear down $cf_label" kind=remove
        busy_dir="$cf_dir" busy_text="removing ..."
        job="$(_m_td_action_start _m_td_remove "$cf_label" "$cf_dir" "$cf_branch" "$cf_force")"
        [ -n "$job" ] || { note="could not start $what"; busy_dir="" busy_text="" kind=""; }
      else
        note="left $cf_label alone"
      fi
      cf_dir="" cf_label="" cf_branch="" cf_verdict="" cf_force=""
      dirty=1
      continue
    fi

    case "$key" in
      $'\e')
        seq=""
        IFS= read -rsn1 -t 0.05 ch || ch=""
        case "$ch" in
          '['|'O')
            while IFS= read -rsn1 -t 0.05 ch; do
              seq+="$ch"
              case "$ch" in [a-zA-Z~]) break ;; esac
            done
            ;;
        esac
        case "$seq" in
          'A') sel=$((sel - 1)) ;;
          'B') sel=$((sel + 1)) ;;
        esac
        ;;
      'k') sel=$((sel - 1)) ;;
      'j') sel=$((sel + 1)) ;;
      'd'|'D')
        read -r label branch dir <<<"${rows[$((sel - 1))]}"
        st="$(_m_td_status "$dir")"
        if [ -n "$job" ]; then
          note="wait for $what to finish"
        elif [ "$dir" = "$main" ]; then
          note="the default worktree is never removed; p lands it on main"
        elif [ "$key" = D ]; then
          cf_dir="$dir" cf_label="$label" cf_branch="$branch" cf_verdict=FORCE cf_force=1
        else
          case "${st%% *}" in
            SAFE|GONE) cf_dir="$dir" cf_label="$label" cf_branch="$branch" \
                         cf_verdict="${st%% *}" cf_force="" ;;
            *) note="$label: ${st#* } - D forces it" ;;
          esac
        fi
        ;;
      'r'|'R')
        if [ -n "$job" ]; then
          note="wait for $what to finish"
        else
          what="scan" kind=scan
          job="$(_m_td_action_start _m_td_scan)"
          wt_stale=1
        fi
        ;;
      'p'|'P')
        if [ -n "$job" ]; then
          note="wait for $what to finish"
        else
          what="land main" kind=other
          job="$(_m_td_action_start _m_td_land)"
        fi
        ;;
      'q'|'Q') break ;;
    esac
  done 2>>"$(_m_td_action_log)"

  # One way out, so the terminal is always handed back the way it was found.
  _m_dev_screen_off
  trap - WINCH INT
  [ -n "$traps" ] && eval "$traps"
  [ -n "$bail" ] && { echo "$bail" >&2; return 1; }
  [ -n "$job" ] && echo "m-teardown: '$what' is still running behind you"
  [ -d "$PWD" ] || cd "$main"
  return 0
}

# --- m-dev / m-cd: the momentum stack, one worktree at a time ----------------
#
# `make dev` can only ever run once: sso-auth, the BFFs, postgres and valkey sit
# on ports hardcoded in AppHost.cs, so two stacks would collide. m-dev drives
# exactly one, and switching worktrees means stopping it and bringing it up in
# the new one. Every worktree therefore lands on the same URLs (ui-app on 3000,
# the Aspire dashboard on 18888), so bookmarks never change.
#
#   m-dev              live table: up/down select, enter switch, s stop,
#                      c clear the log panes, r refresh, q quit. The table never leaves the top of the
#                      screen and the keys always act on the selected row;
#                      actions run behind it, and the rest of the window is a
#                      live tail of m-dev's own progress and of the stack's own
#                      output - aspire, the services, errors and all.
#   m-dev <name|N>     switch straight to that worktree, then show the table
#   m-dev --stop       stop the running stack
#   m-dev --logs       follow the stack log
#   m-cd  [name]       jump a shell to a worktree
#
# How long to wait for a stack to come up. A cold worktree also builds .NET and
# pulls containers, so this is deliberately generous.
: "${M_DEV_TIMEOUT:=420}"

_m_dev_state() { printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/m-dev"; }
_m_dev_log() { printf '%s\n' "$(_m_dev_state)/stack.log"; }

# Empty both panes under the table. Safe to do while a stack or an action is
# live: both logs are written in append mode, so a writer picks up from the new
# end rather than leaving a hole of NULs where its old offset was.
_m_dev_clear_logs() {
  : >"$(_m_dev_log)" 2>/dev/null
  : >"$(_m_dev_action_log)" 2>/dev/null
  return 0
}

# momentum -> main, momentum-betterMobileHeader -> betterMobileHeader.
_m_dev_label() {
  local base="${1##*/}"
  case "$base" in
    momentum)   printf 'main\n' ;;
    momentum-*) printf '%s\n' "${base#momentum-}" ;;
    *)          printf '%s\n' "$base" ;;
  esac
}

# Every worktree as "<label> <branch> <dir>", from git rather than a glob of the
# root, so this is the same list git itself would act on.
_m_dev_worktrees() {
  local dir="" branch=""
  git -C "$(_m_root)/momentum" worktree list --porcelain 2>/dev/null |
    while read -r key value; do
      case "$key" in
        worktree) dir="$value" ;;
        branch)   branch="${value#refs/heads/}" ;;
        "")
          [ -n "$dir" ] && printf '%s %s %s\n' "$(_m_dev_label "$dir")" "${branch:-detached}" "$dir"
          dir="" branch=""
          ;;
      esac
    done
}

# _m_dev_rows <array> [fresh] - the worktree list, cached. git is a fork and the
# interactive table now redraws about once a second, so the list is only re-read
# when it can have changed: a refresh, an action finishing, or a one-shot command.
_M_DEV_WT_CACHE=""
_m_dev_rows() {
  local -n out="$1"
  local line
  if [ -z "$_M_DEV_WT_CACHE" ] || [ "${2:-}" = fresh ]; then
    _M_DEV_WT_CACHE="$(_m_dev_worktrees)"
  fi
  out=()
  while IFS= read -r line; do
    [ -n "$line" ] && out+=("$line")
  done <<<"$_M_DEV_WT_CACHE"
  [ "${#out[@]}" -gt 0 ]
}

_m_dev_pgfile() { printf '%s\n' "$(_m_dev_state)/stack.pgid"; }

# Pids of a live AppHost, whichever worktree it belongs to and whoever started
# it - a `make dev` running in another terminal counts, which is the point.
# Matched on argv[0] being the built AppHost rather than with `pgrep -f`, which
# also matches any shell that merely mentions the path, this file included.
_m_dev_apphost_pids() {
  local pid argv0
  for pid in /proc/[0-9]*; do
    pid="${pid#/proc/}"
    # read, not tr | head: argv[0] is everything up to the first NUL, and a
    # builtin costs no forks. Two per process over a few hundred of them was
    # most of what made the interactive redraw slow enough to see. The redirect
    # is silenced before it runs, because a process can exit between the glob
    # and this read.
    argv0=""
    IFS= read -rd '' argv0 2>/dev/null <"/proc/$pid/cmdline"
    case "$argv0" in
      */Laserfiche.LocalDev.AppHost) printf '%s\n' "$pid" ;;
    esac
  done
}

# The worktree directory the live stack belongs to, matched by walking the known
# worktrees rather than parsing a path: `dotnet run` sits at the repo root while
# the AppHost it spawns sits several directories deeper.
_m_dev_active_dir() {
  local pids pid cwd row label branch dir
  local -a rows
  pids="$(_m_dev_apphost_pids)"
  [ -n "$pids" ] || return 1
  _m_dev_rows rows || return 1
  for row in "${rows[@]}"; do
    read -r label branch dir <<<"$row"
    for pid in $pids; do
      cwd="$(readlink -f "/proc/$pid/cwd" 2>/dev/null)" || continue
      case "$cwd" in "$dir"|"$dir"/*) printf '%s\n' "$dir"; return 0 ;; esac
    done
  done
  return 1
}

_m_dev_ui_up() { ss -ltnH 2>/dev/null | awk '{print $4}' | grep -qE '[:.]3000$'; }

# A label, a branch name, or a 1-based row number -> "<label> <dir>". Case and
# dashes are ignored: the directory is kebab-case (better-mobile-header) while
# the branch it holds is camelCase (betterMobileHeader), and either is a
# reasonable thing to type.
_m_dev_resolve() {
  local want all hit row
  local -a rows
  _m_dev_rows rows fresh || { echo "m-dev: no momentum worktrees found" >&2; return 1; }

  if [[ "$1" =~ ^[0-9]+$ ]]; then
    row="${rows[$(($1 - 1))]}"
    if [ "$1" -lt 1 ] || [ -z "$row" ]; then
      echo "m-dev: no worktree numbered $1 (there are ${#rows[@]})" >&2
      return 1
    fi
    awk '{print $1, $3}' <<<"$row"
    return 0
  fi

  want="$(tr '[:upper:]' '[:lower:]' <<<"${1//-/}")"
  all="$(printf '%s\n' "${rows[@]}")"
  for test in 'k == w' 'index(k, w) == 1 || index(b, w) == 1' 'index(k, w) || index(b, w)'; do
    hit="$(awk -v w="$want" \
      '{ k = tolower($1); gsub(/-/, "", k)
         b = tolower($2); gsub(/-/, "", b)
         if ('"$test"') print $1, $3 }' <<<"$all")"
    [ -n "$hit" ] || continue
    if [ "$(wc -l <<<"$hit")" -eq 1 ]; then
      printf '%s\n' "$hit"
      return 0
    fi
    echo "m-dev: '$1' matches more than one worktree:" >&2
    awk '{print "  " $1}' <<<"$hit" >&2
    return 1
  done
  echo "m-dev: no worktree matching '$1'. Known: $(awk '{printf "%s ", $1}' <<<"$all")" >&2
  return 1
}

# _m_dev_table [sel] [active-dir] [busy-dir] [busy-text]. Passing the active dir
# skips the /proc walk, for a caller that already has it. The busy dir is one an
# action is working on right now, and says so instead of the stack state, which
# is still whatever it was before the action started.
_m_dev_table() {
  local sel="$1" active busy="$3" busytext="$4" i=0 n label branch dir mark stack
  if [ "$#" -ge 2 ]; then
    active="$2"
  else
    active="$(_m_dev_active_dir)" || active=""
  fi
  local -a rows
  _m_dev_rows rows || { echo "no momentum worktrees found"; return 1; }

  # Columns are sized to what is actually in them rather than to a fixed width.
  # Fixed 22/26 made every row 86 characters whether it needed them or not, which
  # wraps on an 80-column terminal - and a wrapped row is what duplicates the
  # bottom line of the frame.
  local lw=8 bw=6
  for n in "${rows[@]}"; do
    read -r label branch dir <<<"$n"
    [ "${#label}" -gt "$lw" ] && lw="${#label}"
    [ "${#branch}" -gt "$bw" ] && bw="${#branch}"
  done

  printf '  %-3s %-*s %-*s %s\n' '#' "$lw" WORKTREE "$bw" BRANCH STACK
  for n in "${rows[@]}"; do
    i=$((i + 1))
    read -r label branch dir <<<"$n"
    if [ -n "$busy" ] && [ "$dir" = "$busy" ]; then
      stack="$busytext"
    elif [ "$dir" = "$active" ]; then
      _m_dev_ui_up && stack="RUNNING  http://localhost:3000" || stack="starting ..."
    else
      stack="-"
    fi
    [ "$i" = "$sel" ] && mark=">" || mark=" "
    printf '%s %-3s %-*s %-*s %s\n' "$mark" "$i" "$lw" "$label" "$bw" "$branch" "$stack"
  done
}

# Every process group holding a stack: the one we launched, plus any AppHost
# started outside m-dev (a `make dev` in another terminal).
_m_dev_stack_pgids() {
  local pgid pid mine
  local -a groups=()
  mine="$(ps -o pgid= -p $$ | tr -d ' ')"

  pgid="$(cat "$(_m_dev_pgfile)" 2>/dev/null)"
  [ -n "$pgid" ] && [ -n "$(pgrep -g "$pgid" 2>/dev/null)" ] && groups+=("$pgid")

  for pid in $(_m_dev_apphost_pids); do
    pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$pgid" ] || continue
    [ "$pgid" = "$mine" ] && continue          # never signal this shell
    [ "$pgid" = 1 ] && continue
    case " ${groups[*]} " in *" $pgid "*) continue ;; esac
    groups+=("$pgid")
  done
  [ "${#groups[@]}" -gt 0 ] && printf '%s\n' "${groups[@]}"
}

# TERM, not INT. Aspire's Ctrl+C shutdown runs off Console.CancelKeyPress, which
# needs a controlling terminal - and setsid deliberately leaves this stack
# without one, so a SIGINT is simply ignored (measured: still fully up after
# 270s). TERM reaches .NET's own shutdown instead, which stops the services and
# removes the containers in about 15s.
_m_dev_stop() {
  local pgid waited=0
  local -a groups=()
  while IFS= read -r pgid; do groups+=("$pgid"); done < <(_m_dev_stack_pgids)

  if [ "${#groups[@]}" -eq 0 ]; then
    echo "no stack running"
    : >"$(_m_dev_log)" 2>/dev/null
    return 0
  fi

  printf 'stopping the stack'
  for pgid in "${groups[@]}"; do kill -TERM -"$pgid" 2>/dev/null; done
  while [ -n "$(_m_dev_stack_pgids)" ] && [ "$waited" -lt 90 ]; do
    printf '.'
    sleep 2
    waited=$((waited + 2))
  done
  echo

  if [ -n "$(_m_dev_stack_pgids)" ]; then
    echo "m-dev: still up after ${waited}s, sending KILL - this can leave containers behind" >&2
    for pgid in "${groups[@]}"; do kill -KILL -"$pgid" 2>/dev/null; done
    sleep 3
  fi
  rm -f "$(_m_dev_pgfile)"

  # Aspire removes its own containers on the way out, but a few seconds after its
  # processes have already gone - so wait before believing any are stranded,
  # otherwise every stop cries wolf.
  local left waited_c=0
  while [ "$waited_c" -lt 30 ]; do
    left="$(docker ps -q 2>/dev/null | wc -l)"
    [ "$left" -eq 0 ] && break
    sleep 2
    waited_c=$((waited_c + 2))
  done
  [ "$left" -gt 0 ] && echo "note: $left container(s) still up after ${waited_c}s; 'docker ps' to look"

  # The stack this log belongs to is gone, so the pane under the table starts
  # empty instead of showing a dead stack's output. The m-dev pane is left
  # alone: it holds this stop's own report, which is the thing to read.
  : >"$(_m_dev_log)" 2>/dev/null
  return 0
}

_m_dev_start() {
  local label="$1" dir="$2" log waited=0
  log="$(_m_dev_log)"
  mkdir -p "$(_m_dev_state)"

  # A fresh worktree has none of its own: they are per-worktree and ~670M, and
  # new-work does not install them. `make dev` spawns ui-app's dev server as a
  # child, so it would fail well into startup rather than up front.
  if [ ! -d "$dir/src/ui-app/node_modules" ]; then
    echo "$label: first run here, installing ui-app dependencies (npm ci, a few minutes)"
    ( cd "$dir/src/ui-app" && npm ci ) || {
      echo "m-dev: npm ci failed in $dir/src/ui-app" >&2
      return 1
    }
  fi

  # setsid so the make/dotnet/AppHost tree is its own process group, which is
  # what lets --stop signal all of it without touching this shell. The inner
  # shell is that group's leader, so its own $$ IS the pgid: recording it here
  # means stopping never has to guess, and works even mid-startup, before the
  # AppHost process itself exists.
  local pgfile
  pgfile="$(_m_dev_pgfile)"
  rm -f "$pgfile"
  : >"$log"
  ( cd "$dir" && setsid bash -c 'echo $$ >"$1"; exec make dev' m-dev "$pgfile" >>"$log" 2>&1 & ) >/dev/null 2>&1

  printf '%s: starting the stack' "$label"
  while [ "$waited" -lt "$M_DEV_TIMEOUT" ]; do
    if _m_dev_ui_up; then
      echo
      echo "$label up: http://localhost:3000  (dashboard :18888)"
      return 0
    fi
    # Exact, so a slow cold build is never mistaken for a failure: if the group
    # we launched has no members left, make/dotnet gave up.
    if [ -s "$pgfile" ] && [ -z "$(pgrep -g "$(cat "$pgfile")" 2>/dev/null)" ]; then
      echo
      echo "m-dev: the stack exited during startup. Last lines of $log:" >&2
      tail -n 15 "$log" >&2
      return 1
    fi
    printf '.'
    sleep 3
    waited=$((waited + 3))
  done
  echo
  echo "m-dev: ui-app was not up within ${waited}s. Last lines of $log:" >&2
  tail -n 15 "$log" >&2
  return 1
}

_m_dev_open() { explorer.exe "$1" >/dev/null 2>&1 & }

# --- actions that run behind the table --------------------------------------
#
# Starting and stopping a stack takes minutes, and the table has to stay on
# screen the whole time, so an action does not run in the foreground: it runs
# detached, writes to the action log, and the interactive loop tails that log
# into a pane under the table - alongside the stack's own log, which is where
# aspire, the services and their errors show up.

_m_dev_action_log() { printf '%s\n' "$(_m_dev_state)/action.log"; }
_m_dev_action_pid() { printf '%s\n' "$(_m_dev_state)/action.pid"; }

# This file, so the detached shell can source it and call back into it.
_M_DEV_SHELL_FILE="${BASH_SOURCE[0]}"

# _m_dev_action_start <function> [args] - run it detached, print its pid.
# Its own session, for two reasons: a plain background job would print bash's
# own "[1] 1234" notice across the frame, and a session can be killed as a group,
# so an action can be dropped without leaving its npm ci or dotnet build behind.
# setsid --fork rather than & for the same reason; --fork is what makes it return
# here immediately.
_m_dev_action_start() {
  local log pidf waited=0
  log="$(_m_dev_action_log)"
  pidf="$(_m_dev_action_pid)"
  mkdir -p "$(_m_dev_state)" 2>/dev/null
  : >"$log" 2>/dev/null
  rm -f "$pidf"
  MOMENTUM_ROOT="$(_m_root)" M_DEV_TIMEOUT="$M_DEV_TIMEOUT" \
    setsid --fork bash -c 'echo $$ >"$1"; . "$2"; shift 2; "$@"' \
      m-dev "$pidf" "$_M_DEV_SHELL_FILE" "$@" >>"$log" 2>&1 </dev/null
  while [ ! -s "$pidf" ] && [ "$waited" -lt 40 ]; do
    sleep 0.05
    waited=$((waited + 1))
  done
  cat "$pidf" 2>/dev/null
}

_m_dev_action_alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }

# Drop a running action, whole session with it. The stack it started is its own
# session and lives on by design - stopping that is a separate action.
_m_dev_action_drop() { [ -n "$1" ] && kill -TERM -"$1" 2>/dev/null; return 0; }

# _m_dev_pane <file> <cols> <lines> [end] - the tail of a log file, as a pane
# under the table. Stripped of anything that would move the cursor or colour the
# rest of the frame, and clipped so no line can wrap: a wrapped line is an extra
# row, which pushes the table off the top of the screen. A log line keeps its
# start, where the message is. With `end` a long line keeps its end instead,
# because that is where a progress line's news is: a row of dots cut from the
# left looks frozen.
_m_dev_pane() {
  local file="$1" width lines="$3" keep="${4:-}"
  [ -s "$file" ] || return 0
  [ "${lines:-0}" -ge 1 ] || return 0
  width=$(( ${2:-100} - 4 ))
  [ "$width" -lt 24 ] && width=24
  tail -n "$lines" "$file" 2>/dev/null |
    awk -v w="$width" -v keep="$keep" '
      BEGIN { esc = sprintf("%c", 27)
              ctl = sprintf("[%c-%c%c-%c%c]", 1, 8, 11, 31, 127) }
      { sub(/.*\r/, "")                             # a line that rewrote itself
        gsub(esc "\\[[0-9;?]*[ -\\/]*[@-~]", "")     # colour, cursor moves
        gsub(/\t/, "  ")
        gsub(ctl, "")
        if (length($0) > w)
          $0 = (keep == "end") ? substr($0, length($0) - w + 1) : substr($0, 1, w)
        print "  " $0 }'
}

# A labelled rule across the window, so it is plain where m-dev stops talking and
# a log starts.
_m_dev_rule() {
  local text="$1" dashes n
  n=$(( ${2:-80} - ${#text} - 5 ))
  [ "$n" -lt 0 ] && n=0
  printf -v dashes '%*s' "$n" ''
  printf '  %s %s' "$text" "${dashes// /-}"
}

# Stop whatever is live and bring the stack up in this worktree instead.
_m_dev_switch() {
  local label="$1" dir="$2" active
  active="$(_m_dev_active_dir)" || active=""

  if [ "$dir" = "$active" ]; then
    if _m_dev_ui_up; then
      echo "$label is already the live stack: http://localhost:3000"
      _m_dev_open http://localhost:3000
      return 0
    fi
    echo "$label is starting already; following its log with --logs may help"
    return 0
  fi

  [ -n "$active" ] && _m_dev_stop
  _m_dev_start "$label" "$dir" || return 1
  _m_dev_open http://localhost:3000
}

# --- drawing the frame -------------------------------------------------------
#
# The table owns the terminal while it is up. Two things it must never do: let a
# line wrap (a wrapped line is an extra row, which scrolls the frame and leaves a
# copy of the bottom line behind), and let anything else print into it.

# The window, read from the tty rather than from COLUMNS, which bash only
# refreshes between commands and so goes stale inside this loop.
_m_dev_size() {
  local size
  size="$(stty size 2>/dev/null)" || size=""
  _M_DEV_ROWS="${size%% *}" _M_DEV_COLS="${size##* }"
  [[ "$_M_DEV_ROWS" =~ ^[0-9]+$ ]] && [ "$_M_DEV_ROWS" -gt 0 ] || _M_DEV_ROWS=24
  [[ "$_M_DEV_COLS" =~ ^[0-9]+$ ]] && [ "$_M_DEV_COLS" -gt 0 ] || _M_DEV_COLS=80
}

# The alternate screen, so the table has the terminal to itself and quitting
# hands back the scrollback untouched. Cursor hidden, and wrapping off as the
# backstop for a line the fit below cannot measure, such as one with wide
# characters in it.
_m_dev_screen_on() { printf '\033[?1049h\033[?25l\033[?7l\033[H\033[2J'; }
_m_dev_screen_off() { printf '\033[?7h\033[?25h\033[?1049l'; }

# A frame cut to the window: every line clipped to the width, the whole thing
# clipped to the height, each line ending in an erase-to-end so a shorter line
# leaves nothing of the longer one it replaced.
_m_dev_fit() {
  local cols="$1" rows="$2" line out="" n=0
  while IFS= read -r line; do
    n=$((n + 1))
    [ "$n" -gt "$rows" ] && break
    [ "${#line}" -gt "$cols" ] && line="${line:0:cols}"
    [ "$n" -gt 1 ] && out+=$'\n'
    out+="$line"$'\033[K'
  done <<<"$3"
  printf '%s' "$out"
}

m-dev() {
  local label dir sel=1 key
  local -a rows

  _M_DEV_WT_CACHE=""                 # a worktree may have come or gone since last time

  case "$1" in
    --stop) _m_dev_stop; echo; _m_dev_table; return 0 ;;
    --logs) tail -f "$(_m_dev_log)"; return $? ;;
  esac

  if [ "$#" -gt 0 ]; then
    read -r label dir < <(_m_dev_resolve "$1") || return 1
    _m_dev_switch "$label" "$dir"
    echo
    _m_dev_table
    return 0
  fi

  # Interactive: the table owns the top of the screen, always, and the keys
  # always act on the selected row. Everything below the table is log: m-dev's
  # own progress on an action, and under it the stack's own output, tailed live so
  # a start, a stop or a crash can be watched where it happens. Actions run
  # detached behind the frame, and enter or s interrupts one, so nothing ever
  # covers the list and there is never a screen to dismiss.
  local frame last="" active stale=1 dirty=1 note="" ticks=0 waits=0 rc=0
  local job="" what="" busy_dir="" busy_text="" seq="" ch="" traps="" bail=""
  local alog slog atext ltext ltitle nl used avail alines llines wt_stale=1
  alog="$(_m_dev_action_log)"
  slog="$(_m_dev_log)"

  # An action a previous m-dev left running is still this one's to report on.
  job="$(cat "$(_m_dev_action_pid)" 2>/dev/null)"
  if _m_dev_action_alive "$job"; then what="an action started earlier"; else job=""; fi

  # Whatever a finished action wrote belongs to an earlier sitting of the table,
  # so the pane starts empty rather than reporting something out of context. The
  # stack log is left alone: it is the running stack's, not this sitting's.
  [ -n "$job" ] || : >"$alog" 2>/dev/null

  # Both signals set a flag rather than acting: the loop is in the middle of a
  # read, and there is a screen to hand back before returning.
  traps="$(trap -p WINCH INT)"
  _M_DEV_RESIZED=0 _M_DEV_QUIT=0
  trap '_M_DEV_RESIZED=1' WINCH
  trap '_M_DEV_QUIT=1' INT
  _m_dev_size
  _m_dev_screen_on

  # The loop's stderr goes to the action log (see the redirect on its done), so
  # a stray diagnostic shows up in the pane instead of on top of the table.
  while :; do
    if [ "$_M_DEV_RESIZED" = 1 ]; then
      _M_DEV_RESIZED=0
      _m_dev_size
      dirty=1
    fi

    if [ "$wt_stale" = 1 ]; then
      _m_dev_rows rows fresh || { bail="m-dev: no momentum worktrees found"; break; }
      wt_stale=0
    fi
    [ "$sel" -gt "${#rows[@]}" ] && sel="${#rows[@]}"
    [ "$sel" -lt 1 ] && sel=1

    if [ -n "$job" ] && ! _m_dev_action_alive "$job"; then
      note="$what: done"
      job="" busy_dir="" busy_text=""
      stale=1 dirty=1 wt_stale=1
    fi

    # Finding the live stack walks /proc. Moving the cursor cannot change it, so
    # it is only re-read after something that can - plus every few seconds on the
    # timer, which is how RUNNING appears without pressing anything.
    if [ "$stale" = 1 ]; then
      active="$(_m_dev_active_dir)" || active=""
      stale=0
    fi

    # The frame, top down: the table and the keys it answers to, then whatever is
    # left of the window given to the logs - m-dev's own progress first, if it has
    # anything to say, and the stack's output filling the rest.
    frame="momentum stack - one worktree at a time"$'\n\n'
    frame+="$(_m_dev_table "$sel" "$active" "$busy_dir" "$busy_text")"$'\n\n'
    frame+="  up/down select   enter switch   s stop   c clear logs   r refresh   q quit"
    [ -n "$job" ] && frame+=$'\n'"  running: $what   (enter or s interrupts it)"
    [ -n "$note" ] && frame+=$'\n'"  $note"

    # Title, blank, table header, its rows, blank, keys, and the two optional
    # lines: what is left is the log's, and no pane may be a row taller than
    # that or the table scrolls off the top.
    used=$(( 5 + ${#rows[@]} ))
    [ -n "$job" ] && used=$((used + 1))
    [ -n "$note" ] && used=$((used + 1))
    avail=$(( _M_DEV_ROWS - used ))

    atext="" alines=0
    if [ "$avail" -ge 6 ]; then
      atext="$(_m_dev_pane "$alog" "$_M_DEV_COLS" 3 end)"
      if [ -n "$atext" ]; then
        nl="${atext//[!$'\n']/}"
        alines=$(( ${#nl} + 2 ))                   # its lines, plus the rule
        frame+=$'\n'"$(_m_dev_rule 'm-dev' "$_M_DEV_COLS")"$'\n'"$atext"
      fi
    fi

    llines=$(( avail - alines - 1 ))
    if [ "$llines" -ge 1 ]; then
      ltext="$(_m_dev_pane "$slog" "$_M_DEV_COLS" "$llines")"
      if [ -n "$ltext" ]; then
        [ -n "$active" ] && ltitle="aspire: $(_m_dev_label "$active")" \
                         || ltitle="aspire (nothing running)"
        frame+=$'\n'"$(_m_dev_rule "$ltitle" "$_M_DEV_COLS")"$'\n'"$ltext"
      fi
    fi

    # One write: home, the frame cut to the window, then erase whatever the last
    # one left below. Clearing first blanks the screen for as long as the redraw
    # takes, which is the flash you see when holding down an arrow key - so the
    # frame is only written when it differs from the one already up, which an
    # idle table with a quiet log does not.
    if [ "$dirty" = 1 ] || [ "$frame" != "$last" ]; then
      printf '\033[H%s\033[J' "$(_m_dev_fit "$_M_DEV_COLS" "$_M_DEV_ROWS" "$frame")"
      last="$frame" dirty=0
    fi

    # Always a timed read, never a blocking one: bash runs a trap only once the
    # builtin returns, so a blocking read swallows Ctrl+C until the next key
    # press, and there is a screen to hand back before this can return. A key
    # leaves here at once, so the row keys stay instant; otherwise the wait ends
    # about once a second, which is what keeps the log panes moving, and the
    # /proc walk behind the STACK column is only redone on every fourth of those.
    waits=0
    while :; do
      IFS= read -rsn1 -t 0.25 key && break
      rc=$?
      [ "$_M_DEV_QUIT" = 1 ] && break 2
      [ "$rc" -le 128 ] && break 2                 # eof, not a timeout
      [ "$_M_DEV_RESIZED" = 1 ] && continue 2
      waits=$((waits + 1))
      if [ "$waits" -ge 4 ]; then
        ticks=$((ticks + 1))
        [ "$((ticks % 4))" = 0 ] && stale=1
        continue 2
      fi
    done
    [ "$_M_DEV_QUIT" = 1 ] && break
    note=""

    case "$key" in
      $'\e')
        # Read the whole sequence, not a fixed two bytes: anything left in the
        # buffer is read as a keystroke on the next pass, and the tail of an
        # unhandled sequence can spell s or q.
        seq=""
        IFS= read -rsn1 -t 0.05 ch || ch=""
        case "$ch" in
          '['|'O')
            while IFS= read -rsn1 -t 0.05 ch; do
              seq+="$ch"
              case "$ch" in [a-zA-Z~]) break ;; esac
            done
            ;;
        esac
        case "$seq" in
          'A') sel=$((sel - 1)) ;;
          'B') sel=$((sel + 1)) ;;
        esac
        ;;
      'k') sel=$((sel - 1)) ;;
      'j') sel=$((sel + 1)) ;;
      '')
        read -r label _ dir <<<"${rows[$((sel - 1))]}"
        [ -n "$job" ] && { _m_dev_action_drop "$job"; note="dropped $what"; }
        what="switch to $label" busy_dir="$dir" busy_text="starting ..."
        job="$(_m_dev_action_start _m_dev_switch "$label" "$dir")"
        [ -n "$job" ] || { note="could not start $what"; busy_dir="" busy_text=""; }
        stale=1
        ;;
      's'|'S')
        [ -n "$job" ] && { _m_dev_action_drop "$job"; note="dropped $what"; }
        what="stop the stack" busy_dir="$active" busy_text="stopping ..."
        job="$(_m_dev_action_start _m_dev_stop)"
        [ -n "$job" ] || { note="could not start $what"; busy_dir="" busy_text=""; }
        stale=1
        ;;
      'c'|'C') _m_dev_clear_logs; dirty=1 ;;
      'r'|'R') stale=1 wt_stale=1 ;;
      'q'|'Q') break ;;
    esac
  done 2>>"$(_m_dev_action_log)"

  # One way out, so the terminal is always handed back the way it was found.
  _m_dev_screen_off
  trap - WINCH INT
  [ -n "$traps" ] && eval "$traps"
  [ -n "$bail" ] && { echo "$bail" >&2; return 1; }
  [ -n "$job" ] && echo "m-dev: '$what' is still running; m-dev --logs follows the stack"
  return 0
}

# m-cd [name] - jump to a worktree; no argument goes to the default one.
m-cd() {
  local label dir
  if [ "$#" -eq 0 ]; then
    cd "$(_m_root)/momentum" || return 1
    return 0
  fi
  read -r label dir < <(_m_dev_resolve "$1") || return 1
  cd "$dir" || return 1
}

# --- m-panel: the popup front door ------------------------------------------
#
# One popup, one menu. ctrl+alt+d opens this instead of going straight to a
# single panel: a letter runs one full-screen inside the same popup, and
# quitting that panel comes back here rather than closing the popup. The
# letters are the chords the panels already had, so ctrl+alt+d then d is still
# the stack and ctrl+alt+d then y is still teams-sync.
#
# Adding a panel is one line in _M_PANELS. A panel whose command is not
# installed on this box is left out of the menu rather than shown broken, which
# is what lets a line land here before the thing it runs exists.
#
#          key|name|what it is for|command
_M_PANELS=(
  't|work queues|one queue per worktree, and the runner that drains them|m-board'
  'd|the momentum stack|switch which worktree runs on :3000|m-dev'
  'y|teams-sync|cards out and replies in, together or one at a time|herdr-teams-toggle panel'
  'w|worktree teardown|what is safe to remove, and d removes it|m-teardown'
)

# Can the first word of a panel command run here? A shell function counts,
# which is how m-dev qualifies.
_m_panel_have() { command -v "${1%% *}" >/dev/null 2>&1; }

m-panel() {
  local rec key name hint cmd pick rc i
  local -a keys names hints cmds

  for rec in "${_M_PANELS[@]}"; do
    IFS='|' read -r key name hint cmd <<<"$rec"
    _m_panel_have "$cmd" || continue
    keys+=("$key") names+=("$name") hints+=("$hint") cmds+=("$cmd")
  done

  if [ "${#keys[@]}" -eq 0 ]; then
    echo "m-panel: none of the panels are installed on this box" >&2
    return 1
  fi

  # No alternate screen here. m-dev switches to it and back on its own and a
  # terminal has only the one, so opening a second would leave the buffer
  # unbalanced the moment a panel exits. A plain clear nests fine.
  while :; do
    clear
    printf 'momentum panels\n\n'
    for i in "${!keys[@]}"; do
      printf '  %s   %-22s %s\n' "${keys[$i]}" "${names[$i]}" "${hints[$i]}"
    done
    printf '\n  a letter opens a panel   q closes this\n'

    IFS= read -rsn1 pick || { clear; return 0; }

    # An arrow key arrives as escape plus a bracket sequence. Read the whole
    # thing, because anything left behind is read as a keystroke on the next
    # pass and the tail of one of these spells q. Escape on its own closes.
    if [ "$pick" = $'\e' ]; then
      IFS= read -rsn1 -t 0.05 pick || { clear; return 0; }
      case "$pick" in
        '['|'O')
          while IFS= read -rsn1 -t 0.05 pick; do
            case "$pick" in [a-zA-Z~]) break ;; esac
          done
          ;;
      esac
      continue
    fi

    case "$pick" in
      q|Q) clear; return 0 ;;
    esac

    for i in "${!keys[@]}"; do
      [ "$pick" = "${keys[$i]}" ] || continue
      clear
      # Deliberately unquoted: every command is a literal in _M_PANELS above,
      # and the word split is what turns 'herdr-teams-toggle panel' into a
      # command plus its argument.
      # shellcheck disable=SC2086
      ${cmds[$i]}
      rc=$?
      # A panel that failed has something to say and the next repaint would
      # wipe it. What one prints on a clean exit is still lost; nothing needs
      # that yet.
      if [ "$rc" -ne 0 ]; then
        printf '\n  %s exited %s. press a key\n' "${names[$i]}" "$rc"
        IFS= read -rsn1 _
      fi
      break
    done
  done
}
