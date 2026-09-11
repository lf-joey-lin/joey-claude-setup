# mqueue: one work-item queue per momentum worktree, and the runner that drains
# them.
#
# You make the worktree yourself (m-work, and whatever prototyping follows).
# This owns what happens after: items filed against that worktree, run one at a
# time in it, and a runner that walks N worktrees at once in round robin.
#
# The store is one markdown file per item under ~/m-code/mqueue/<label>/, with
# frontmatter this file owns and a body that is the spec. The body is what the
# agent is sent, so there is nothing to translate on the way out. Runtime state
# is separate and lives in the cache dir, because it is not worth committing.
#
# Source from ~/.bashrc after momentum.sh and herdr-momentum.sh: _m_dev_label,
# _m_dev_worktrees and _m_root come from the first, _m_herdr_name from the
# second. Override the store with MQUEUE_ROOT, and turn the auto-commit off
# with MQUEUE_GIT=0.

_mqu_root()  { printf '%s\n' "${MQUEUE_ROOT:-$HOME/m-code/mqueue}"; }
_mqu_state() { printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/mqueue"; }
_mqu_log()   { printf '%s\n' "$(_mqu_state)/runner.log"; }

# The store is a git repo, so `git log -p <label>/<id>.md` is the record of how
# a rough note turned into a spec. Never fatal: a failure here must not lose the
# write that just happened.
_mqu_git() {
  [ "${MQUEUE_GIT:-1}" = 1 ] || return 0
  local d
  d="$(_mqu_root)"
  [ -d "$d/.git" ] || git -C "$d" init -q 2>/dev/null || return 0
  git -C "$d" add -A 2>/dev/null
  git -C "$d" commit -q -m "$1" 2>/dev/null
  return 0
}

_mqu_slug() {
  local s
  s="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' |
    sed -E 's/-+/-/g; s/^-//; s/-$//')"
  # Cut a long title back to a word boundary, so an id reads as words rather
  # than ending in a chopped one.
  if [ "${#s}" -gt 32 ]; then
    s="${s:0:32}"
    [ "${s%-*}" != "$s" ] && s="${s%-*}"
  fi
  printf '%s\n' "$s"
}

# --- worktrees ---------------------------------------------------------------

# "<label> <branch> <dir>" per worktree, skipping the default checkout: that one
# stays on main and is never worked in, so it can never hold a queue.
_mqu_worktrees() {
  _m_dev_worktrees 2>/dev/null | while read -r label branch dir; do
    [ "$label" = main ] && continue
    printf '%s %s %s\n' "$label" "$branch" "$dir"
  done
}

_mqu_labels() { _mqu_worktrees | awk '{print $1}'; }

_mqu_dir_of() {
  _mqu_worktrees | awk -v l="$1" '$1 == l { print $3; exit }'
}

# --- the store ---------------------------------------------------------------

_mqu_lane_dir() { printf '%s\n' "$(_mqu_root)/$1"; }
_mqu_file()     { printf '%s\n' "$(_mqu_root)/$1.md"; }

