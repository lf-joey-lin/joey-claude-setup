# loom contract (shared)

The one file every loom skill reads. It holds the repo facts, the flight ledger
format, and the attendance contract, so no loom skill carries its own copy of
any of them. When a fact here changes, it changes once.

loom is a dev pipeline for momentum `ui-app` work. The roster:

| Skill | Job |
| --- | --- |
| `loom` | the orchestrator: drives a whole run, delegates every stage |
| `loom-finish` | the orchestrator for baking a prototype in, in place |
| `loom-ninja` | the orchestrator for a fast round on a branch that already landed one |
| `loom-scout` | workspace setup, recon, the brief, lane routing |
| `loom-adopt` | read a prototype diff as the spec, revert it, size the round |
| `loom-plan` | slice plan (feature lane only) |
| `loom-crew` | the foreman: runs the slice loop for one wave of slices |
| `loom-slice` | build one slice, checks first (born red) |
| `loom-probe` | adversarial verification: attack, reproduce, report |
| `loom-shape` | one concept-level read of the branch, and the reshape it prices |
| `loom-tidy` | one maintainability pass over the finished branch |
| `loom-gate` | local mirror of the ui-app CI checks |
| `loom-land` | merge main, push, write the report from the ledger |

## Repo facts (single source of truth)

- **Workspace root**: `~/m-code` on WSL/Linux, `C:\code2` on Windows
  (`uname -s`: Linux means WSL). `<root>/momentum` is a read-only reference
  checkout that stays on main - never branch, commit or edit there. All work
  happens in a feature worktree `<root>/momentum-<slug>`, one per run. On WSL,
  worktrees stay on the Linux filesystem, never under `/mnt/c`.
