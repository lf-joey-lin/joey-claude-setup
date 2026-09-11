# momentum workspace shortcuts: m-newwork, m-teardown, m-purge, m-dev, m-cd, m-doctor.
#
# m-newwork sets up the branch and worktree, then leaves the shell somewhere
# useful. m-teardown, m-purge, m-dev, m-cd and m-doctor are plain git/process
# wrappers. No Claude in any of them.
#
# Source from ~/.bashrc. Bash only; the Windows side has no equivalent yet.

_m_root() { printf '%s\n' "${MOMENTUM_ROOT:-$HOME/m-code}"; }

# "fix form submit null check" -> fixFormSubmitNullCheck. An argument that is
# already one camelCase word comes back unchanged.
_m_camel() {
  printf '%s' "$*" | tr -c 'A-Za-z0-9' ' ' | awk '{
    out = ""
    for (i = 1; i <= NF; i++) {
      w = $i
      if (w ~ /^[A-Z0-9]+$/) w = tolower(w)
      if (out == "") out = tolower(substr(w, 1, 1)) substr(w, 2)
      else out = out toupper(substr(w, 1, 1)) substr(w, 2)
    }
    print out
  }'
}

# _m_pick <rows> <want> - the whole rows whose first or second field matches a
# name, one per line. Case and dashes are ignored: a worktree directory is
# kebab-case (better-mobile-header) while the branch it holds is camelCase
# (betterMobileHeader), and either is a reasonable thing to type. Exact beats a
# prefix and a prefix beats a substring, and the first of those three that
# matches anything is the answer, so a name that fully matches one row is never
# ambiguous with a longer one that merely contains it.
_m_pick() {
  local want hit test
  want="$(tr '[:upper:]' '[:lower:]' <<<"${2//-/}")"
  for test in 'k == w' 'index(k, w) == 1 || index(b, w) == 1' 'index(k, w) || index(b, w)'; do
    hit="$(awk -v w="$want" \
      '{ k = tolower($1); gsub(/-/, "", k)
         b = tolower($2); gsub(/-/, "", b)
         if ('"$test"') print }' <<<"$1")"
    [ -n "$hit" ] && { printf '%s\n' "$hit"; return 0; }
  done
  return 1
}

# _m_newworktree <short description>
#
# Branch off a freshly fetched origin/main into its own worktree next to the
# reference checkout, and publish it. The default worktree stays on main and is
# only fetched. Prints the new worktree path on stdout; everything else is
# stderr, so callers can capture the path.
_m_newworktree() {
  local root main branch dir
  root="$(_m_root)"
  main="$root/momentum"

  if [ ! -e "$main/.git" ]; then
    echo "no momentum checkout at $main" >&2
    return 1
  fi

  branch="$(_m_camel "$@")"
  if [ -z "$branch" ]; then
    echo "cannot derive a branch name from: $*" >&2
    return 1
  fi
  dir="$root/momentum-$branch"

  if git -C "$main" show-ref --verify --quiet "refs/heads/$branch"; then
    echo "branch $branch already exists; pick another description" >&2
    return 1
  fi
  if [ -e "$dir" ]; then
    echo "$dir already exists; pick another description" >&2
    return 1
  fi

  git -C "$main" fetch origin >&2 || return 1

  # --no-track matters: inheriting origin/main as upstream makes a bare push
  # fail under push.default=simple on the branch name mismatch.
  git -C "$main" worktree add --no-track -b "$branch" "$dir" origin/main >&2 || return 1

  # Sets origin/<branch> and the upstream, so commits show as outgoing in the
  # editor from here on. A failed push leaves a perfectly usable worktree.
  git -C "$dir" push -u origin HEAD >&2 ||
    echo "push failed; the worktree is fine, publish the branch by hand" >&2

  printf '%s\n' "$dir"
}

# m-newwork <short description>
#
# Sets up the branch/worktree, then drops you into it with Claude running.
m-newwork() {
  if [ "$#" -eq 0 ]; then
    echo "usage: m-newwork <short description of the work>" >&2
    return 1
  fi

  local dir
  dir="$(_m_newworktree "$@")" || return 1

  cd "$dir" || return 1
  claude -n "$*"
}

# --- m-teardown: the worktree and branch sweep, as a table --------------------
#
# Plain shell, no Claude in it. The table lists every momentum worktree and every
# local branch, split into what holds work main does not have and what is spent.
# d removes the selected one after a y, X removes every spent one at once.
#
#   m-teardown           the table: up/down select, d tear down, D force,
#                        X purge spent, r rescan, p land main, q quit
#   m-teardown <name>    gate that one worktree or branch, remove it after a y/n
#   m-teardown this      the worktree the shell is standing in
#   m-teardown --purge   every spent one, listed, then removed after a y/n
#                        (--yes skips the question; m-purge is the short name)
#   m-teardown --pull    land momentum on a fresh main and pull manta
#
# The question each row answers is whether it holds work main does not already
# have. Four verdicts:
#
#   BASE   the default worktree. Nothing removes it; p lands it on main.
#   HOLD   it holds work, and this is the only copy - or gh could not say, which
#          is not the same as an answer. d refuses; only D forces.
#   KEEP   it holds work, and origin has it too. d removes it, purge never does.
#   SPENT  nothing here that main lacks. d and X both take it.
#
# Working a verdict out costs a `gh pr list`, so a scan runs behind the table and
# writes its answers to a cache the redraw reads back - the same split m-dev uses
# to keep slow work off the frame.

_m_td_state() { printf '%s\n' "${XDG_CACHE_HOME:-$HOME/.cache}/m-teardown"; }
_m_td_status_file() { printf '%s\n' "$(_m_td_state)/status"; }
_m_td_action_log() { printf '%s\n' "$(_m_td_state)/action.log"; }
_m_td_action_pid() { printf '%s\n' "$(_m_td_state)/action.pid"; }
_m_td_fate_file() { printf '%s\n' "$(_m_td_state)/commit-fate"; }

# One remembered answer per commit, in a file rather than a variable. Every caller
# of the lookup below runs inside a command substitution, so a shell variable
# written in one is thrown away with the subshell - a file is also what lets the
# scan and a later purge share the work. The key is a SHA, so an answer cannot go
# stale in a way that matters; OPEN and down are the two that can still change and
# are the two never written.
_m_td_fate_get() {
  local line f
  f="$(_m_td_fate_file)"
  [ -f "$f" ] || return 1
  while IFS= read -r line; do
    case "$line" in "$1 "*) printf '%s\n' "${line#* }"; return 0 ;; esac
  done <"$f"
  return 1
}
_m_td_fate_put() {
  case "$2" in OPEN*|down) return 0 ;; esac
  mkdir -p "$(_m_td_state)" 2>/dev/null
  printf '%s %s\n' "$1" "$2" >>"$(_m_td_fate_file)" 2>/dev/null
  return 0
}