# Filenames carry the order, so reordering is a rename and inserting ahead of
# everything is a lower prefix. Steps of ten leave room to do that by hand.
_mqu_next_order() {
  local d last
  d="$(_mqu_lane_dir "$1")"
  last="$(ls "$d" 2>/dev/null | sed -n 's/^\([0-9][0-9][0-9]\)-.*/\1/p' | sort -n | tail -1)"
  printf '%03d\n' $(( 10#${last:-0} + 10 ))
}

# _mqu_add <label> <title> - write a new item, print its id.
_mqu_add() {
  local label="$1" title="$2" d id base n=2
  title="${title#"${title%%[![:space:]]*}"}"
  title="${title%"${title##*[![:space:]]}"}"
  [ -n "$label" ] && [ -n "$title" ] || return 1
  d="$(_mqu_lane_dir "$label")"
  mkdir -p "$d" || return 1
  base="$(_mqu_next_order "$label")-$(_mqu_slug "$title")"
  id="$label/$base"
  while [ -e "$(_mqu_file "$id")" ]; do id="$label/$base-$n"; n=$(( n + 1 )); done
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'title: %s\n' "$title"
    printf 'status: queued\n'
    printf 'mode: %s\n' "${MQUEUE_MODE:-loom}"
    printf 'created: %s\n' "$(date -Iseconds)"
    printf -- '---\n\n%s\n' "$title"
  } >"$(_mqu_file "$id")" || return 1
  _mqu_git "add $id"
  printf '%s\n' "$id"
}

# Everything after the closing --- of the frontmatter. This is the spec. The
# leading blank line the template writes is stripped, so a prompt built out of
# this does not start with an empty line; command substitution takes the
# trailing ones.
_mqu_body() {
  awk '/^---[[:space:]]*$/ && n < 2 { n++; next } n >= 2' "$(_mqu_file "$1")" |
    sed -e '/./,$!d'
}

# Both accessors go through awk with the key and value passed as variables, so a
# note carrying quotes, slashes or a pipe cannot turn into part of the program.
# Runs write their own error text into `note`, and that text is whatever herdr
# said.
_mqu_get() {
  [ -f "$(_mqu_file "$1")" ] || return 0
  awk -v key="$2" '
    /^---[[:space:]]*$/ { n++; if (n == 2) exit; next }
    n == 1 && index($0, key ": ") == 1 { print substr($0, length(key) + 3); exit }
  ' "$(_mqu_file "$1")"
}

# Rewrite a frontmatter field, or add one the item has never carried at the end
# of the block, so the file still reads top to bottom after a run has stamped
# its timings and verdict on it.
_mqu_set() {
  local f tmp
  f="$(_mqu_file "$1")"
  [ -f "$f" ] || return 1
  tmp="$f.tmp$$"
  awk -v key="$2" -v val="$3" '
    /^---[[:space:]]*$/ {
      n++
      if (n == 2 && !set) { print key ": " val; set = 1 }
      print; next
    }
    n == 1 && index($0, key ": ") == 1 {
      if (!set) { print key ": " val; set = 1 }
      next
    }
    { print }
  ' "$f" >"$tmp" && mv "$tmp" "$f"
}

# The first line with anything on it, trimmed. That line is the item's title,
# so writing a spec is all it takes to name it.
_mqu_first_line() {
  sed -n '/[^[:space:]]/{s/^[[:space:]]*//;s/[[:space:]]*$//;p;q;}' "$1"
}

# Replace an item's body with what is in <file>, and retitle it from that file's
# first line. The frontmatter is copied through untouched, which is what lets
# the editor be handed the body alone. A file with nothing in it changes
# nothing, so quitting the editor without writing cannot blank an item. The
# title goes through the environment rather than awk -v, because -v would read a
# backslash in it as an escape and a stray newline would break the block.
_mqu_set_body() {
  local f title tmp
  f="$(_mqu_file "$1")"
  [ -f "$f" ] || return 1
  title="$(_mqu_first_line "$2")"
  [ -n "$title" ] || return 1
  tmp="$f.tmp$$"
  MQU_TITLE="$title" awk '
    /^---[[:space:]]*$/ { n++; print; if (n == 2) exit; next }
    n == 1 && index($0, "title: ") == 1 { print "title: " ENVIRON["MQU_TITLE"]; next }
    { print }
  ' "$f" >"$tmp" || return 1
  printf '\n' >>"$tmp"
  cat "$2" >>"$tmp" || return 1
  mv "$tmp" "$f"
}

# status, id, mode, title - one line per item in one lane, in file order, which
# is the order the prefixes give. One awk over the lane, not one per file.
_mqu_rows() {
  local d
  d="$(_mqu_lane_dir "$1")"
  [ -d "$d" ] || return 0
  awk '
    FNR == 1 { id = ""; st = ""; ti = ""; md = ""; n = 0 }
    /^---[[:space:]]*$/ {
      n++
      if (n == 2 && id != "") print st "\t" id "\t" md "\t" ti
      next
    }
    n == 1 && /^id: /     { id = substr($0, 5) }
    n == 1 && /^status: / { st = substr($0, 9) }
    n == 1 && /^mode: /   { md = substr($0, 7) }
    n == 1 && /^title: /  { ti = substr($0, 8) }
  ' "$d"/*.md 2>/dev/null
}

# "<queued> <running> <blocked> <done>" for one lane.
_mqu_counts() {
  _mqu_rows "$1" | awk -F'\t' '
    { c[$1]++ }
    END { printf "%d %d %d %d\n", c["queued"], c["running"], c["blocked"], c["done"] }'
}

_mqu_first_queued() {
  _mqu_rows "$1" | awk -F'\t' '$1 == "queued" { print $2; exit }'
}

_mqu_running_id() {
  _mqu_rows "$1" | awk -F'\t' '$1 == "running" { print $2; exit }'
}

# A lane is busy while anything in it is running. This is the invariant the
# whole scheduler rests on: one running item per worktree, whatever N is, because
# a worktree is one working tree and one branch and two runs would fight over
# both.
_mqu_lane_busy() { [ -n "$(_mqu_running_id "$1")" ]; }

_mqu_running_count() {
  local label n=0
  while read -r label; do
    [ -n "$label" ] && _mqu_lane_busy "$label" && n=$(( n + 1 ))
  done < <(_mqu_labels)
  printf '%d\n' "$n"
}

# --- the agent ---------------------------------------------------------------

_mqu_agent_of() { _m_herdr_name "$(_mqu_dir_of "$1")" 2>/dev/null; }

# One herdr call answers for every agent, so callers that ask about several in a
# row (the board's redraw, the runner's fill pass) pay for one fork rather than
# one each. Pass fresh to re-read.
_MQU_AGENTS=""
_mqu_agents_load() {
  if [ -z "$_MQU_AGENTS" ] || [ "${1:-}" = fresh ]; then
    _MQU_AGENTS="$(herdr agent list 2>/dev/null |
      jq -r '.result.agents[] | [(.name // .pane_id), .agent_status] | @tsv' 2>/dev/null)"
  fi
  return 0
}

# idle | working | blocked | done | "" when herdr has no agent by that name,
# which is what a worktree with no space open looks like.
_mqu_agent_status() {
  local name
  name="$(_mqu_agent_of "$1")"
  [ -n "$name" ] || return 0
  _mqu_agents_load
  printf '%s\n' "$_MQU_AGENTS" | awk -F'\t' -v n="$name" '$1 == n { print $2; exit }'
}

# --- the receipt and the ledger ----------------------------------------------
#
# Two different questions. The receipt says the run is over. The ledger says
# what happened in it. A settled agent answers neither: it means the turn
# ended, which is not the same claim at all.

# A run's last act is one line at artifacts/loom/<slug>-status (the loom
# contract, "The end-of-run receipt"). That line carries its own timestamp, so
# comparing it with the one taken at dispatch is what tells this run's receipt
# from the previous round's. Empty when the run has not written one.
_mqu_receipt() {
  local f
  f="$(ls -t "$1"/artifacts/loom/*-status 2>/dev/null | head -1)"
  [ -n "$f" ] || return 0
  head -1 "$f" 2>/dev/null
}

# One ledger per branch, so the glob normally matches exactly one file. Newest
# wins if a branch somehow carries two.
_mqu_ledger() {
  ls -t "$1"/artifacts/loom/*-ledger.md 2>/dev/null | head -1
}

# Has the ledger sat still for <seconds>? A live run appends to it at every
# stage boundary. No ledger at all counts as still.
_mqu_ledger_quiet() {
  local f
  f="$(_mqu_ledger "$1")"
  [ -n "$f" ] || return 0
  [ $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || printf 0) )) -ge "$2" ]
}

# Did the ledger move after <iso>? Without a receipt that is the only thing
# separating this run's Land mark from an earlier round's, because a lane's
# later items are rounds in the one file.
_mqu_ledger_after() {
  local f t
  f="$(_mqu_ledger "$1")"
  [ -n "$f" ] || return 1
  t="$(date -d "${2:-@0}" +%s 2>/dev/null)" || return 1
  [ "$(stat -c %Y "$f" 2>/dev/null || printf 0)" -gt "${t:-0}" ]
}

# landed | blocked | unfinished | none. Only read when a run left no receipt,
# to say something useful about why. The last Land heading is the current
# round's, which is why this reads the tail rather than the first match, and it
# is matched at any depth: a round nests its stages one level down, so round two
# onwards writes `### Land`.
_mqu_landed() {
  local f mark
  f="$(_mqu_ledger "$1")"
  if [ -z "$f" ]; then printf 'none\n'; return 0; fi
  mark="$(grep -o '^#\{2,\} Land - \[.\]' "$f" 2>/dev/null | tail -1 | sed 's/.*\[\(.\)\].*/\1/')"
  case "$mark" in
    x)  printf 'landed\n' ;;
    '!') printf 'blocked\n' ;;
    '') printf 'none\n' ;;
    *)  printf 'unfinished\n' ;;
  esac
}