- **Scope**: `src/ui-app` (Nuxt 4 / Vue 3 / `@nuxt/ui` v4 / Tailwind v4),
  plus the realm BFFs (`src/acs-bff`, `src/app-bff`) when a slice needs a new
  browser-facing route - see "BFF slices" below. A branch that touches
  anything else (`sso-auth`, `bff-platform`, another C# service, infra) is
  outside loom's gate; run that component's own checks separately and say so.
- **Commands**, from `src/ui-app`:

  | Check | Command |
  | --- | --- |
  | lint | `npm run lint` (autofix: `npx eslint --fix <paths>`) |
  | typecheck | `npx nuxt typecheck` (there is no npm script for it) |
  | one spec file | `npx vitest run --project=unit <path>` |
  | unit suite | `npx vitest run --project=unit` |
  | coverage, iterating | `npm run test:coverage` |
  | coverage gate | `npm run test:ci` (100% statements + branches, enforced) |
  | build | `npm run build` |
  | a11y | `npm run build-storybook && npm run test:a11y` |
  | dev server | `npm run dev` |

  For a BFF slice, from the repo root:

  | Check | Command |
  | --- | --- |
  | build | `dotnet build src/acs-bff/acs-bff.slnx -c Release` (or the app-bff pair) |
  | one test class | `dotnet test src/<bff>/tests/<Assembly>.Tests/<Assembly>.Tests.csproj --filter "FullyQualifiedName~<TestClass>"` |
  | coverage gate | `npx nx run-many -t test,coverage-threshold --projects=<bff test projects>` - the .NET gate lives in the `coverage-threshold` target (100% line + branch on the BFFs); `test` alone enforces nothing |

- **BFF slices**: when the data path a slice needs does not exist, the slice
  builds it in `acs-bff` or `app-bff` through the **`api-integrator` skill**,
  which is the single source for that work (upstream contract reading, the
  narrowed wire/mapper/bridge/endpoint shape, the status mapping, the
  invariant checklist). loom splits it across its own stages: api-integrator
  Steps 0 to 4 (read the upstream from source, design the browser contract)
  run at plan time, its Step 5 human gate is loom's ask moment 2, and Steps 6
  to 8 (build, cheap verify, optional thin ui-app service composable) run at
  slice time under loom's born-red discipline. Its "stop and hand back" points
  are replaced by loom's own gates; everything else in that file is binding.
  An upstream that is neither realm (api-integrator's "no new realm" boundary)
  is a blocker, not a workaround.
- **Ground truth for the platform API**: the installed packages under
  `src/ui-app/`, never memory. Nuxt UI components and composables are typed at
  `node_modules/@nuxt/ui/dist/runtime/` (`components/*.vue.d.ts`,
  `composables/*.d.ts`); the Nuxt and Vue auto-import roster is
  `.nuxt/imports.d.ts`; the VueUse roster is
  `node_modules/@vueuse/core/dist/index.d.ts`. Never name a component,
  composable or prop you have not confirmed in one of those.
- **Platform before hand-rolled, for behavior as much as for markup.** The
  order is: an app component or composable that already does it, then a Nuxt UI
  component, then a Nuxt or Vue built-in, then a VueUse composable, then
  composition of those, then custom. Run it on the behavior itself - load more
  as a list ends, debounce an input, trap focus, read an element's size, watch
  the clipboard or the page's visibility - not only on the components someone
  already thought to name. A stock component with a hand-written effect wired
  up beside it reads as idiomatic and is the thing this ordering exists to
  catch. Hand-rolling what the platform provides costs a written trade-off
  naming the unit passed over and what it could not do. "Nothing here imports
  it yet" is not a trade-off, and neither is a line count.
- **`@vueuse/core` is declared, and taking one is an ordinary choice now.** It
  is a direct dependency of `src/ui-app` at `^14.4.0` (promoted in `8917f1a39`,
  2026-09-01) as well as arriving under `@nuxt/ui`, and `app/` ships a real
  consumer:
  `app/components/common/table-listing/infinite/InfiniteTableListing.vue:2`
  imports `useInfiniteScroll`. So there is nothing left to approve. A VueUse
  composable sits where the platform ordering above puts it, and it needs no
  ask moment, no "Needs human eyes" line, and no trade-off written for the
  dependency.

  One mechanical fact survives: there is still no `@vueuse/nuxt` and
  `nuxt.config.ts` does not list one, so its composables are **not
  auto-imported** and never appear in `.nuxt/imports.d.ts`. Taking one means an
  explicit `import { x } from '@vueuse/core'`, and the roster to confirm the
  name against is `node_modules/@vueuse/core/dist/index.d.ts` rather than the
  auto-import file. Matching the existing consumer's import style is the whole
  of it.
- **Conventions**: `src/ui-app/CLAUDE.md` is binding - i18n through `t()` with
  keys in `en.json` only, theme palette tokens never hex, `<script setup
  lang="ts">`, semantic HTML first and `data-testid` (naming
  `<feature>-<element>-<qualifier>`, entity ids not indexes) only where
  role/label cannot locate.
- **Translations**: only `en.json` is ever hand-edited. `fr.json`, `es.json`,
  `en-XA.json` and the XLIFF memory are pipeline output - never edit, never
  hand-prune, never `translate.ts --pseudo`. A branch that changed `en.json`
  needs the `to-be-translated` label on its PR; `pr-i18n-parity` fails until
  it is on, cannot run locally, and is never a local failure to report.
- **Git**: branch `veryShortCamelCaseDesc` off fresh `origin/main` with
  `--no-track`; publish with `git push -u origin HEAD`; commit subjects
  `[<component>] Imperative summary` (`[ui-app]`, `[acs-bff]`, `[app-bff]`),
  no trailers; merge main, never rebase; never commit to `main`, never
  force-push, never stash review state. The one stash this pipeline makes is
  `loom-adopt`'s, which is the opposite of hiding state: it is announced, its
  ref goes in the ledger, the same content is written to a patch file first,
  and no skill ever drops it.
- **Hard stops, every skill, every mode**: anything that looks like a secret;
  a hand-edited generated catalog; the branch being `main`. Stop and report,
  never work around.
- **LSP**: for a TypeScript symbol, load with `ToolSearch("select:LSP")`, then
  `findReferences` / `goToDefinition` / `hover`. If a `.vue` path answers "No
  LSP server available", the reference list is a floor - grep the `.vue` files
  too before any count. Cite `path:line`.

## The flight ledger

One markdown file per run at `artifacts/loom/<slug>-ledger.md` (`artifacts/`
is gitignored repo-wide, so it works for a branch that never touches
ui-app; create the folder if missing). It is the interface between stages,
the resume point, and the source the final report is generated from. Rules:

- **Append after every stage**, never in a batch at the end.
- **Claims carry evidence and a falsifier.** A stage that asserts something
  records what command proved it (with its exit code or output reference) and
  what observation would disprove it. The orchestrator gates on the evidence
  line, never on prose.
- **Distilled, never pasted.** An evidence line is one line: the command and
  its exit code or the number that matters. Output worth keeping beyond
  roughly twenty lines (a failing suite, a conflict listing, coverage tables)
  goes to a sidecar file under `artifacts/loom/<slug>/` and the ledger
  carries the path. The ledger is state, not a log.
- **Resume**: a ledger already existing for the slug means continue from the
  first stage not marked done. Never restart a stage marked `[x]`.
- **Rounds**: a `loom-finish` round appends `## Round <n>` with every stage
  nested under it, rather than reopening a finished section. One ledger per
  branch however many rounds it takes; slice ids carry the round prefix
  (`R2.S1`) so they stay unique. A round whose stages are all `[x]` is history,
  not a resume point - the next round is `<n>+1`. Branch-scoped stages (probe
  deep, shape, tidy, gate, land) still read the whole branch, so a later round
  re-covers the earlier ones; that is intended, not waste.
- **Ninja rounds**: a `loom-ninja` round is numbered the same way and heads
  itself `## Round <n> (ninja)`. The tag is load-bearing: it is how a later
  settle-up finds the rounds no branch-scoped review pass has covered. Such a
  branch also carries one extra header line, which ninja writes on its first
  round and rewrites on every round after:
  `- Ninja debt: <n> rounds since <sha> (last full review: round <k>, <iso>)`.
  `<sha>` is the commit `loom-probe-deep`, `loom-shape` and `loom-tidy` last
  covered; every skill other than a ninja settle-up carries it forward
  untouched. A full `loom` or `loom-finish` round landing on the branch clears
  it to zero at its own HEAD, because its review tail covered everything.
- **Decisions are logged where they are made**: the choice, the alternative,
  one line of why, and whether it was asked or defaulted.
- **The spine is the state, so nothing is appended below it.** The
  orchestrator's gate decision is the last line of the section it judges
  (`- Gate: accepted - <the evidence line>` or `- Gate: sent back - <why>`),
  never a running list after `## Blockers`. Fix turns are headed per probe,
  `### Fix turn P1.1`, `P1.2` (`R2.P1.1` in a round), so the two-per-probe cap
  is countable from the headings. Resume reads the spine; a spine that stops
  being maintained is a broken resume.
- **Timing is read from the clock, never estimated.** Every stage stamps its
  own section: run `date -Iseconds` when it starts acting, again once its
  ledger write is done, and record one line,
  `- Timing: started <iso>, finished <iso>, took <hh:mm:ss>`. Never write a
  timestamp or a duration you did not read from `date` - a remembered or
  guessed time is worse than no time at all. Get a duration from the shell
  too, not by hand:
  `d=$(( $(date -d '<finish>' +%s) - $(date -d '<start>' +%s) )); printf '%02d:%02d:%02d\n' $((d/3600)) $((d%3600/60)) $((d%60))`.
  Scout stamps the run's start in the header, land its finish. A fix turn or a
  re-probe stamps itself like any other stage.

Template (stages append their own sections; keep this spine):

```markdown
# loom: <feature name>

- Request: <verbatim>
- Lane: patch | feature    Mode: attended | solo
- Branch: <branch>    Worktree: <absolute path>
- Started: <iso8601>    Finished: <iso8601>
- Wall: <hh:mm:ss> (start to finish)    Active: <hh:mm:ss> (stage timings summed)
- Legend: [ ] pending  [~] in progress  [x] done  [!] blocked

## Brief (scout) - [ ]
- Intent / users / data shape / awkward cases
- Precedent: <path> - <what it settles>
- Decisions: <question> - chose <x> over <y>, <why> (asked | defaulted)

## Plan - [ ]            (feature lane only)
### S1 <name> - [ ]    Kind: ui | bff
- Behavior: <what a user sees>
- Platform: <unit taken, confirmed at path:line> | hand-rolled <what> - passed
  over <unit>, <what it could not do>
- Checks: C1 <assertion> (channel: <what a caller looks at>)
- Touches: <paths>    Attack: <what probe will try>
- A11y: <story that renders the new markup | none - adds no markup>
- (bff only) Upstream: <verb + path, read from source>    Route: <verb /bff/...>
  DTO: <fields kept / dropped>    Status map: <reused outcome type>

## Slices
### S1 - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Red: <spec path> failed as expected before implementation
- Green: <commit hash> <subject>
- Verify: typecheck exit 0 | eslint exit 0 | slice specs n/n
- Claims: C1 - evidence: <cmd + result> - falsifier: <what would disprove>

## Probe
### P1 (quick, after S1) - [ ]
- F1: <input -> observed vs expected> (must-fix | polish)
- Promoted specs: <paths | none>
### P-deep - [ ]

## Fixes
### Fix turn P1.1 - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- F1: fixed in <commit> | deferred - <reason>

## Shape - [ ]
- Concept map: <concept> - <its home, or its homes>
### Finding S1 - <concept in one noun phrase>
- Budget: executable | follow-up - <the rule that stopped it>
### Reshape S1 - [ ]        (only when a finding was executable)
- Stages: <n>, each green alone    Tests: <before> to <after>

## Tidy - [ ]
## Gate - [ ]
- <scorecard>    Verdict: READY | NOT READY

## Land - [ ]
- Merge: <sha | up to date>    Push: <yes | local only>    Report: <path>

## Needs human eyes
## Blockers
```

A `loom-finish` round nests the same stages one level down, under its own
heading, and adds two things scout's brief does not have - where the spec came
from, and what the prototype skipped:

```markdown
## Round <n> (loom-finish) - [ ]
### Adopt - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Source: <uncommitted | --from ...>    Patch: <path>    Stash: <ref>
- Behavior: <one line each, with the channel that proves it>
- Prototype gaps: <one line each> - owner: slice R<n>.S<k> | probe | out of scope
### Slices
#### R<n>.S1 - [ ]    Kind: ui | bff
### Probe
#### R<n>.P1 (quick, after R<n>.S1) - [ ]
### Reconcile - [ ]
- Hunks: <compared> - present <n>, dropped with record <n>, missing <n>
- M1: <file> - <what it did> (fixed in <commit> | recorded)
### Fixes
#### Fix turn R<n>.P1.1 - [ ]
### Shape - [ ]
#### Reshape R<n>.S1 - [ ]
### Tidy - [ ]
### Gate - [ ]
### Land - [ ]
```

## The end-of-run receipt

A run's last act, however it ends, is one line at
`artifacts/loom/<slug>-status`:

```
<iso8601> landed|blocked <round> <one line why>
```

Overwrite it, never append. `<round>` is `R<n>` on a round, `R1` otherwise.
Land writes `landed` at the moment it marks Land `[x]`. The orchestrator writes
`blocked` when a stop ends the run, beside the ledger entry it already writes.

The ledger says what happened; this says the run is over. A reader outside the
run cannot get the second from the first, and that is the whole reason this
file exists. A stopped run often never reaches Land at all, leaving it `[ ]`
and marking `## Gate - [!]` or its own round heading instead; a landed round
writes `### Land - [x]` at a depth the previous round's heading does not share;
and an agent sitting idle only means its turn ended, not that the run did.
Anything that starts runs back to back waits on this file - `shell/mqueue.sh`
in `joey-claude-setup` does, one run per worktree - so a run that skips it
holds a queue open until a timeout hours later.

## The attendance contract

One bar, two modes. The quality bar - what gets checked, probed, fixed, and
gated - is identical whether a human is watching or not. The only thing
attendance changes is who answers questions.

- **Attended** (default): the run pauses at exactly two ask moments - after
  the brief (scout) and after the plan. Each is one `AskUserQuestion`. Nothing
  else pauses except a hard stop or a blocker. The push at land is confirmed.
- **Solo** (`--solo`, and any background run): zero asks. Every question takes
  its documented default, logged in the ledger as `(defaulted)` with the
  alternative. Land never pushes solo. A genuine blocker - contradictory
  input, a red acceptance check that two fix turns could not clear, a gate
  that stays NOT READY - stops the run with a ledger entry and a `blocked`
  receipt; it is never guessed past.
- Default order for any open question: this app's precedent, then the house
  conventions in `src/ui-app/CLAUDE.md`, then the most idiomatic Nuxt UI
  shape. Record which level answered it.

## Delegation and nesting

The orchestrator delegates every stage to one subagent and never reads source
or edits code in its own context; it gates on ledger evidence. A stage skill
invoked as that subagent runs its work inline and spawns no further subagents.

Two skills sit between the orchestrator and a stage, and only these two:

- **`loom-crew`** holds the slice loop for a wave of slices. It spawns
  `loom-slice` and `loom-probe`, gates them, and writes the `- Gate:` line for
  the slices in its wave. It reads no source and edits no code, same as the
  orchestrator.
- **`loom-land`** may fan out one subagent per conflicted file during the
  merge.

So depth never exceeds three: orchestrator, then crew or land, then stage or
conflict-file. Gate decisions are owned by whoever ran the stage - the crew
for its wave's slices, the orchestrator for everything else. Nobody else
writes a `- Gate:` line.

Every stage seed carries: the absolute worktree path, the ledger path, the mode
line (`attended` or `solo`), the round number where there is one, and the
instruction to read this contract file plus its own skill file. It is spawned by
the agent type named in the next section, never as a plain `general-purpose`
agent.

## Models

Each stage has its own agent type under `~/.claude/agents/`, and the model and
effort live in that file's frontmatter. **Spawn by `subagent_type`, and never
pass `model` yourself.** One place holds the choice, whoever is doing the
spawning, and a stage cannot end up on the wrong tier because the level above it
was.

| Stage skill | Agent type | Model | Effort | Runs per 4-slice run |
| --- | --- | --- | --- | --- |
| `loom-scout` | `loom-scout` | sonnet | medium | 1 |
| `loom-plan` | `loom-plan` | opus | xhigh | 1 |
| `loom-adopt` | `loom-adopt` | opus | xhigh | 1 to 2 |
| `loom-crew` | `loom-crew` | sonnet | low | 1 to 2 |
| `loom-slice` | `loom-slice` | opus | xhigh | 4, plus fix and reshape turns |
| `loom-probe` quick | `loom-probe-quick` | sonnet | medium | 4, plus re-checks |
| `loom-probe` deep | `loom-probe-deep` | opus | xhigh | 1 |
| `loom-shape` | `loom-shape` | fable | xhigh | 1 |
| `loom-tidy` | `loom-tidy` | opus | high | 1 |
| `loom-gate` | `loom-gate` | sonnet | medium | 1 to 2 |
| `loom-land` | `loom-land` | sonnet | medium | 1 |
| land's conflict fan-out | `loom-merge-conflict` | opus | high | one per conflicted file |

The orchestrators (`loom`, `loom-finish`, `loom-ninja`) run on the session's own model. They
gate rather than think, but a rubber-stamped gate is the one failure this
pipeline cannot absorb, so they are not somewhere to save.

**The rule behind the table: downgrade by frequency, never by stakes.** A stage
that runs four to twelve times per run and executes a list somebody else already
wrote is where efficiency lives. A stage that runs once and produces a claim
nobody can check from outside is where the money should go. That is why the
per-slice probe is cheap and the once-per-run structural read is the most
expensive thing in the pipeline: quick probe runs the Attack line the plan wrote
for it, while `loom-shape`'s own failure mode is answering an easier question
than the one asked, which is exactly what a weaker model does and nothing
downstream would catch.

Two stages are split for this reason alone. `loom-probe` has two agent types
because its quick and deep depths are different jobs at the same desk, and one
of them runs once while the other runs per slice. `loom-land` hands each
conflicted file to `loom-merge-conflict` because the merge around it is
mechanical and the resolution inside it is not.

**The trap this exists to close.** A spawn with no agent type and no `model`
inherits the model of whoever spawned it. `loom-crew` and `loom-land` both sit
on a cheaper tier than the stages they spawn, so a bare `general-purpose` spawn
from either one silently drops the code-writing or conflict-resolving stage a
tier, with nothing in the ledger to show it happened and green checks either
way. Both skills carry the rule at their spawn sites; the agent type is what
makes it hold.

**Haiku is not used anywhere here.** It is 200K context against everything
else's 1M, and `loom-crew`, `loom-shape` and `loom-land` are precisely the
context-absorbing roles.

**If agent types are unavailable** (the runtime does not resolve them, or the
skills are being run somewhere `~/.claude/agents/` is not installed), the
spawner passes `model` explicitly from the table on every single call. Omitting
it is not a neutral default, it is the trap above. Effort cannot be passed per
call, so it goes back to the session default until the agent types are back.

## Context economy

A long run must not drown the orchestrator. Three rules keep it flat:

- **A return has a fixed shape, so it cannot grow.** Mid-run, a stage or a
  crew returns one line per unit of work plus one verdict line, and nothing
  else - no prose, no recap, no tool output:

  ```
  <id> <ACCEPT | BLOCKED> | <one evidence line> | ledger:<heading>
  ```

  The unit is whatever that stage produced one of: a slice for `loom-crew`, a
  finding for `loom-probe` or `loom-shape`, a decision for `loom-scout`, a
  slice entry for `loom-plan`, a scorecard row for `loom-gate`. Scout's and plan's records are
  the lines a human is about to be asked about, so they carry the choice
  rather than a hash; the shape is the same. Nothing in a return may claim
  what the ledger does not carry - the return is a pointer to evidence, not a
  second copy of it. Tool noise (build logs, file contents, diffs) never
  leaves the stage that made it, and a stage with more to say writes it into
  the ledger, which land reads in its own fresh context.

  The cap is on mid-run returns. `loom-land`'s report is the run's output, not
  a return, and is not capped.
- **The orchestrator and the crew read ledger sections, not the ledger.**
  Mid-run either verifies a stage by reading only that stage's section
  (search for the stage's heading and read from there). The orchestrator
  reads the whole file exactly once, at resume; a crew reads the Plan section
  and its own slices' sections and never the whole file. Land reads it in
  full inside its own fresh context to write the report.
- **Re-ground from the file, not from memory.** If the orchestrator's
  context is summarized mid-run, the ledger is the state; continue from it
  and trust nothing recalled that it does not confirm.

If the runtime cannot spawn subagents at all, run the stages inline and
sequentially, in strict order, finishing each stage's ledger section before
starting the next - slower and heavier, but the ledger discipline still
bounds what later stages need to re-read. There is no crew in that mode:
waves exist to partition context across agents, and with one agent there is
nothing to partition.

## Text rules

No em dash, emojis, arrows, or box-drawing characters in anything written -
ledger, report, code, commits. Sentence-case headings. Short plain sentences.