# What names a row in the status cache. A worktree is its directory; a branch
# with no worktree has no directory to be named by, and every one of them carries
# the same "-" placeholder, so they need a key of their own or they all collide.
_m_td_key() {
  case "$2" in
    -) printf 'branch:%s\n' "$1" ;;
    *) printf '%s\n' "$2" ;;
  esac
}

# The worktrees this may act on: the default one, which is only ever landed on
# main, and its direct momentum-<desc> siblings. Another tool may keep real momentum
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

# Local branches no worktree is holding - what GitHub's merge leaves behind, and
# what a worktree removed by hand leaves behind. Their rows carry "-" where a
# worktree directory would be. main is skipped: it is the thing every other
# verdict is measured against.
_m_td_bare_branches() {
  local main held b
  main="$(_m_root)/momentum"
  held="$(git -C "$main" worktree list --porcelain 2>/dev/null |
            awk '/^branch refs\/heads\//{sub(/^branch refs\/heads\//, ""); print}')"
  git -C "$main" for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null |
    while read -r b; do
      [ -n "$b" ] && [ "$b" != main ] || continue
      grep -qxF "$b" <<<"$held" && continue
      printf '%s %s -\n' "$b" "$b"
    done
}

_M_TD_WT_CACHE=""
_m_td_rows() {
  local -n out="$1"
  local line
  if [ -z "$_M_TD_WT_CACHE" ] || [ "${2:-}" = fresh ]; then
    _M_TD_WT_CACHE="$(_m_td_targets; _m_td_bare_branches)"
  fi
  out=()
  while IFS= read -r line; do
    [ -n "$line" ] && out+=("$line")
  done <<<"$_M_TD_WT_CACHE"
  [ "${#out[@]}" -gt 0 ]
}

# How many pull requests one read asks for. gh pages at 100 a request, so the
# whole history costs about four seconds, while every branch the page does not
# reach costs a lookup of its own at 0.8s each - measured 2026-09-11: a 200 page
# left 25 branches to look up one at a time and turned a 9s scan into 29s.
_M_TD_PR_LIMIT=1000

# Every branch that has a pull request, as "<branch><tab><number> <state> <head-sha>",
# newest first. It fails rather than printing nothing when gh cannot answer: no PR
# is a normal end state for an abandoned branch, while a gh that cannot answer
# proves nothing and must not read as one.
_m_td_pr_map() {
  ( cd "$(_m_root)/momentum" &&
      gh pr list --state all --limit "$_M_TD_PR_LIMIT" \
        --json number,state,headRefName,headRefOid \
        --jq '.[] | [.headRefName, "\(.number) \(.state) \(.headRefOid)"] | @tsv' )
}

# _m_td_pr_load <map-name> <error-var-name> <mode-var-name> - fill the map from
# one gh call. Everything is set by nameref rather than printed, because a caller
# capturing the output would run this in a subshell and lose the map it built.
#
# The mode is what a branch missing from the map means:
#
#   full  the page reached the end of the history, so missing means no PR
#   page  the page filled up, so missing may just be an older PR - look it up
#   down  gh never answered, so nothing can be concluded from the map at all
_m_td_pr_load() {
  local -n map="$1"
  local -n errout="$2"
  local -n modeout="$3"
  local out b rest n=0
  map=() errout="" modeout=down
  out="$(_m_td_pr_map 2>&1)" || { errout="$out"; return 1; }
  while IFS=$'\t' read -r b rest; do
    [ -n "$b" ] || continue
    n=$((n + 1))
    [ -n "${map[$b]}" ] && continue          # the list is newest first
    map["$b"]="$rest"
  done <<<"$out"
  [ "$n" -lt "$_M_TD_PR_LIMIT" ] && modeout=full || modeout=page
  return 0
}

# The pull request for one branch, as "<number> <state> <head-sha>", or the word
# `none` when it has none and `down` when gh could not answer.
_m_td_pr_of() {
  local out
  out="$( cd "$(_m_root)/momentum" && gh pr list --head "$1" --state all --limit 1 \
            --json number,state,headRefOid \
            --jq '.[] | "\(.number) \(.state) \(.headRefOid)"' 2>/dev/null )" \
    || { printf 'down\n'; return 0; }
  [ -n "$out" ] && printf '%s\n' "$out" || printf 'none\n'
}

# _m_td_pr_for <map-name> <mode> <branch> - the PR line for one branch, from the
# bulk map when it is in there and from the mode when it is not.
_m_td_pr_for() {
  local -n m="$1"
  if [ -n "${m[$3]}" ]; then
    printf '%s\n' "${m[$3]}"
  else
    case "$2" in
      full) printf 'none\n' ;;
      page) _m_td_pr_of "$3" ;;
      *)    printf 'down\n' ;;
    esac
  fi
}

# How many commits exist only in this clone: on this branch and on no remote ref
# at all. Merges are left out, because a merge of main into a branch carries no
# work of its own and redoing it costs nothing.
#
# This replaces counting against the branch's own upstream, which counted main's
# commits too once you had merged main in - tableGrouping read as "66 unpushed"
# when 65 of them were main's and the 66th was the merge.
_m_td_local_only() {
  git -C "$(_m_root)/momentum" rev-list --count --no-merges "$1" --not --remotes 2>/dev/null || printf '0\n'
}

# The newest commit that exists only in this clone, or nothing.
_m_td_local_tip() {
  git -C "$(_m_root)/momentum" rev-list --no-merges -1 "$1" --not --remotes 2>/dev/null
}

# What GitHub knows about one commit. Four answers, and the difference between the
# last two is the whole point:
#
#   <MERGED|OPEN|CLOSED> <n>  a pull request carries it
#   nopr                      GitHub has the commit, but no pull request carries it
#   local                     GitHub has never seen it - this clone is the only copy
#   down                      the lookup itself failed
#
# This is what separates your own unpushed work from a worktree you made to review
# somebody else's pull request. To git the two are identical: commits no remote ref
# contains, on a branch with no upstream. GitHub can tell them apart, because a
# review checkout's commits were pushed once while yours never left this machine.
#
# `nopr` is not a risk and must not read as one. It is what a rebased or
# force-pushed PR branch leaves behind: the commits are still on GitHub, just no
# longer attached to the PR. The caller lets these fall through to the ordinary
# rules instead of holding the branch - inbox/697808-taskinfo answers this way for
# four commits of someone else's, and its PR merged.
_m_td_commit_pr() {
  local out rc res
  res="$(_m_td_fate_get "$1")" && { printf '%s\n' "$res"; return 0; }
  out="$( cd "$(_m_root)/momentum" && gh api "repos/{owner}/{repo}/commits/$1/pulls" \
            --jq '.[0] | if . == null then "" else "\(if .merged_at then "MERGED" else (.state | ascii_upcase) end) \(.number)" end' 2>&1 )"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    case "$out" in
      *"No commit found for SHA"*) res=local ;;
      *)                           printf 'down\n'; return 0 ;;   # never cached, it may pass
    esac
  elif [ -n "$out" ]; then
    res="$out"
  else
    res=nopr
  fi
  _m_td_fate_put "$1" "$res"
  printf '%s\n' "$res"
}