# --- dispatch ----------------------------------------------------------------
#
# The item goes to the worktree's own claude in its herdr space, not to a
# headless claude: those panes already run in auto mode, so there is no new
# permission surface, and the run shows up in the sidebar where blocked sorts to
# the top. herdr blocks until the agent settles, so the dispatcher is also the
# thing that knows when the run is over.

_mqu_item_log() { printf '%s\n' "$(_mqu_state)/items/${1//\//__}.log"; }

# The text actually typed at the agent. Flags come before the body because a
# body is often several lines and a trailing flag reads as part of it.
_mqu_prompt() {
  local id="$1" trigger="$2" mode dir solo=""
  mode="$(_mqu_get "$id" mode)"
  dir="$(_mqu_dir_of "${id%%/*}")"
  # The runner only ever sends solo runs: an attended run has two ask moments,
  # and to the scheduler "the queue advanced" and "the queue is waiting on you"
  # look identical. Solo also never pushes, so an unattended batch cannot put
  # anything on origin. A run started by hand from the board is attended, which
  # is the reason to start one by hand.
  [ "$trigger" = runner ] && solo=" --solo"
  case "$mode" in
    loom)   printf '/loom --in %s%s %s\n' "$dir" "$solo" "$(_mqu_body "$id")" ;;
    finish) printf '/loom --retrofit%s\n' "$solo" ;;
    *)      _mqu_body "$id" ;;
  esac
}

# Runs detached, one per item. Everything it learns it writes back into the
# item, so the board and the runner both read the same state and neither has to
# watch a process.
_mqu_run_item() {
  local id="$MQU_ID" trigger="$MQU_TRIGGER" label dir name rc out
  local baseline receipt poll grace quiet deadline settled=0 why verdict ledger
  label="${id%%/*}"
  dir="$(_mqu_dir_of "$label")"
  name="$(_mqu_agent_of "$label")"
  baseline="$(_mqu_get "$id" baseline)"

  _mqu_set "$id" pid "$$"
  printf '=== %s  %s  (%s)\n' "$(date -Iseconds)" "$id" "$trigger"

  # herdr's wait is a turn primitive, not a run primitive - its own help says a
  # turn already in flight may match - so it is used here only to see the agent
  # pick the prompt up. Waiting on idle or done instead is what used to end an
  # item thirteen minutes into an eight-hour run and hand the slot to the next
  # worktree. A non-zero exit here is not fatal: a short turn can settle before
  # `working` is ever observed, and the wait below finds out either way.
  # Multiline bodies are safe - herdr pastes with the pane's bracketed-paste
  # mode and sends one Enter after the whole text.
  out="$(herdr agent prompt "$name" "$(_mqu_prompt "$id" "$trigger")" \
    --wait --until working --timeout "${MQUEUE_START_TIMEOUT:-30000}" 2>&1)"
  rc=$?
  printf '%s\n' "$out"

  # Now wait for the run itself to end. Three ways out, in this order: it writes
  # its receipt, or it stops looking alive at all, or it runs out of time.
  # "Stops looking alive" needs both halves - herdr has been seen calling a live
  # run done for a long stretch, and a run mid-stage writes no ledger for tens
  # of minutes - so a lane is only given up when neither has moved.
  poll="${MQUEUE_POLL:-20}"
  grace="${MQUEUE_SETTLE_POLLS:-15}"
  quiet="${MQUEUE_QUIET:-600}"
  deadline=$(( $(date +%s) + ${MQUEUE_TIMEOUT:-14400000} / 1000 ))
  while :; do
    sleep "$poll"
    receipt="$(_mqu_receipt "$dir")"
    if [ -n "$receipt" ] && [ "$receipt" != "$baseline" ]; then why=receipt; break; fi
    _mqu_agents_load fresh
    case "$(_mqu_agent_status "$label")" in
      idle | done) settled=$(( settled + 1 )) ;;
      *)           settled=0 ;;
    esac
    if [ "$settled" -ge "$grace" ] && _mqu_ledger_quiet "$dir" "$quiet"; then
      why=settled; break
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then why=timeout; break; fi
  done
  printf '%s  ended: %s\n' "$(date -Iseconds)" "$why"

  if [ "$why" = receipt ]; then
    verdict="$(printf '%s' "$receipt" | awk '{print $2}')"
    if [ "$verdict" = landed ]; then
      _mqu_set "$id" status done
    else
      _mqu_set "$id" status blocked
    fi
    _mqu_set "$id" note "$receipt"
  else
    # No receipt, so the run did not end the way the contract says a run ends.
    # The ledger is all that is left to read, and its Land mark is only this
    # run's if the file moved after dispatch.
    ledger="$(_mqu_landed "$dir")"
    printf 'no receipt, ledger says %s\n' "$ledger"
    if [ "$ledger" = landed ] && _mqu_ledger_after "$dir" "$(_mqu_get "$id" started)"; then
      _mqu_set "$id" status done
      _mqu_set "$id" note "landed, no receipt"
    else
      # A stopped run, not a finished one, and the lane stays stopped so the
      # runner cannot stack another item on top of a failure it cannot see.
      _mqu_set "$id" status blocked
      if [ "$why" = timeout ]; then
        _mqu_set "$id" note "timed out after ${MQUEUE_TIMEOUT:-14400000}ms, ledger $ledger"
      elif [ "$rc" -ne 0 ]; then
        _mqu_set "$id" note "herdr exit $rc: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)"
      else
        _mqu_set "$id" note "agent settled without a receipt, ledger $ledger"
      fi
    fi
  fi
  _mqu_set "$id" finished "$(date -Iseconds)"
  _mqu_git "finish $id"
}

# _mqu_dispatch <id> <runner|manual> - start one item. Fails without starting
# anything when the lane is busy or the agent is not ready, so a caller can just
# move on to the next worktree.
_mqu_dispatch() {
  local id="$1" trigger="${2:-manual}" label status log
  label="${id%%/*}"

  [ -n "$(_mqu_dir_of "$label")" ] || { echo "mqueue: no worktree for $label" >&2; return 1; }
  _mqu_lane_busy "$label" && { echo "mqueue: $label already has an item running" >&2; return 1; }

  # Always against a freshly read agent list. The cache is there for a redraw
  # asking about ten worktrees at once; a runner that kept it would still be
  # dispatching against what herdr said when the loop started.
  _mqu_agents_load fresh

  # Only ever type at a settled agent. herdr rejects a submission to a blocked
  # one outright, and against a working one its wait can match the turn already
  # in flight rather than ours, which would mark the item finished off somebody
  # else's work. idle and done are both settled: done is an agent that announced
  # a result and is still sitting at its prompt, which is most of them.
  status="$(_mqu_agent_status "$label")"
  case "$status" in
    idle | done) ;;
    '') echo "mqueue: $label has no herdr agent - run m-space in it first" >&2; return 1 ;;
    *)  echo "mqueue: $label's agent is $status, not idle" >&2; return 1 ;;
  esac

  log="$(_mqu_item_log "$id")"
  mkdir -p "$(dirname "$log")"
  # What the worktree's receipt said before this run touched it. The lane's
  # earlier items left theirs in the same place, so "a receipt exists" is not
  # the signal - "the receipt changed" is.
  _mqu_set "$id" baseline "$(_mqu_receipt "$(_mqu_dir_of "$label")")"
  _mqu_set "$id" status running
  _mqu_set "$id" pid ""
  _mqu_set "$id" started "$(date -Iseconds)"
  _mqu_set "$id" note ""
  _mqu_git "dispatch $id"
  MQU_ID="$id" MQU_TRIGGER="$trigger" setsid bash -lic _mqu_run_item >>"$log" 2>&1 &
  return 0
}

# --- the runner --------------------------------------------------------------

_mqu_n() {
  local n
  n="$(cat "$(_mqu_state)/n" 2>/dev/null)"
  [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] || n=1
  printf '%d\n' "$n"
}

_mqu_set_n() {
  [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] || return 1
  mkdir -p "$(_mqu_state)"
  printf '%s\n' "$1" >"$(_mqu_state)/n"
}

_mqu_cursor()     { cat "$(_mqu_state)/cursor" 2>/dev/null; }
_mqu_set_cursor() { mkdir -p "$(_mqu_state)"; printf '%s\n' "$1" >"$(_mqu_state)/cursor"; }

_mqu_pidfile() { printf '%s\n' "$(_mqu_state)/runner.pid"; }
_mqu_runner_pid() { cat "$(_mqu_pidfile)" 2>/dev/null; }
_mqu_runner_alive() {
  local p
  p="$(_mqu_runner_pid)"
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null
}

# A dispatcher that died without writing a verdict - killed, or the box went
# down mid-run - leaves its item at running forever, and that lane would never
# take another. The grace window covers the gap between dispatch and the
# dispatcher writing its own pid.
_mqu_reap() {
  local label id pid started age now
  now="$(date +%s)"
  while read -r label; do
    [ -n "$label" ] || continue
    id="$(_mqu_running_id "$label")"
    [ -n "$id" ] || continue
    pid="$(_mqu_get "$id" pid)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then continue; fi
    if [ -z "$pid" ]; then
      started="$(_mqu_get "$id" started)"
      age=$(( now - $(date -d "${started:-@0}" +%s 2>/dev/null || printf 0) ))
      [ "$age" -lt 120 ] && continue
    fi
    _mqu_set "$id" status blocked
    _mqu_set "$id" note "dispatcher gone without a verdict"
    _mqu_set "$id" finished "$(date -Iseconds)"
    _mqu_git "reap $id"
    printf '%s  reaped %s\n' "$(date -Iseconds)" "$id"
  done < <(_mqu_labels)
}

# Round robin: walk the worktrees from one past whoever went last, take the
# first that has queued work and nothing running, and stop when N lanes are
# busy. At N=1 that is one item from each worktree in turn; raise N and the same
# walk just fills more lanes.
_mqu_fill() {
  local n count cur start i k label id
  local -a labels
  mapfile -t labels < <(_mqu_labels)
  [ "${#labels[@]}" -gt 0 ] || return 0

  n="$(_mqu_n)"
  count="$(_mqu_running_count)"
  cur="$(_mqu_cursor)"
  start=0
  for i in "${!labels[@]}"; do
    [ "${labels[$i]}" = "$cur" ] && { start=$(( i + 1 )); break; }
  done

  for (( k = 0; k < ${#labels[@]}; k++ )); do
    [ "$count" -ge "$n" ] && break
    label="${labels[$(( (start + k) % ${#labels[@]} ))]}"
    _mqu_lane_busy "$label" && continue
    id="$(_mqu_first_queued "$label")"
    [ -n "$id" ] || continue
    if _mqu_dispatch "$id" runner; then
      _mqu_set_cursor "$label"
      count=$(( count + 1 ))
      printf '%s  dispatched %s\n' "$(date -Iseconds)" "$id"
    fi
  done
}

_mqu_tick() { _mqu_reap; _mqu_fill; }

_mqu_loop() {
  # Written here rather than worked out by the caller: setsid forks or does not
  # depending on whether the caller was already a process group leader, so $! is
  # not reliably this loop.
  mkdir -p "$(_mqu_state)"
  printf '%s\n' "$$" >"$(_mqu_pidfile)"
  printf '%s  runner up, N=%s\n' "$(date -Iseconds)" "$(_mqu_n)"
  while :; do
    [ -f "$(_mqu_state)/stop" ] && break
    _mqu_tick
    sleep "${MQUEUE_TICK:-10}"
  done
  printf '%s  runner down\n' "$(date -Iseconds)"
  rm -f "$(_mqu_pidfile)" "$(_mqu_state)/stop"
}

# m-run [start|stop|n <N>|tick|log] - the runner, from any shell. No argument
# prints what it is doing.
m-run() {
  local state log
  state="$(_mqu_state)"
  log="$(_mqu_log)"
  mkdir -p "$state"

  case "${1:-status}" in
    start)
      if _mqu_runner_alive; then echo "m-run: already running (pid $(_mqu_runner_pid))"; return 0; fi
      rm -f "$state/stop" "$(_mqu_pidfile)"
      setsid bash -lic _mqu_loop >>"$log" 2>&1 &
      # The loop writes its own pid file, so this only waits for it to appear.
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        _mqu_runner_alive && break
        sleep 0.2
      done
      if _mqu_runner_alive; then
        echo "m-run: started, N=$(_mqu_n). log: $log"
      else
        echo "m-run: it did not come up. log: $log" >&2
        return 1
      fi
      ;;
    stop)
      if ! _mqu_runner_alive; then echo "m-run: not running"; rm -f "$(_mqu_pidfile)"; return 0; fi
      # The stop file first, so the loop finishes the tick it is in rather than
      # dying between a status write and its commit. The kill is the fallback
      # for a loop asleep on a long tick.
      : >"$state/stop"
      kill -TERM "$(_mqu_runner_pid)" 2>/dev/null
      rm -f "$(_mqu_pidfile)"
      echo "m-run: stopped. items already dispatched keep running"
      ;;
    n)
      _mqu_set_n "$2" || { echo "usage: m-run n <number of lanes, 1 or more>" >&2; return 1; }
      echo "m-run: N=$2"
      ;;
    tick) _mqu_tick ;;
    log)  tail -f "$log" ;;
    status)
      local label q r b d
      if _mqu_runner_alive; then
        echo "runner: on (pid $(_mqu_runner_pid))  N=$(_mqu_n)  last lane: $(_mqu_cursor)"
      else
        echo "runner: off  N=$(_mqu_n)"
      fi
      while read -r label; do
        [ -n "$label" ] || continue
        read -r q r b d < <(_mqu_counts "$label")
        printf '  %-24s %s queued  %s running  %s blocked  %s done  %s\n' \
          "$label" "$q" "$r" "$b" "$d" "$(_mqu_agent_status "$label")"
      done < <(_mqu_labels)
      ;;
    *) echo "usage: m-run [start|stop|n <N>|tick|log|status]" >&2; return 1 ;;
  esac
}

# --- the board ---------------------------------------------------------------
#
# Two levels in one panel: the worktrees, and one worktree's lane. The keys are
# the same language m-dev and m-teardown use. The lane has two modes on top of
# that, because an input and single-key commands cannot both own the keyboard:
# with the input always live, e types an e and q types a q.

_mq_size() {
  local size
  size="$(stty size 2>/dev/null)" || size=""
  _MQ_ROWS="${size%% *}" _MQ_COLS="${size##* }"
  [[ "$_MQ_ROWS" =~ ^[0-9]+$ ]] && [ "$_MQ_ROWS" -gt 0 ] || _MQ_ROWS=24
  [[ "$_MQ_COLS" =~ ^[0-9]+$ ]] && [ "$_MQ_COLS" -gt 0 ] || _MQ_COLS=80
}

_mq_mark() {
  case "$1" in
    running) printf '[>]' ;;
    done)    printf '[x]' ;;
    blocked) printf '[!]' ;;
    *)       printf '[ ]' ;;
  esac
}

# Wrap one item across as many lines as it needs, into _MQ_WRAPPED. The panel
# turns the terminal's own wrapping off, so a long title is cut short unless it
# is split here. <pre> is the first line's indent, <cont> the one every line
# after it gets, so a wrapped item still reads as one row.
_mq_wrap() {
  local pre="$1" cont="$2" rest="$3" width piece cut flat
  _MQ_WRAPPED=()
  while :; do
    width=$(( _MQ_COLS - ${#pre} ))
    if [ "$width" -lt 8 ]; then      # too narrow to wrap into, so cut it
      flat="$pre$rest"
      _MQ_WRAPPED+=("${flat:0:_MQ_COLS}")
      break
    fi
    if [ "${#rest}" -le "$width" ]; then
      _MQ_WRAPPED+=("$pre$rest")
      break
    fi
    piece="${rest:0:width+1}"
    cut="${piece% *}"                # back up to the last space in reach
    if [ "$cut" = "$piece" ] || [ -z "$cut" ]; then
      cut="${rest:0:width}"          # one long word: break it anywhere
      rest="${rest:width}"
    else
      rest="${rest:${#cut}}"
      rest="${rest# }"               # the space it broke on goes away
    fi
    _MQ_WRAPPED+=("$pre$cut")
    pre="$cont"
  done
}

# Hand the terminal to the editor and take it back after. Both the add and the
# edit key go through here, so the panel is put back the same way either way.
_mq_editor() {
  printf '\033[?7h\033[?25h\033[?1049l'
  # Unquoted on purpose: an EDITOR carrying arguments, such as "code -w", is a
  # command plus its flags and not one filename.
  # shellcheck disable=SC2086
  ${EDITOR:-vi} "$1"
  printf '\033[?1049h\033[?7l\033[H\033[2J'
}

# A scratch file for the editor to work on, named .md so the editor treats it
# as one.
_mq_scratch() { mktemp "${TMPDIR:-/tmp}/mq-XXXXXX.md"; }

# Every worktree shows, an empty lane included: that is where the next item goes.
_mq_load_worktrees() {
  local label q r b d id st
  _MQ_WL=() _MQ_WTEXT=()
  _mqu_agents_load fresh
  while read -r label; do
    [ -n "$label" ] || continue
    read -r q r b d < <(_mqu_counts "$label")
    id="$(_mqu_running_id "$label")"
    if [ -n "$id" ]; then
      st="$(_mqu_get "$id" title)"
    else
      id="$(_mqu_first_queued "$label")"
      [ -n "$id" ] && st="next: $(_mqu_get "$id" title)" || st=""
    fi
    _MQ_WL+=("$label")
    _MQ_WTEXT+=("$(printf '%-22s %2sq %2sr %2sb %2sd  %-8s %s' \
      "${label:0:22}" "$q" "$r" "$b" "$d" "$(_mqu_agent_status "$label")" "$st")")
  done < <(_mqu_labels)
}

_mq_load_lane() {
  local st id md ti
  _MQ_IDS=() _MQ_STS=() _MQ_MDS=() _MQ_TIS=()
  while IFS=$'\t' read -r st id md ti; do
    [ -n "$id" ] || continue
    # Done items are out of the way unless A asked for them.
    [ "$st" = done ] && [ "${_MQ_ALL:-0}" = 0 ] && continue
    _MQ_IDS+=("$id") _MQ_STS+=("$st") _MQ_MDS+=("$md") _MQ_TIS+=("$ti")
  done < <(_mqu_rows "$_MQ_LANE")
}

_mq_load() {
  if [ "$_MQ_VIEW" = lane ]; then _mq_load_lane; else _mq_load_worktrees; fi
}

# m-board - the panel. Opens on the worktrees, because picking one is what it is
# for; enter drills into its lane.
m-board() {
  local mode=list buf="" sel=1 top=1 note="" confirm="" caction="" key ch seq rc keys
  local traps line n i id avail dirty=1 last="" frame title ticks=0 used cont tmp
  local -a fl

  mkdir -p "$(_mqu_state)"
  # What a wrapped title lines up under: two spaces, the mark, the mode column.
  printf -v cont '%14s' ''
  traps="$(trap -p WINCH INT)"
  _MQ_RESIZED=0 _MQ_QUIT=0
  trap '_MQ_RESIZED=1' WINCH
  trap '_MQ_QUIT=1' INT
  _mq_size
  # The alternate screen, so the panel has the terminal to itself and quitting
  # hands the scrollback back untouched. Wrapping off, because a highlighted row
  # is padded to the full width.
  printf '\033[?1049h\033[?7l\033[H\033[2J'
  _MQ_VIEW=worktrees
  _mq_load

  while :; do
    if [ "$_MQ_RESIZED" = 1 ]; then _MQ_RESIZED=0; _mq_size; dirty=1; fi

    if [ "$_MQ_VIEW" = lane ]; then n=${#_MQ_IDS[@]}; else n=${#_MQ_WL[@]}; fi
    [ "$sel" -gt "$n" ] && sel="$n"
    [ "$sel" -lt 1 ] && sel=1

    if [ "$_MQ_VIEW" = lane ] && [ "$mode" = input ]; then
      avail=$(( _MQ_ROWS - 6 ))
    else
      avail=$(( _MQ_ROWS - 4 ))
    fi
    [ -n "$note$confirm" ] && avail=$(( avail - 1 ))
    [ "$avail" -lt 1 ] && avail=1
    [ "$sel" -lt "$top" ] && top="$sel"
    if [ "$_MQ_VIEW" = lane ]; then
      # An item can wrap onto several lines, so keeping the selection on screen
      # means measuring the window in lines rather than counting items.
      while [ "$top" -lt "$sel" ]; do
        used=0
        for (( i = top; i <= sel; i++ )); do
          _mq_wrap "$cont" "$cont" "${_MQ_TIS[$(( i - 1 ))]}"
          used=$(( used + ${#_MQ_WRAPPED[@]} ))
        done
        [ "$used" -le "$avail" ] && break
        top=$(( top + 1 ))
      done
    else
      [ "$sel" -ge $(( top + avail )) ] && top=$(( sel - avail + 1 ))
    fi
    [ "$top" -lt 1 ] && top=1

    if [ "$_MQ_VIEW" = lane ]; then
      title="$(printf '%-40s %s' "$_MQ_LANE" "runner: $(_mqu_runner_alive && echo on || echo off)   N=$(_mqu_n)")"
    else
      title="$(printf '%-40s %s' "worktrees" "runner: $(_mqu_runner_alive && echo on || echo off)   N=$(_mqu_n)")"
    fi
    fl=("$title" "")
    [ "$_MQ_VIEW" = lane ] && [ "$mode" = input ] && fl+=("  > $buf" "")

    if [ "$n" -eq 0 ]; then
      if [ "$_MQ_VIEW" = lane ]; then
        fl+=("  nothing queued here. press a and type an item")
      else
        fl+=("  no feature worktrees. m-work one first")
      fi
    elif [ "$_MQ_VIEW" = lane ]; then
      used=0
      for (( i = top; i <= n; i++ )); do
        # The mode is cut to its column width, so the title starts at the same
        # place the wrapped lines under it do.
        _mq_wrap "  $(_mq_mark "${_MQ_STS[$(( i - 1 ))]}") $(printf '%-7.7s' "${_MQ_MDS[$(( i - 1 ))]}") " \
          "$cont" "${_MQ_TIS[$(( i - 1 ))]}"
        for line in "${_MQ_WRAPPED[@]}"; do
          [ "$used" -ge "$avail" ] && break 2
          # The bar is the selection and the cursor is the mode, so the bar stays
          # on in both. Every line of the item carries it, padded to the width.
          [ "$i" = "$sel" ] &&
            printf -v line '\033[7m%-*s\033[27m' "$_MQ_COLS" "$line"
          fl+=("$line")
          used=$(( used + 1 ))
        done
      done
    else
      for (( i = top; i < top + avail && i <= n; i++ )); do
        line="  ${_MQ_WTEXT[$(( i - 1 ))]}"
        [ "${#line}" -gt "$_MQ_COLS" ] && line="${line:0:_MQ_COLS}"
        [ "$i" = "$sel" ] &&
          printf -v line '\033[7m%-*s\033[27m' "$_MQ_COLS" "$line"
        fl+=("$line")
      done
    fi

    if [ -n "$confirm" ]; then
      keys="  $confirm"
    elif [ "$_MQ_VIEW" != lane ]; then
      keys="  enter lane  s/S runner  +/- lanes  r reload  q close"
    elif [ "$mode" = input ]; then
      keys="  enter files it   esc the list   tab switch"
    else
      keys="  enter run  a add  e edit  m mode  x done  D delete  A all  q back"
    fi
    [ "${#keys}" -gt "$_MQ_COLS" ] && keys="${keys:0:_MQ_COLS}"
    fl+=("" "$keys")
    [ -n "$note" ] && fl+=("  ${note:0:$(( _MQ_COLS - 2 ))}")

    # Every line carries its own erase-to-end, so a shorter line leaves nothing
    # of the longer one it replaced, and the trailing erase clears below.
    frame=""
    for line in "${fl[@]}"; do frame+="$line"$'\033[K\n'; done

    if [ "$dirty" = 1 ] || [ "$frame" != "$last" ]; then
      printf '\033[H%s\033[J' "$frame"
      last="$frame" dirty=0
    fi
    if [ "$_MQ_VIEW" = lane ] && [ "$mode" = input ] && [ -z "$confirm" ]; then
      printf '\033[?25h\033[3;%dH' $(( 5 + ${#buf} ))
    else
      printf '\033[?25l'
    fi

    # A timed read, never a blocking one: bash runs a trap only once read
    # returns, so a blocking read swallows ctrl+c until the next keypress, and
    # there is a screen to hand back before this can return. The count is also
    # the refresh clock - a dispatched item changes state with nobody typing.
    while :; do
      IFS= read -rsn1 -t 0.25 key && break
      rc=$?
      [ "$_MQ_QUIT" = 1 ] && break 2
      [ "$rc" -le 128 ] && break 2                 # eof, not a timeout
      [ "$_MQ_RESIZED" = 1 ] && continue 2
      ticks=$(( ticks + 1 ))
      if [ "$ticks" -ge 12 ]; then ticks=0; _mq_load; continue 2; fi
    done
    [ "$_MQ_QUIT" = 1 ] && break
    note="" ticks=0

    # A confirmation takes the very next keypress and nothing else, and only y
    # answers it, so a stray keystroke can only ever call one off.
    if [ -n "$confirm" ]; then
      confirm="" dirty=1
      id="${_MQ_IDS[$(( sel - 1 ))]}"
      if [ "$key" = y ] || [ "$key" = Y ]; then
        case "$caction" in
          run)
            if _mqu_dispatch "$id" manual 2>"$(_mqu_state)/last-error"; then
              note="running $id. log: $(_mqu_item_log "$id")"
            else
              note="$(cat "$(_mqu_state)/last-error")"
            fi
            ;;
          delete)
            rm -f "$(_mqu_file "$id")"
            _mqu_git "delete $id"
            note="deleted $id"
            ;;
        esac
        _mq_load
      else
        note="cancelled"
      fi
      caction=""
      continue
    fi

    # An escape is either the key itself or the head of an arrow sequence. Read
    # the whole thing: what is left behind is read as a keystroke on the next
    # pass, and the tail of one of these spells q.
    if [ "$key" = $'\e' ]; then
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
        A) sel=$(( sel - 1 )) ;;
        B) sel=$(( sel + 1 )) ;;
        '')
          if [ "$_MQ_VIEW" = lane ] && [ "$mode" = input ]; then
            if [ -n "$buf" ]; then buf=""; else mode=list; fi
          fi
          ;;
      esac
      dirty=1
      continue
    fi

    if [ "$_MQ_VIEW" = lane ] && [ "$mode" = input ]; then
      case "$key" in
        '')
          if [ -n "$buf" ]; then
            if _mqu_add "$_MQ_LANE" "$buf" >/dev/null; then note="filed"; else note="could not write the item"; fi
            buf=""
            _mq_load
            sel=${#_MQ_IDS[@]}
          else
            mode=list
          fi
          ;;
        $'\t') mode=list ;;
        $'\177' | $'\b') buf="${buf%?}" ;;
        $'\025') buf="" ;;
        $'\027')
          while [ -n "$buf" ] && [ "${buf: -1}" = " " ]; do buf="${buf%?}"; done
          while [ -n "$buf" ] && [ "${buf: -1}" != " " ]; do buf="${buf%?}"; done
          ;;
        [[:print:]]) buf+="$key" ;;
      esac
      dirty=1
      continue
    fi

    case "$key" in
      k) sel=$(( sel - 1 )) ;;
      j) sel=$(( sel + 1 )) ;;
      r) _mq_load; note="reloaded" ;;
      q | Q)
        if [ "$_MQ_VIEW" = lane ]; then
          _MQ_VIEW=worktrees sel=1 top=1
          _mq_load
        else
          break
        fi
        ;;
    esac

    if [ "$_MQ_VIEW" != lane ]; then
      case "$key" in
        '')
          if [ "$n" -gt 0 ]; then
            _MQ_LANE="${_MQ_WL[$(( sel - 1 ))]}"
            _MQ_VIEW=lane mode=list sel=1 top=1
            _mq_load
          fi
          ;;
        s) m-run start >/dev/null 2>&1; note="runner on, N=$(_mqu_n)" ;;
        S) m-run stop  >/dev/null 2>&1; note="runner off. items already dispatched keep running" ;;
        '+'|'=') _mqu_set_n $(( $(_mqu_n) + 1 )); note="N=$(_mqu_n)" ;;
        '-'|'_') [ "$(_mqu_n)" -gt 1 ] && _mqu_set_n $(( $(_mqu_n) - 1 )); note="N=$(_mqu_n)" ;;
      esac
      dirty=1
      continue
    fi

    case "$key" in
      a)
        # A new item is written in the editor, body first: the first line names
        # it, so there is no title to type separately and no frontmatter to see.
        if ! tmp="$(_mq_scratch)"; then
          note="could not make a scratch file"
        else
          _mq_editor "$tmp"
          if [ -n "$(_mqu_first_line "$tmp")" ]; then
            id="$(_mqu_add "$_MQ_LANE" "$(_mqu_first_line "$tmp")")" &&
              _mqu_set_body "$id" "$tmp"
            _mqu_git "add $id"
            note="filed $id"
            _mq_load
            sel=${#_MQ_IDS[@]}
          else
            note="nothing filed"
          fi
          rm -f "$tmp"
        fi
        ;;
      i | $'\t') mode=input ;;
      A)
        _MQ_ALL=$(( 1 - ${_MQ_ALL:-0} ))
        [ "$_MQ_ALL" = 1 ] && note="showing everything" || note="showing open items"
        _mq_load
        ;;
      e)
        if [ "$n" -gt 0 ]; then
          id="${_MQ_IDS[$(( sel - 1 ))]}"
          # The body alone goes to the editor, so the frontmatter this file
          # owns is never in the buffer to be broken by hand.
          if ! tmp="$(_mq_scratch)"; then
            note="could not make a scratch file"
          else
            _mqu_body "$id" >"$tmp"
            _mq_editor "$tmp"
            if _mqu_set_body "$id" "$tmp"; then
              _mqu_git "edit $id"
            else
              note="$id left alone: the body came back empty"
            fi
            rm -f "$tmp"
            _mq_load
          fi
        fi
        ;;
      m)
        if [ "$n" -gt 0 ]; then
          id="${_MQ_IDS[$(( sel - 1 ))]}"
          case "$(_mqu_get "$id" mode)" in
            loom)   _mqu_set "$id" mode finish ;;
            finish) _mqu_set "$id" mode free ;;
            *)      _mqu_set "$id" mode loom ;;
          esac
          _mqu_git "mode $id"
          _mq_load
          note="mode $(_mqu_get "$id" mode)"
        fi
        ;;
      x)
        if [ "$n" -gt 0 ]; then
          id="${_MQ_IDS[$(( sel - 1 ))]}"
          if [ "${_MQ_STS[$(( sel - 1 ))]}" = done ]; then
            _mqu_set "$id" status queued
          else
            _mqu_set "$id" status done
          fi
          _mqu_git "status $id"
          _mq_load
        fi
        ;;
      D)
        [ "$n" -gt 0 ] && {
          confirm="delete \"${_MQ_TIS[$(( sel - 1 ))]}\"? y to confirm"
          caction=delete
        }
        ;;
      '')
        [ "$n" -gt 0 ] && {
          confirm="run \"${_MQ_TIS[$(( sel - 1 ))]}\" in $_MQ_LANE now, attended? y to confirm"
          caction=run
        }
        ;;
    esac
    dirty=1
  done

  # One way out, so the terminal is always handed back the way it was found.
  printf '\033[?7h\033[?25h\033[?1049l'
  trap - WINCH INT
  [ -n "$traps" ] && eval "$traps"
  return 0
}

# mq [text] - file an item against the worktree this shell is standing in, for
# when a pane is free and the panel is a detour. No argument opens the board.
mq() {
  local label
  if [ "$#" -eq 0 ]; then m-board; return $?; fi
  label="$(_m_dev_label "$(git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")")"
  if [ -z "$(_mqu_dir_of "$label")" ]; then
    echo "mq: $PWD is not a momentum feature worktree" >&2
    return 1
  fi
  _mqu_add "$label" "$*" >/dev/null || { echo "mq: nothing to file" >&2; return 1; }
}
