# loom contract (shared)

The one file every loom skill reads. It holds the repo facts, the flight ledger
format, and the attendance contract, so no loom skill carries its own copy of
any of them. When a fact here changes, it changes once.

loom is a dev pipeline for momentum `ui-app` work. The roster:

| Skill | Job |
| --- | --- |
| `loom` | the orchestrator: drives a whole run, delegates every stage |
| `loom-scout` | workspace setup, recon, the brief, lane routing |
| `loom-plan` | slice plan (feature lane only) |
| `loom-slice` | build one slice, checks first (born red) |
| `loom-probe` | adversarial verification: attack, reproduce, report |
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
  outside loom's gate; hand those checks to `prepare-to-ship`.
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
- **Ground truth for the component API**: the installed types under
  `src/ui-app/node_modules/@nuxt/ui/dist/runtime/` (`components/*.vue.d.ts`,
  `composables/*.d.ts`). Never name a Nuxt UI component or prop you have not
  confirmed there.
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
  force-push, never stash review state.
- **Hard stops, every skill, every mode**: anything that looks like a secret;
  a hand-edited generated catalog; the branch being `main`. Stop and report,
  never work around.
- **LSP**: for a TypeScript symbol, load with `ToolSearch("select:LSP")`, then
  `findReferences` / `goToDefinition` / `hover`. If a `.vue` path answers "No
  LSP server available", the reference list is a floor - grep the `.vue` files
  too before any count. Cite `path:line`.

## The flight ledger

One markdown file per run at `src/ui-app/logs/loom/<slug>.md` (gitignored;
create the folder if missing). It is the interface between stages, the resume
point, and the source the final report is generated from. Rules:

- **Append after every stage**, never in a batch at the end.
- **Claims carry evidence and a falsifier.** A stage that asserts something
  records what command proved it (with its exit code or output reference) and
  what observation would disprove it. The orchestrator gates on the evidence
  line, never on prose.
- **Distilled, never pasted.** An evidence line is one line: the command and
  its exit code or the number that matters. Output worth keeping beyond
  roughly twenty lines (a failing suite, a conflict listing, coverage tables)
  goes to a sidecar file under `src/ui-app/logs/loom/<slug>/` and the ledger
  carries the path. The ledger is state, not a log.
- **Resume**: a ledger already existing for the slug means continue from the
  first stage not marked done. Never restart a stage marked `[x]`.
- **Decisions are logged where they are made**: the choice, the alternative,
  one line of why, and whether it was asked or defaulted.
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
- Checks: C1 <assertion> (channel: <what a caller looks at>)
- Touches: <paths>    Attack: <what probe will try>
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
- F1: fixed in <commit> | deferred - <reason>

## Tidy - [ ]
## Gate - [ ]
- <scorecard>    Verdict: READY | NOT READY

## Land - [ ]
- Merge: <sha | up to date>    Push: <yes | local only>    Report: <path>

## Needs human eyes
## Blockers
```

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
  that stays NOT READY - stops the run with a ledger entry; it is never
  guessed past.
- Default order for any open question: this app's precedent, then the house
  conventions in `src/ui-app/CLAUDE.md`, then the most idiomatic Nuxt UI
  shape. Record which level answered it.

## Delegation and nesting

The orchestrator delegates every stage to one subagent and never reads source
or edits code in its own context; it gates on ledger evidence. A stage skill
invoked as that subagent runs its work inline and spawns no further subagents,
with one exception: `loom-land` may fan out one subagent per conflicted file
during the merge. Depth never exceeds orchestrator, stage, conflict-file.

Every stage seed carries: the absolute worktree path, the ledger path, the
mode line (`attended` or `solo`), and the instruction to read this contract
file plus its own skill file before acting.

## Context economy

A long run must not drown the orchestrator. Three rules keep it flat:

- **Stage returns are capped.** A stage returns at most about fifteen lines,
  and nothing in the return may claim what the ledger does not carry - the
  return is a pointer to evidence, not a second copy of it. Tool noise
  (build logs, file contents, diffs) never leaves the stage that made it.
- **The orchestrator reads ledger sections, not the ledger.** Mid-run it
  verifies a stage by reading only that stage's section (search for the
  stage's heading and read from there). The whole file is read exactly
  twice: at resume, and never otherwise by the orchestrator - land reads it
  in full inside its own fresh context to write the report.
- **Re-ground from the file, not from memory.** If the orchestrator's
  context is summarized mid-run, the ledger is the state; continue from it
  and trust nothing recalled that it does not confirm.

If the runtime cannot spawn subagents at all, run the stages inline and
sequentially, in strict order, finishing each stage's ledger section before
starting the next - slower and heavier, but the ledger discipline still
bounds what later stages need to re-read.

## Text rules

No em dash, emojis, arrows, or box-drawing characters in anything written -
ledger, report, code, commits. Sentence-case headings. Short plain sentences.