# How many of this branch's commits main does not already have, compared by
# patch-id rather than by SHA so a rebase or a cherry-pick does not read as new
# work. -1 means there is no origin/main to compare against, which the caller
# must treat as an unknown rather than as a zero.
#
# A squash merge defeats this - it puts one commit on main whose patch matches
# none of the branch's - which is why a merged PR is settled by its own head SHA
# in the check below and never reaches here.
_m_td_novel_count() {
  local main
  main="$(_m_root)/momentum"
  git -C "$main" rev-parse --verify --quiet origin/main >/dev/null 2>&1 || { printf '%s\n' -1; return 0; }
  git -C "$main" cherry origin/main "$1" 2>/dev/null | grep -c '^+'
  return 0                           # grep calls a count of zero a failure; here it is an answer
}

# _m_td_branch_check <branch> <pr> -> "<HOLD|KEEP|SPENT><tab><reason>".
#
# Does this branch hold work main does not have, and if it does, is this the only
# copy? The refs live in the default worktree, so this holds even for a branch
# whose worktree directory has already gone.
_m_td_branch_check() {
  local branch="$1" pr="$2" main n num state oid novel only tip fate upstream_gone=""
  main="$(_m_root)/momentum"

  # Anything no remote has is the first question, because it is the only case
  # where removing the branch destroys something. Ask GitHub about the newest such
  # commit rather than trusting git alone: a worktree opened to review someone
  # else's PR looks exactly like unpushed work of your own, and this is what tells
  # them apart.
  only="$(_m_td_local_only "$branch")"
  if [ "${only:-0}" -gt 0 ]; then
    tip="$(_m_td_local_tip "$branch")"
    fate="$(_m_td_commit_pr "$tip")"
    read -r state num <<<"$fate"
    case "$state" in
      MERGED) printf 'SPENT\t%s commit(s) only here, newest merged in PR #%s\n' "$only" "$num"; return 0 ;;
      OPEN)   printf 'KEEP\t%s commit(s) only here, newest in open PR #%s\n' "$only" "$num"; return 0 ;;
      CLOSED) printf 'SPENT\t%s commit(s) only here, newest in closed PR #%s\n' "$only" "$num"; return 0 ;;
      down)   printf 'HOLD\t%s commit(s) on no remote, and gh could not say more\n' "$only"; return 0 ;;
      local)  printf 'HOLD\t%s commit(s) exist only here\n' "$only"; return 0 ;;
    esac
    # nopr: GitHub still holds them, so nothing is at risk and the ordinary rules
    # below decide the branch.
  fi

  # Everything on the branch is on a remote somewhere. What is left is whether it
  # reached main.
  if ! git -C "$main" rev-parse --verify --quiet "$branch@{upstream}" >/dev/null 2>&1 \
     && [ -n "$(git -C "$main" config --get "branch.$branch.merge" 2>/dev/null)" ]; then
    # Pushed once, and origin/<branch> has since gone. That is what GitHub does
    # to a head branch on merge, so with a merged PR below it is ordinary. With
    # no PR to confirm it, the patch-id count is the only evidence either way.
    upstream_gone=1
  fi

  case "$pr" in
    down) printf 'HOLD\tgh could not say whether a PR exists\n'; return 0 ;;
  esac

  read -r num state oid <<<"$pr"
  case "$state" in
    MERGED)
      # Commits pushed after the merge are work of their own, and the branch is
      # not spent until they land too.
      #
      # The cat-file is the point of this arm. GitHub deletes the head branch on
      # merge and the fetch above prunes the ref, so the merged head is usually
      # not in this clone at all (8 of 9 merged branches here, measured
      # 2026-09-11). rev-list on a commit it does not have fails and prints
      # nothing, which reads exactly like "nothing pushed since" - so ask whether
      # the commit is there before believing the count.
      #
      # With it missing, the PR is the whole answer and the branch is spent. Not
      # ideal, but there is nothing better: this repo squash-merges, which puts
      # one commit on main whose patch matches none of the branch's, so comparing
      # the branch against main by patch-id calls every merged branch novel (42
      # commits for bplisting2, whose PR merged). The one case where work really
      # does exist only here - commits never pushed - is caught above, while
      # origin still has the branch to be ahead of.
      if [ -n "$oid" ] && git -C "$main" cat-file -e "$oid^{commit}" 2>/dev/null; then
        n="$(git -C "$main" rev-list --count "$oid..$branch" 2>/dev/null)"
        [ "${n:-0}" -gt 0 ] && { printf 'KEEP\tPR #%s merged, %s commit(s) pushed since\n' "$num" "$n"; return 0; }
      fi
      printf 'SPENT\tPR #%s merged\n' "$num"
      return 0 ;;
    OPEN)   printf 'KEEP\tPR #%s open\n' "$num"; return 0 ;;
    CLOSED) printf 'SPENT\tPR #%s closed unmerged\n' "$num"; return 0 ;;
  esac

  novel="$(_m_td_novel_count "$branch")"
  if [ "${novel:-0}" -lt 0 ]; then
    printf 'HOLD\tno origin/main here to compare against\n'
  elif [ "$novel" -eq 0 ]; then
    printf 'SPENT\tno PR, nothing main lacks\n'
  elif [ -n "$upstream_gone" ]; then
    printf 'KEEP\tno PR, origin/%s gone, %s commit(s) main lacks\n' "$branch" "$novel"
  else
    printf 'KEEP\tno PR, %s commit(s) main lacks\n' "$novel"
  fi
}

# _m_td_check <dir> <branch> <pr> -> "<VERDICT><tab><detail>". A dir of "-" is a
# branch with no worktree: nothing to be dirty, nothing to prune, so the branch
# check is the whole answer. Nothing here writes.
_m_td_check() {
  local dir="$1" branch="$2" pr="$3" main n verdict reason
  main="$(_m_root)/momentum"

  [ "$dir" = "$main" ] && { printf 'BASE\tdefault worktree, never removed\n'; return 0; }
  [ "$branch" = detached ] && { printf 'HOLD\tdetached head, no branch to check\n'; return 0; }

  IFS=$'\t' read -r verdict reason < <(_m_td_branch_check "$branch" "$pr")

  # Uncommitted work only exists in a directory that is still there, and the
  # WORKTREE column already says which rows are not.
  if [ "$dir" != "-" ] && [ -d "$dir" ]; then
    n="$(git -C "$dir" status --porcelain 2>/dev/null | wc -l)"
    [ "${n:-0}" -gt 0 ] && { printf 'HOLD\tdirty, %s uncommitted file(s)\n' "$n"; return 0; }
  fi

  printf '%s\t%s\n' "$verdict" "$reason"
}

# Every verdict, written a line at a time so the table fills in as it goes. The
# fetch first is what makes the patch-id comparison mean anything: without it a
# branch merged five minutes ago is measured against a stale origin/main and
# still reads as novel.
_m_td_scan() {
  local main label branch dir pr err="" mode=down
  local -A prs=()
  main="$(_m_root)/momentum"
  mkdir -p "$(_m_td_state)"
  : >"$(_m_td_status_file)"

  echo "fetching origin ..."
  git -C "$main" fetch --prune --quiet origin || echo "fetch failed; deciding on the refs already here"

  echo "reading pull requests ..."
  if _m_td_pr_load prs err mode; then
    echo "${#prs[@]} branches have a pull request"
  else
    echo "gh pr list failed, so no verdict can rest on a PR:"
    echo "$err"
  fi

  while read -r label branch dir; do
    echo "checking $label ..."
    pr="$(_m_td_pr_for prs "$mode" "$branch")"
    printf '%s\t%s\n' "$(_m_td_key "$branch" "$dir")" "$(_m_td_check "$dir" "$branch" "$pr")" \
      >>"$(_m_td_status_file)"
  done < <(_m_td_targets; _m_td_bare_branches)
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
        printf '%-5s %s' "${rest%%$'\t'*}" "${rest#*$'\t'}"
        return 0 ;;
    esac
  done <<<"$_M_TD_ST_CACHE"
  printf '%-5s %s' '?' 'checking ...'
}

_m_td_verdict() {
  local st
  st="$(_m_td_status "$1")"
  printf '%s\n' "${st%% *}"
}

# _m_td_group <dir> <verdict> - which half of the table a row belongs in. A row
# still being checked sits with the novel ones, so nothing is ever offered to a
# purge before its verdict is in. The default worktree is recognised by its path
# rather than by its verdict, or it spends the first seconds of a scan sitting
# under the novel heading.
_m_td_group() {
  [ "$1" = "$(_m_root)/momentum" ] && { printf 'base\n'; return 0; }
  case "$2" in
    BASE)  printf 'base\n' ;;
    SPENT) printf 'spent\n' ;;
    *)     printf 'novel\n' ;;
  esac
}

# What the WORKTREE column says: the short name while the directory is there,
# `gone` for a record git can prune, `-` for a branch that never had one.
_m_td_wtcell() {
  case "$2" in
    -) printf '%s\n' '-' ;;
    *) [ -d "$2" ] && printf '%s\n' "$1" || printf '%s\n' 'gone' ;;
  esac
}

# _m_td_order <rows-name> <out-name> - display order: the default worktree, then
# everything holding work main does not have, then everything spent. Inside a
# group the order git gave them is kept, so the list only moves when a verdict
# really changes.
_m_td_order() {
  local -n src="$1"
  local -n dst="$2"
  local row label branch dir
  local -a b=() n=() s=()
  for row in "${src[@]}"; do
    read -r label branch dir <<<"$row"
    case "$(_m_td_group "$dir" "$(_m_td_verdict "$(_m_td_key "$branch" "$dir")")")" in
      base)  b+=("$row") ;;
      spent) s+=("$row") ;;
      *)     n+=("$row") ;;
    esac
  done
  dst=("${b[@]}" "${n[@]}" "${s[@]}")
}

# Remove one worktree and its branch. Runs behind the table, so everything it
# has to say goes to stdout and ends up in the pane. A dir of "-" is a branch
# with no worktree, and only the branch half runs.
#
# It re-decides the branch for itself rather than trusting the verdict on screen:
# the removal is the destructive half, and by the time it runs the scan behind
# that verdict may be minutes old.
_m_td_remove() {
  local label="$1" dir="$2" branch="$3" force="${4:-}" nofetch="${5:-}" main out verdict="" reason=""
  main="$(_m_root)/momentum"

  case "$branch" in
    ''|detached|main) branch="" ;;
    *) IFS=$'\t' read -r verdict reason < <(_m_td_branch_check "$branch" "$(_m_td_pr_of "$branch")")
       echo "branch $branch: $verdict  $reason" ;;
  esac

  if [ "$dir" = "-" ]; then
    :
  elif [ ! -d "$dir" ]; then
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
  elif [ "$verdict" = HOLD ] && [ -z "$force" ]; then
    echo "keeping branch $branch: $reason"
  else
    if out="$(git -C "$main" branch -d "$branch" 2>&1)"; then
      echo "$out"
    else
      # -d only sees a merge when the SHAs match, which a squash or a rebase
      # merge never does. The check above already proved origin holds the work,
      # or a force said to go anyway.
      if [ -n "$force" ]; then
        echo "branch -d refused, deleting with -D (forced)"
      else
        echo "branch -d refused, deleting with -D (squash or rebase merge)"
      fi
      git -C "$main" branch -D "$branch"
    fi
  fi

  [ -n "$nofetch" ] || { git -C "$main" fetch --prune --quiet origin && echo "pruned stale remote refs"; }
  echo "done: $label"
}

# _m_td_purge [dry] - every spent worktree and branch in one pass, or in dry mode
# just the verdicts. Runs behind the table like a single removal.
#
# It re-checks each row from scratch rather than trusting the verdicts on screen,
# and skips anything that is no longer spent by the time its turn comes. One
# fetch and one `gh pr list` cover the whole pass.
_m_td_purge() {
  local dry="${1:-}" main label branch dir pr verdict reason err="" mode=down gone=0 left=0
  local -A prs=()
  main="$(_m_root)/momentum"

  echo "fetching origin ..."
  git -C "$main" fetch --prune --quiet origin || echo "fetch failed; deciding on the refs already here"

  if _m_td_pr_load prs err mode; then
    echo "${#prs[@]} branches have a pull request"
  else
    echo "gh pr list failed, so nothing can be called spent:"
    echo "$err"
    return 1
  fi

  while read -r label branch dir; do
    [ "$dir" = "$main" ] && continue
    pr="$(_m_td_pr_for prs "$mode" "$branch")"
    IFS=$'\t' read -r verdict reason < <(_m_td_check "$dir" "$branch" "$pr")
    if [ "$verdict" != SPENT ]; then
      echo "keeping $label: $verdict  $reason"
      left=$((left + 1))
      continue
    fi
    gone=$((gone + 1))
    if [ -n "$dry" ]; then
      echo "would remove $label: $reason"
      continue
    fi
    echo
    echo "== $label: $reason"
    _m_td_remove "$label" "$dir" "$branch" "" nofetch
  done < <(_m_td_targets; _m_td_bare_branches)

  echo
  if [ -n "$dry" ]; then
    echo "$gone spent, $left left alone"
  else
    git -C "$main" fetch --prune --quiet origin && echo "pruned stale remote refs"
    echo "purge finished: $gone removed, $left left alone"
  fi
  [ "$gone" -gt 0 ]
}

# The purge from the command line: list it, then ask, then do it. The list costs
# a second pass over gh, which is the price of answering the y with the real list
# in front of you rather than a count.
_m_td_purge_cmd() {
  local yes="$1" root main ans
  root="$(_m_root)"
  main="$root/momentum"

  # Standing in something about to go would break every command after it.
  case "$PWD/" in
    "$main"/*) ;;
    "$root"/momentum-*) cd "$main" && echo "stepped out of the worktree into $main" ;;
  esac

  if [ -z "$yes" ]; then
    _m_td_purge dry || { echo "nothing to purge"; return 0; }
    read -r -p "remove all of these? [y/N] " ans </dev/tty || return 1
    case "$ans" in y|Y) ;; *) echo "nothing removed"; return 1 ;; esac
    echo
  fi
  _m_td_purge
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

# _m_td_table <ordered-name> <sel> <busy-key> <busy-text> <cols>. The busy row is
# the one an action is working on, and says so rather than showing a verdict the
# action is in the middle of invalidating.
_m_td_table() {
  local -n ord="$1"
  local sel="$2" busy="$3" busytext="$4" cols="${5:-80}"
  local i=0 row label branch dir bw=6 ww=8 st key grp last="" mark

  [ "${#ord[@]}" -gt 0 ] || { echo "  nothing to tear down"; return 1; }

  for row in "${ord[@]}"; do
    read -r label branch dir <<<"$row"
    [ "${#branch}" -gt "$bw" ] && bw="${#branch}"
    label="$(_m_td_wtcell "$label" "$dir")"
    [ "${#label}" -gt "$ww" ] && ww="${#label}"
  done

  printf '  %-*s %-*s %s\n' "$bw" BRANCH "$ww" WORKTREE VERDICT
  for row in "${ord[@]}"; do
    i=$((i + 1))
    read -r label branch dir <<<"$row"
    key="$(_m_td_key "$branch" "$dir")"
    if [ -n "$busy" ] && [ "$key" = "$busy" ]; then
      st="$busytext"
    else
      st="$(_m_td_status "$key")"
    fi
    grp="$(_m_td_group "$dir" "${st%% *}")"
    if [ "$grp" != "$last" ] && [ "$grp" != base ]; then
      echo
      case "$grp" in
        novel) _m_dev_rule 'novel - work main does not have' "$cols"; echo ;;
        spent) _m_dev_rule 'spent - nothing here that main lacks' "$cols"; echo ;;
      esac
    fi
    last="$grp"
    [ "$i" = "$sel" ] && mark='>' || mark=' '
    printf '%s %-*s %-*s %s\n' "$mark" "$bw" "$branch" "$ww" "$(_m_td_wtcell "$label" "$dir")" "$st"
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

# A name -> the "<label> <branch> <dir>" row it means. Row numbers are not
# accepted: the table regroups itself as verdicts land, so a number is only true
# until the next redraw.
_m_td_resolve() {
  local all hit
  local -a rows
  _m_td_rows rows fresh || { echo "m-teardown: nothing to tear down" >&2; return 1; }
  all="$(printf '%s\n' "${rows[@]}")"

  if [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "m-teardown: name the worktree or branch; the table reorders as it scans, so a row number means nothing" >&2
    return 1
  fi
  if ! hit="$(_m_pick "$all" "$1")"; then
    echo "m-teardown: nothing matching '$1'. Known: $(awk '{printf "%s ", $2}' <<<"$all")" >&2
    return 1
  fi
  if [ "$(wc -l <<<"$hit")" -gt 1 ]; then
    echo "m-teardown: '$1' matches more than one:" >&2
    awk '{print "  " $2}' <<<"$hit" >&2
    return 1
  fi
  printf '%s\n' "$hit"
}

# One worktree or branch, gated and removed in the foreground. The path a name on
# the command line takes; the table uses the same two functions behind an action.
_m_td_one() {
  local name="$1" force="$2" root main label dir branch pr verdict detail ans
  root="$(_m_root)"
  main="$root/momentum"

  read -r label branch dir < <(_m_td_resolve "$name") || return 1
  case "$dir" in
    -) ;;
    "$root"/momentum-*/*|"$root"/momentum)
      echo "m-teardown: $dir is not a worktree this removes" >&2
      return 1 ;;
    "$root"/momentum-*) ;;
    *)
      echo "m-teardown: $dir is not a $root/momentum-<desc> worktree" >&2
      return 1 ;;
  esac

  if [ -n "$force" ]; then
    echo "$label ($branch): forced, no checks - uncommitted and unpushed work goes with it"
  else
    echo "checking $label ..."
    pr="$(_m_td_pr_of "$branch")"
    IFS=$'\t' read -r verdict detail < <(_m_td_check "$dir" "$branch" "$pr")
    echo "$label ($branch): $verdict  $detail"
    case "$verdict" in
      SPENT|KEEP) ;;
      *) echo "not removed. --force overrides."; return 1 ;;
    esac
  fi

  read -r -p "tear down $label? [y/N] " ans </dev/tty || return 1
  case "$ans" in y|Y) ;; *) echo "left alone"; return 1 ;; esac

  # Standing in it would break every command after the removal.
  [ "$dir" != "-" ] && case "$PWD/" in "$dir"/*) cd "$main" || return 1 ;; esac
  _m_td_remove "$label" "$dir" "$branch" "$force"
}

m-purge() { m-teardown --purge "$@"; }

m-teardown() {
  local root main a arg="" force="" pull="" purge="" yes="" sel=1 sel_key="" key
  root="$(_m_root)"
  main="$root/momentum"
  if [ ! -e "$main/.git" ]; then
    echo "no momentum checkout at $main" >&2
    return 1
  fi
  mkdir -p "$(_m_td_state)" 2>/dev/null
  _M_TD_WT_CACHE=""                  # a worktree or branch may have come or gone since last time

  for a in "$@"; do
    case "$a" in
      --force|-f) force=1 ;;
      --pull|-p)  pull=1 ;;
      --purge|-P) purge=1 ;;
      --yes|-y)   yes=1 ;;
      this)       arg="$(_m_teardown_this)" || return 1 ;;
      -*)         echo "m-teardown: unknown option $a" >&2; return 1 ;;
      *)          arg="$a" ;;
    esac
  done

  if [ -n "$purge" ] && [ -n "$force" ]; then
    echo "m-teardown: --force and --purge do not combine; a purge only ever removes what is spent" >&2
    return 1
  fi

  [ -n "$pull" ]  && { _m_td_land; return $?; }
  [ -n "$purge" ] && { _m_td_purge_cmd "$yes"; return $?; }
  [ -n "$arg" ]   && { _m_td_one "$arg" "$force"; return $?; }

  # Interactive. The table owns the top of the screen and the keys always act on
  # the selected row; the scan and any removal run detached behind it, with their
  # output tailed into the pane underneath, so nothing ever covers the list.
  local frame last="" dirty=1 wt_stale=1 note="" excluded=0 rc=0 waits=0
  local job="" what="" kind="" busy_key="" busy_text="" seq="" ch="" traps="" bail=""
  local cf_kind="" cf_dir="" cf_label="" cf_branch="" cf_verdict="" cf_force="" cf_count=0
  local label branch dir st tbl nl atext used avail i
  local -a rows ordered

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
      job="" busy_key="" busy_text=""
      wt_stale=1 dirty=1
      # A removal changed what every other verdict was worked out against, and
      # the rows that just went have to leave the table, so the list is re-read
      # and the scan runs again on its own.
      if [ "$kind" = remove ]; then
        job="$(_m_td_action_start _m_td_scan)"
        what="scan" kind=scan
      else
        kind=""
      fi
    fi

    if [ "$wt_stale" = 1 ]; then
      _m_td_rows rows fresh || { bail="m-teardown: nothing to tear down"; break; }
      excluded=$(( $(_m_dev_worktrees | wc -l) - $(_m_td_targets | wc -l) ))
      wt_stale=0
    fi

    _m_td_status_load
    _m_td_order rows ordered

    # The selection follows the row it is on rather than the position: a verdict
    # landing moves rows between the two halves under it.
    if [ -n "$sel_key" ]; then
      for i in "${!ordered[@]}"; do
        read -r label branch dir <<<"${ordered[$i]}"
        [ "$(_m_td_key "$branch" "$dir")" = "$sel_key" ] && { sel=$((i + 1)); break; }
      done
    fi
    [ "$sel" -gt "${#ordered[@]}" ] && sel="${#ordered[@]}"
    [ "$sel" -lt 1 ] && sel=1
    read -r label branch dir <<<"${ordered[$((sel - 1))]}"
    sel_key="$(_m_td_key "$branch" "$dir")"

    tbl="$(_m_td_table ordered "$sel" "$busy_key" "$busy_text" "$_M_DEV_COLS")"

    frame="momentum worktrees and branches - what is safe to tear down"$'\n\n'
    frame+="$tbl"$'\n\n'
    if [ -n "$cf_kind" ]; then
      # The frame gives a confirmation one line and the fit clips it at the window
      # width, so the answer it asks for comes before anything explaining it: at
      # 80 columns a long name used to push "y / anything else" off the end. The
      # selected row is directly above with its branch and verdict on it, so this
      # does not repeat them.
      if [ "$cf_kind" = purge ]; then
        frame+="  purge $cf_count spent row(s)?  y / anything else  (each is re-checked first)"
      elif [ -n "$cf_force" ]; then
        frame+="  FORCE remove $cf_label?  y / anything else  (uncommitted and unpushed work goes too)"
      elif [ "$cf_dir" = "-" ]; then
        frame+="  delete branch $cf_branch?  y / anything else"
      elif [ "$cf_verdict" = KEEP ]; then
        frame+="  tear down $cf_label?  y / anything else  (it holds work main lacks)"
      else
        frame+="  tear down $cf_label?  y / anything else"
      fi
    else
      frame+="  up/down select   d tear down   D force   X purge spent   r rescan   p land main   q quit"
    fi
    [ "$excluded" -gt 0 ] && frame+=$'\n'"  $excluded other momentum worktree(s) elsewhere are never touched"
    [ -n "$job" ] && frame+=$'\n'"  running: $what"
    [ -n "$note" ] && frame+=$'\n'"  $note"

    nl="${tbl//[!$'\n']/}"
    used=$(( ${#nl} + 5 ))
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
    if [ -n "$cf_kind" ]; then
      if [ "$key" = y ] || [ "$key" = Y ]; then
        if [ "$cf_kind" = purge ]; then
          case "$PWD/" in
            "$main"/*) ;;
            "$root"/momentum-*) cd "$main" && note="stepped out of the worktree into $main" ;;
          esac
          what="purge" kind=remove
          job="$(_m_td_action_start _m_td_purge)"
        else
          [ "$cf_dir" != "-" ] && case "$PWD/" in
            "$cf_dir"/*) cd "$main" && note="stepped out of $cf_label into $main" ;;
          esac
          what="tear down $cf_label" kind=remove
          busy_key="$(_m_td_key "$cf_branch" "$cf_dir")" busy_text="removing ..."
          job="$(_m_td_action_start _m_td_remove "$cf_label" "$cf_dir" "$cf_branch" "$cf_force")"
        fi
        [ -n "$job" ] || { note="could not start $what"; busy_key="" busy_text="" kind=""; }
      elif [ "$cf_kind" = purge ]; then
        note="nothing purged"
      else
        note="left $cf_label alone"
      fi
      cf_kind="" cf_dir="" cf_label="" cf_branch="" cf_verdict="" cf_force="" cf_count=0
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
        sel_key=""
        ;;
      'k') sel=$((sel - 1)); sel_key="" ;;
      'j') sel=$((sel + 1)); sel_key="" ;;
      'd'|'D')
        read -r label branch dir <<<"${ordered[$((sel - 1))]}"
        st="$(_m_td_status "$(_m_td_key "$branch" "$dir")")"
        if [ -n "$job" ]; then
          note="wait for $what to finish"
        elif [ "$dir" = "$main" ]; then
          note="the default worktree is never removed; p lands it on main"
        elif [ "$key" = D ]; then
          cf_kind=one cf_dir="$dir" cf_label="$label" cf_branch="$branch" cf_verdict=FORCE cf_force=1
        else
          case "${st%% *}" in
            SPENT|KEEP) cf_kind=one cf_dir="$dir" cf_label="$label" cf_branch="$branch" \
                          cf_verdict="${st%% *}" cf_force="" ;;
            *) note="$label: ${st#* } - D forces it" ;;
          esac
        fi
        ;;
      'X')
        if [ -n "$job" ]; then
          note="wait for $what to finish"
        else
          cf_count=0
          for i in "${!ordered[@]}"; do
            read -r label branch dir <<<"${ordered[$i]}"
            [ "$(_m_td_verdict "$(_m_td_key "$branch" "$dir")")" = SPENT ] && cf_count=$((cf_count + 1))
          done
          if [ "$cf_count" -eq 0 ]; then
            note="nothing is spent, so there is nothing to purge"
          else
            cf_kind=purge
          fi
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
    dirty=1
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

# --- m-doctor: the toolchain every worktree shares ---------------------------
#
# A worktree isolates the source and bin/obj. It does not isolate the toolchain:
# ~/.nuget/packages, NuGet's lock files, the MSBuild node pool and VBCSCompiler
# are one set per user. Sharing them is fine. Two worktrees restoring and
# building at the same time was measured clean.
#
# The exception is NuGet's lock, which has no timeout and no override. A process
# that takes one and then stops (state T) blocks every dotnet restore on the box
# until it is resumed or killed. `make dev` then hangs with no output, which
# reads as a broken m-dev and looks cured by a reboot - the reboot only kills the
# stopped process. Seen 2026-09-08: a suspended `aspire nuget search` held one
# for an hour, and a one-package restore in an empty temp directory hung past
# 100s, then finished in 1.1s once the lock was let go.
#
#   m-doctor         report
#   m-doctor --fix   resume a suspended holder, delete dead MSBuild sockets
#   m-doctor --sniff one line if it looks wedged, silence if not, for a timer
#
# m-dev runs the resume part itself before every start, so the hang cannot
# happen behind the board, and d runs --fix into the pane.

_m_doctor_lockdir() { printf '%s\n' "/tmp/NuGetScratch$(id -un)/lock"; }

# The lock files something is really holding. flock takes the same exclusive lock
# NuGet does, so one it cannot take is in use. Counting the directory tells you
# nothing: NuGet never deletes these files, so nearly all of them are inert.
_m_doctor_held() {
  local f
  for f in "$(_m_doctor_lockdir)"/*; do
    [ -f "$f" ] || continue
    flock -n -x "$f" true 2>/dev/null || printf '%s\n' "$f"
  done
}

# The pid with a lock file open. One find, not a readlink per fd, which is
# thousands of forks on a box with this many dotnet processes on it.
_m_doctor_holder() {
  local hit
  hit="$(find /proc -maxdepth 3 -path '/proc/[0-9]*/fd/*' -lname "$1" -printf '%h\n' 2>/dev/null | head -1)"
  hit="${hit#/proc/}"
  printf '%s\n' "${hit%/fd}"
}

_m_doctor_state() { awk '{print $3}' "/proc/$1/stat" 2>/dev/null; }
_m_doctor_cmd() { tr '\0' ' ' <"/proc/$1/cmdline" 2>/dev/null | cut -c1-88; }

# Resume anything stopped while holding a nuget lock. Resume rather than kill:
# the holder has usually finished its work already, so SIGCONT lets it exit on
# its own. Returns 1 only if a stopped process still holds a lock afterwards,
# which is the one state a caller must not start a build in.
_m_doctor_unwedge() {
  local f pid rc=0 acted=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    pid="$(_m_doctor_holder "$f")"
    [ -n "$pid" ] || continue
    case "$(_m_doctor_state "$pid")" in T*) ;; *) continue ;; esac
    echo "m-doctor: pid $pid stopped while holding a nuget lock, resuming it"
    echo "m-doctor:   $(_m_doctor_cmd "$pid")"
    kill -CONT "$pid" 2>/dev/null
    acted=1
  done < <(_m_doctor_held)
  [ "$acted" = 1 ] || return 0

  sleep 5
  local still=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    still=1
    pid="$(_m_doctor_holder "$f")"
    [ -n "$pid" ] || continue
    case "$(_m_doctor_state "$pid")" in
      T*) echo "m-doctor: pid $pid is still stopped and still holding it; kill $pid by hand" >&2
          rc=1 ;;
      *)  echo "m-doctor: pid $pid took the resume and still holds the lock, so it went back to"
          echo "m-doctor:   work rather than exiting. It should finish on its own." ;;
    esac
  done < <(_m_doctor_held)
  [ "$rc" = 0 ] && [ "$still" = 0 ] && echo "m-doctor: lock released"
  return "$rc"
}

# MSBuild leaves its socket behind when a node is killed. Litter, not a stall -
# but it is the pile that gets mistaken for the problem, so it is counted here
# and swept by --fix. Prints how many were dead.
_m_doctor_sockets() {
  local f pid dead=0
  for f in /tmp/MSBuild*; do
    [ -S "$f" ] || continue
    pid="${f#/tmp/MSBuild}"
    [ -d "/proc/$pid" ] && continue
    dead=$((dead + 1))
    [ "${1:-}" = clean ] && rm -f "$f"
  done
  printf '%s\n' "$dead"
}

# Every stopped process, whatever it is. No forks: the whole point is that this
# is cheap enough to run on a timer. The state field is read after the last ") "
# rather than as field 3, because a comm with a space in it shifts them.
#
# Deliberately not filtered to dotnet and friends. The name would only save the
# odd tier-2 sweep, and it costs the cases that matter: the holder of a nuget
# lock is whatever process opened it, and guessing its name is how a real wedge
# gets missed. Tier 2 proves ownership, which is the actual evidence.
_m_doctor_stopped() {
  local d pid line st
  for d in /proc/[0-9]*; do
    pid="${d#/proc/}"
    # Silenced before it runs, not after: a process can exit between the glob and
    # this read, and bash applies redirections left to right, so the other order
    # still prints "No such file or directory" over whatever is on screen.
    read -r line 2>/dev/null <"$d/stat" || continue
    st="${line##*) }"
    st="${st%% *}"
    [ "$st" = T ] && printf '%s\n' "$pid"
  done
}

# One line if the box looks wedged, nothing if it does not. Exit 0 means there is
# something to say. Two tiers on purpose: the /proc pass above costs no forks and
# rules out the wedge outright, so the 95-fork lock sweep only runs on the rare
# occasion something is actually stopped. A stopped process holding no lock is
# left unsaid - it is harmless, and a warning nobody needs is one they learn to
# ignore.
_m_doctor_sniff() {
  local stopped f pid
  stopped="$(_m_doctor_stopped)"
  [ -n "$stopped" ] || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    pid="$(_m_doctor_holder "$f")"
    [ -n "$pid" ] || continue
    case $'\n'"$stopped"$'\n' in
      *$'\n'"$pid"$'\n'*)
        echo "nuget lock held by stopped pid $pid"
        return 0 ;;
    esac
  done < <(_m_doctor_held)
  return 1
}

# The sniff as a line for the top of the m-dev board. Always says something,
# even when there is nothing wrong: a warning that only shows up when it is bad
# tells you nothing on the day it is missing because the check itself broke.
_m_dev_sniff_line() {
  local r
  r="$(_m_doctor_sniff)" && r="! $r" || r="no stuck lock"
  printf 'm-doctor --sniff result: %s\n' "$r"
}

# Reused MSBuild nodes, one pool for the whole box. Counted off /proc rather
# than with `pgrep -f`, which also matches any shell whose command line merely
# mentions the pattern, this one included. argv[0] narrows it to dotnet first, so
# only a handful of processes cost a fork.
_m_doctor_nodes() {
  local pid a0 cmd n=0
  for pid in /proc/[0-9]*; do
    pid="${pid#/proc/}"
    a0=""
    IFS= read -rd '' a0 2>/dev/null <"/proc/$pid/cmdline"
    case "$a0" in */dotnet|*/MSBuild) ;; *) continue ;; esac
    cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)"
    case "$cmd" in *MSBuild.dll*/nodemode:1*) n=$((n + 1)) ;; esac
  done
  printf '%s\n' "$n"
}

# A package directory with no .nupkg.metadata is a half-written extract: NuGet
# writes that file last. A killed restore is how one would appear.
_m_doctor_partial() {
  local d
  for d in "$HOME"/.nuget/packages/*/*/; do
    [ -d "$d" ] || continue
    [ -f "$d.nupkg.metadata" ] || printf '%s\n' "${d#"$HOME"/.nuget/packages/}"
  done
}

# The host ports AppHost.cs hardcodes. It cannot move off them, so anything else
# sitting on one fails `make dev` - the other way m-dev appears not to run.
_M_DOCTOR_PORTS='3000|4242|5081|5082|11600|15672|17080|18888'

m-doctor() {
  local fix=0 sweep="" files held partial dead bound problems=""
  [ "${1:-}" = --sniff ] && { _m_doctor_sniff; return $?; }
  [ "${1:-}" = --fix ] && { fix=1; sweep=clean; }

  files="$(ls "$(_m_doctor_lockdir)" 2>/dev/null | wc -l)"
  partial="$(_m_doctor_partial)"
  dead="$(_m_doctor_sockets $sweep)"
  bound="$(ss -ltnH 2>/dev/null | awk '{print $4}' | grep -oE '[0-9]+$' |
    grep -xE "$_M_DOCTOR_PORTS" | sort -un | tr '\n' ' ')"

  echo "m-doctor"
  printf '  %-14s %s versions, %s partial\n' 'package cache' \
    "$(ls -d "$HOME"/.nuget/packages/*/*/ 2>/dev/null | wc -l)" \
    "$(printf '%s' "$partial" | grep -c . )"
  printf '  %-14s %s shared across every worktree, %s dead sockets%s\n' 'msbuild' \
    "$(_m_doctor_nodes)" "$dead" \
    "$([ "$fix" = 1 ] && [ "$dead" -gt 0 ] && echo ' (swept)')"
  printf '  %-14s %s exited containers, %s localdev volumes\n' 'docker' \
    "$(docker ps -aq -f status=exited 2>/dev/null | wc -l)" \
    "$(docker volume ls -q 2>/dev/null | grep -c localdev.apphost)"

  # Problems last, and the verdict last of all: m-dev's pane under the table
  # shows only the final three lines of this.
  [ -n "$partial" ] && problems+="  half-extracted packages, delete them and restore:"$'\n'"$(sed 's/^/    /' <<<"$partial")"$'\n'
  if [ -n "$bound" ] && ! _m_dev_active_dir >/dev/null 2>&1; then
    problems+="  ports $bound are taken and no momentum stack owns them; make dev will fail"$'\n'
  fi

  held="$(_m_doctor_held)"
  if [ -z "$held" ]; then
    printf '  %-14s %s files, none held\n' 'nuget locks' "$files"
  else
    printf '  %-14s %s files, %s held\n' 'nuget locks' "$files" "$(grep -c . <<<"$held")"
    local f pid st
    while IFS= read -r f; do
      pid="$(_m_doctor_holder "$f")"
      [ -n "$pid" ] || { problems+="  a lock is held by a process that has gone; nothing to do but wait"$'\n'; continue; }
      st="$(_m_doctor_state "$pid")"
      case "$st" in
        T*) problems+="  WEDGED  pid $pid is stopped and holding a nuget lock"$'\n'
            problems+="          $(_m_doctor_cmd "$pid")"$'\n'
            problems+="          every dotnet restore on this box is blocked behind it"$'\n' ;;
        *)  problems+="  pid $pid holds a nuget lock and is running ($st); a restore is in flight, this is normal"$'\n' ;;
      esac
    done <<<"$held"
  fi

  if [ -z "$problems" ]; then
    echo "  ok"
    return 0
  fi
  printf '%s' "$problems"
  if [ "$fix" = 1 ]; then
    _m_doctor_unwedge && echo "  fixed what it could" || return 1
  else
    echo "  m-doctor --fix resumes a stopped holder"
  fi
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
#   m-dev              the m-doctor --sniff result, then a live table:
#                      up/down select, enter switch, s stop,
#                      d doctor, c clear the log panes, r refresh, q quit.
#                      The table never leaves the top of the screen and the keys
#                      always act on the selected row; actions run behind it, and
#                      the rest of the window is a live tail of m-dev's own
#                      progress and of the stack's own output - aspire, the
#                      services, errors and all.
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
  local all hit row
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

  all="$(printf '%s\n' "${rows[@]}")"
  if ! hit="$(_m_pick "$all" "$1")"; then
    echo "m-dev: no worktree matching '$1'. Known: $(awk '{printf "%s ", $1}' <<<"$all")" >&2
    return 1
  fi
  if [ "$(wc -l <<<"$hit")" -gt 1 ]; then
    echo "m-dev: '$1' matches more than one worktree:" >&2
    awk '{print "  " $1}' <<<"$hit" >&2
    return 1
  fi
  awk '{print $1, $3}' <<<"$hit"
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
  # m-newwork does not install them. `make dev` spawns ui-app's dev server as a
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
  # A stopped process holding a nuget lock makes the restore inside `make dev`
  # wait forever, with nothing on screen to say why. Cheap to rule out here, and
  # unfixable once the stack is 400s into a start that will never finish.
  if ! _m_doctor_unwedge; then
    echo "m-dev: not starting - a stopped process is holding a nuget lock (m-doctor)" >&2
    return 1
  fi

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
    --stop) _m_dev_stop; echo; _m_dev_sniff_line; echo; _m_dev_table; return 0 ;;
    --logs) tail -f "$(_m_dev_log)"; return $? ;;
  esac

  if [ "$#" -gt 0 ]; then
    read -r label dir < <(_m_dev_resolve "$1") || return 1
    _m_dev_switch "$label" "$dir"
    echo
    _m_dev_sniff_line
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
  local frame last="" active stale=1 dirty=1 note="" sniff="" ticks=0 waits=0 rc=0
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
      # Same tick, because it is the same kind of thing: a fact about the box that
      # only a walk can find.
      sniff="$(_m_dev_sniff_line)"
      stale=0
    fi

    # The frame, top down: the table and the keys it answers to, then whatever is
    # left of the window given to the logs - m-dev's own progress first, if it has
    # anything to say, and the stack's output filling the rest.
    frame="momentum stack - one worktree at a time"$'\n'
    frame+="  $sniff"$'\n\n'
    frame+="$(_m_dev_table "$sel" "$active" "$busy_dir" "$busy_text")"$'\n\n'
    frame+="  up/down select  enter switch  s stop  d doctor  c clear  r refresh  q quit"
    [ -n "$job" ] && frame+=$'\n'"  running: $what   (enter or s interrupts it)"
    [ -n "$note" ] && frame+=$'\n'"  $note"

    # Title, the sniff line, blank, table header, its rows, blank, keys, and the
    # two optional lines: what is left is the log's, and no pane may be a row
    # taller than that or the table scrolls off the top.
    used=$(( 6 + ${#rows[@]} ))
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
      'd'|'D')
        # Report and resume, not just report: the only reason to reach for this
        # from the board is that something is already stuck, and --fix only sends
        # SIGCONT and deletes dead socket files.
        [ -n "$job" ] && { _m_dev_action_drop "$job"; note="dropped $what"; }
        what="doctor" busy_dir="" busy_text=""
        job="$(_m_dev_action_start m-doctor --fix)"
        [ -n "$job" ] || note="could not start $what"
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
