---
name: plan-bpm-migration
description: Plan and draft the epic for migrating the legacy BPM / PA Forms services (the `bpm` repo's BpmServer and BpmAppFrontendServer Windows roles) into momentum as cloud-native Linux microservices. PLANNING ONLY - no implementation, no code, no PRs. A long-running, multi-session mission: interactively it advances exactly one logical task per session and then stops for human review, and every session reads and updates durable state under the git-ignored `artifacts/bpm-migration/` folder (mission, progress log, to-do backlog, per-subsystem inventory, decisions, target architecture, design briefs, build-versus-adopt evaluations, migration slices, epic draft). Every proposed architecture is reviewed as competing options with real pros and cons, and lands as a self-contained markdown design brief carrying the mermaid diagrams that explain it. Build-versus-adopt questions (for example whether Elsa should carry the routing engine) each become their own pickup-ready sub-task. Has an `auto` mode that runs with no human in the loop and takes the best-recommended option. Grounded in the PA Forms knowledge base at `C:\code\forms_agent_kb\` and the legacy source at `C:\code\bpm`. Invoke when the user types /plan-bpm-migration, or asks to "plan the BPM migration", "work on the forms migration epic", "continue the migration plan", "what's next on the BPM epic", "should we use <library> for <subsystem>", or hands over a legacy Forms/BPM subsystem and wants to plan how it moves to momentum.
---

# plan-bpm-migration: plan the legacy BPM / Forms migration epic

Drive the planning of one very large epic: moving Laserfiche's legacy process
automation platform - the `bpm` repo's Windows-hosted `BpmServer` and
`BpmAppFrontendServer` roles above all - into momentum as cloud-native Linux
microservices on Kubernetes.

The epic is far too large for one session. This skill is the durable memory and
the working method for the whole effort: each invocation orients from the state
files, advances **one** logical task, writes the findings down, and hands back a
short report for a human to review. What survives a session is the markdown under
`artifacts/bpm-migration/`, not the conversation.

## Hard rule: planning only

No implementation, in any session, ever, until a human explicitly ends the
planning phase and starts a build with a different skill.

- Do not write or modify source, `.csproj`, `Dockerfile`, chart, workflow, or
  infrastructure files.
- Do not create branches, commits, or pull requests.
- Do not file TFS work items without explicit per-item approval (see section 8).
- The only files this skill writes are markdown under `artifacts/bpm-migration/`.

Everything produced here is a proposal to be reviewed and argued with. Say so in
the artifacts: mark each one's status (`Draft`, `Reviewed`, `Accepted`).

## Invocation

```
/plan-bpm-migration                       # orient, report status, propose the next task
/plan-bpm-migration status                # state summary only, no new work
/plan-bpm-migration discover <subsystem>  # run a discovery pass on one legacy subsystem
/plan-bpm-migration architect             # advance the target architecture
/plan-bpm-migration design <topic>        # produce a design brief: options, tradeoffs, diagrams
/plan-bpm-migration evaluate <question>   # a build-versus-adopt evaluation (for example Elsa)
/plan-bpm-migration slice                 # (re)build or re-rank the migration slice backlog
/plan-bpm-migration epic                  # draft or refresh the TFS epic text
/plan-bpm-migration auto [n]              # no human in the loop; work n items, default 3
/plan-bpm-migration <freeform>            # anything else; map it onto the phase model
```

Every form except `auto` is interactive: one task, then a review gate. See
"Interactive mode" below.

With no argument, orient and propose the next task from the backlog before doing
work. Do not silently pick a large task.

## Ground rules for every session

1. **Evidence over recall.** Every factual claim about legacy behavior cites a
   real anchor: `bpm:Src/Domain/.../TaskHandler.cs:120`, a knowledge-base file, a
   TFS item, or a momentum path. If you could not determine something, write
   `UNKNOWN:` and what it would take to find out. Never pad the plan with
   plausible-sounding architecture that no one verified.
2. **Write it down.** Findings go into the right state file in the same session
   they are produced. The chat reply is a summary of what changed on disk.
3. **One task, then stop.** Interactive sessions do exactly one logical task,
   fully closed out (section 9), and hand it to a human to review. One task
   reviewed beats five half-explored ones. See "Interactive mode" below; auto
   mode is the only exception.
4. **Contracts first.** The default is to preserve legacy data contracts (DB
   schema, API shapes, message shapes) so existing customer data keeps working.
   Adapters are allowed where the new model genuinely needs to diverge, but each
   divergence is a recorded decision with an owner, not a drive-by.
5. **New architecture is on the table.** Momentum's goal is not a port. Propose
   the k8s-native design that is actually right, then account separately for how
   legacy data and in-flight state reach it.
6. **Never one option.** Every architecture proposal is presented as competing
   options with real pros and cons, scored against stated criteria, ending in a
   recommendation and the conditions that would flip it. A single-option proposal
   is not a proposal, it is a preference. See section 5.
7. **Think outside the box on build versus adopt.** For each capability, ask
   honestly whether a third-party library or service should carry it (for example
   Elsa for the routing engine) or whether owning the code is genuinely better.
   Both directions are live answers. See section 6.
8. **Fork questions into sub-tasks.** When a session hits an open design or
   build-versus-adopt question, do not answer it shallowly inline and do not let
   it derail the current item. Write it into `TODO.md` as a self-contained
   sub-task a cold session can pick up: what to decide, why it matters, candidates
   to look at, anchors to read, artifact to produce.
9. **Delegate legacy source reads.** The `bpm` repo is roughly 180 projects. Read
   it through subagents that return structured findings, never by pulling large
   swaths of it into this context. Invoking this skill authorizes that fan-out.
10. **Style.** No em dash, no emoji, no arrows in prose, no box-drawing
    characters. Sentence-case headings. Terse, factual, skimmable. Tables over
    prose where the content is a list of facts. Mermaid's own edge syntax
    (`-->`, `->>`) is diagram source, not prose, and is fine.

## Interactive mode: one task, then review

Interactive mode is the default: every invocation except `auto` and `status`.

**Do exactly one logical task, then stop and review it with the human.** Do not
start a second task, not even a small one, and not even when the first finishes
early. A session that ends with one reviewed artifact is a good session.

One logical task is one of these, and no more:

| Task | Produces |
|---|---|
| Discovery pass on one subsystem | one `inventory/<subsystem>.md` |
| One design brief | one `plan/designs/<id>-<slug>.md` |
| One build-versus-adopt evaluation | one `plan/evaluations/<id>-<slug>.md` |
| Seam analysis, or one revision of it | `plan/seams.md` |
| One target-architecture pass | `plan/target-architecture.md` or `plan/data-contracts.md`, not both |
| Slice backlog build or re-rank | `plan/slices.md` |
| One slice card | one `plan/slice-<id>.md` |
| Epic draft or refresh | `plan/epic-draft.md` |
| Bootstrap | the state files and the seeded `TODO.md`, and nothing else |

If the picked item turns out to be two tasks wearing one hat (a discovery pass
that clearly needs its own design brief, a slice pass that is really three slice
cards), do the first piece only, write the rest into `TODO.md` as pickup-ready
sub-tasks, and say so in the reply. Splitting is the expected outcome, not a
failure.

If the user's own request names several tasks, say which one you are doing first
and list the rest as the queue. Do not treat a multi-task request as permission
to run them all in one session; work the first, review, and let the human say
continue. The exception is a request that is explicitly "keep going until X",
which is a request for `auto`.

### The review gate

After close-out (section 9), stop and hand back. The reply is a review request,
not a status update. It carries:

- the one task worked and the artifact path it landed at
- the three to five findings that matter, each with its anchor
- the calls you made inside the task that a human might overturn, stated plainly
  enough to argue with
- open questions that need the user
- the proposed next task, as a proposal only

Then wait. The next task starts when the human says so, or in a new session.
If the human reviews and asks for changes to what you just wrote, revising that
artifact is part of the same task, not a new one.

### Keeping a session short

The point of the one-task rule is that the human reviews real work while it is
still cheap to change. Long sessions defeat that, so also:

- Budget the reading. Load only the state files section 0 names and the anchors
  the task needs. Do not re-read the whole `inventory/` folder to write one brief.
- Delegate legacy source reads to subagents (ground rule 9) and keep their
  findings structured. Two or three concurrent, not a fan-out of ten.
- When a task is running long, close out what you have with the unfinished part
  marked `UNKNOWN:` or `In progress` in `TODO.md`, and hand back. A partial
  artifact that is honest about its gaps beats a session that never reaches the
  review gate.

## Auto mode

`/plan-bpm-migration auto [n]` runs without a human in the loop. It exists so the
backlog can be advanced unattended, and so a session never stalls waiting on an
answer nobody is there to give.

In auto mode:

- Work `n` backlog items (default 3, in backlog order) instead of one, then close
  out once for the whole run. This is the only mode that does more than one task,
  and the only one with no review gate between them.
- **Never ask a question. Never present a choice.** Where a human would be asked,
  take the best-recommended option, and record in the artifact both the
  alternative that lost and what would flip the decision. This holds even for a
  genuine coin flip.
- Where a fact is unknown and cannot be established from the sources at hand,
  proceed on an explicit stated assumption, mark the affected artifact section
  `ASSUMED:`, and log the question in `questions.md` anyway so a human can
  overturn it later.
- Artifact status caps at `Draft`. Auto mode never marks anything `Reviewed` or
  `Accepted`, never files a TFS item, and never graduates anything out of
  `artifacts/`. Those need a human.
- Still obey every ground rule above, especially evidence and citations. Auto mode
  removes the human gate, not the standard of proof.
- The closing report lists every decision auto mode made on its own, in one place,
  so a human can review the run by reading that list.

## 0. Bootstrap and orient (do this first, every session)

Resolve paths:

```bash
git rev-parse --show-toplevel          # momentum worktree root
```

State lives at `<root>/artifacts/bpm-migration/`. `artifacts/` is already ignored
by the repo-root `.gitignore`, so no gitignore change is needed. Confirm it before
writing anything, and stop and tell the user if the check fails rather than
writing state into a tracked path:

```bash
git check-ignore -v artifacts/bpm-migration/MISSION.md || echo NOT-ignored
```

Check a full path under the folder, not the bare directory name: the `.gitignore`
pattern is `artifacts/`, which is directory-only, so `git check-ignore artifacts`
reports not-ignored until the directory actually exists on disk.

Then:

- If `artifacts/bpm-migration/MISSION.md` does not exist, this is session one:
  create the state files from
  [`references/state-files.md`](references/state-files.md) and seed `TODO.md`
  with the phase 1 backlog. In interactive mode that is the whole session's task.
  Close out, show the human the seeded backlog, and let them pick what comes
  first rather than starting discovery in the same session.
- Otherwise read, in order: `MISSION.md`, `PROGRESS.md` (last three entries are
  enough), `TODO.md`, and the index tables in `plan/slices.md` and
  `decisions/README.md`. Read an `inventory/` or `decisions/` file only when the
  session's item touches it.

Open [`references/legacy-landscape.md`](references/legacy-landscape.md) whenever
the session touches legacy structure. It holds the verified starting map
(executables, deployment roles, engines, databases) so no session re-derives it.

## The phase model: how the whole effort goes

The epic runs through these phases. They overlap in practice, but a session
should know which phase its item belongs to, and `MISSION.md` records the current
centre of gravity.

| Phase | Goal | Exit criteria | Artifact |
|---|---|---|---|
| 1. Discovery | Understand what the legacy platform actually does and how it is built | Every subsystem in `inventory/` has a filled file; no `UNKNOWN` left that blocks slicing | `inventory/*.md` |
| 2. Seams | Find the real cut lines: coupling, data ownership, shared state | A dependency and data-ownership picture that survives a skeptical read | `plan/seams.md` |
| 3. Target architecture | Design the k8s-native destination, reusing what momentum already has | Component map with owners, contracts, and gaps named | `plan/target-architecture.md`, `plan/data-contracts.md` |
| 3a. Design briefs | Settle each significant design question as competing options with tradeoffs and diagrams | One brief per question, each with a recommendation and a case against it | `plan/designs/<id>-<slug>.md` |
| 3b. Build versus adopt | Decide per capability whether a third party carries it or we own the code | Every open candidate either evaluated or explicitly deferred with a reason | `plan/evaluations/<id>-<slug>.md` |
| 4. Slicing | Break the move into independently shippable slices, ordered easy to hard | Ranked slice backlog, each slice with coexistence and rollback story | `plan/slices.md`, `plan/slice-<id>.md` |
| 5. Epic draft | Turn the plan into an epic plus child features and spec stubs | Draft epic text a human can review in one sitting | `plan/epic-draft.md` |
| 6. Review and graduate | Human review; approved slices become real specs | Slice's spec lands at `src/<component>/specs/spec.md` under a separate skill | (leaves this skill) |

Phase 1 is the current phase at bootstrap, and it deserves real investment. A
migration plan built on a shallow reading of the legacy system is the main way
this epic fails.

## 1. Pick the session's one task

Take the task from the user's argument if given. Otherwise pick from `TODO.md`,
preferring: anything blocking the current phase's exit criteria, then the
highest-value unstarted item, then a stale `In progress` item. State the pick in
one line, say what it will produce, and start. In auto mode, take the first `n`
in that same order without asking.

Pick one. If the backlog's top item is bigger than one logical task, take the
first slice of it and leave the rest in `TODO.md`. If the user's request implies
a phase jump (for example asking for slices while discovery is thin), do it, but
note in the reply which inputs are still missing and how that weakens the output.

## 2. Discovery pass on a subsystem

One legacy subsystem per pass. Candidate list lives in `TODO.md`; the starting
set is in [`references/legacy-landscape.md`](references/legacy-landscape.md).

Method: spawn one subagent per subsystem (two or three concurrently at most, so
findings stay reviewable), each with the knowledge-base entry points and legacy
paths for its area, each returning the fixed structure below. You then reconcile,
challenge anything unsupported, and write `inventory/<subsystem>.md`.

Every discovery file answers these, or marks them `UNKNOWN`:

- **Responsibility.** What the subsystem owns, in one paragraph.
- **Entry points.** HTTP routes, queue message types, scheduled triggers, events.
- **Hosting.** Which executable and deployment role runs it; IIS, OWIN self-host,
  Windows Service, in-process worker.
- **State.** In-memory state, Redis keys and locks, singleton or leader
  assumptions, per-node affinity.
- **Data.** Tables and schemas touched, cluster vs customer database, who else
  writes them, migration history sensitivity.
- **Messaging.** Queues and topics, transport (MSMQ, RabbitMQ, SQS), ordering and
  idempotency assumptions, poison and retry behavior.
- **External dependencies.** Repository or Laserfiche SDK, filesystem and
  FileStore, S3, SMTP, IMAP, HTTP integrations, licensing services.
- **Windows-only coupling.** The list that decides difficulty: MSMQ, WWF
  (`WorkflowEngine83`), IIS or `System.Web`, registry, Windows auth, COM, native
  SDK, drive paths, scheduled tasks, GDI or printing.
- **Tenancy.** How tenant context is resolved and enforced.
- **Auth and authorization.** Token flow, roles, licensing checks.
- **Observability.** Existing logs (see the knowledge base's server-log
  architecture files), metrics, correlation ids worth preserving.
- **Scaling and performance.** Current scaling unit, known hot paths, load shape.
- **Consumers.** Who calls it: other legacy services, sites, mobile, public API,
  on-prem, customer scripts. Public contract or internal only?
- **Tests.** What test coverage exists and how much of it can be reused as a
  migration oracle.
- **Already in momentum.** Anything of this subsystem that momentum has already
  built or started (check `src/` before assuming greenfield; `workflow-engine`,
  `rules-engine`, `repository`, `instants`, and `value-sets` all overlap this
  domain). This check is mandatory. Duplicating work already underway is the
  cheapest mistake to avoid here.
- **Migration notes.** First read on difficulty, obvious seams, obvious traps.

## 3. Seam and coupling analysis

With enough inventory, build `plan/seams.md`:

- A dependency picture at subsystem granularity: who calls whom, through what
  (in-process, queue, HTTP, shared database, shared Redis).
- **Shared-database coupling**, called out explicitly per table. This is usually
  the binding constraint on how independently anything can move, and it is the
  thing most likely to make a clean-looking slice undeployable.
- Shared mutable state outside the database: Redis locks, in-memory caches with
  cross-request lifetime, file shares.
- Transaction and consistency boundaries the legacy code relies on, especially
  anywhere a single database transaction spans what would become two services.
- Candidate cut lines, each with what breaks if you cut there.

## 4. Target architecture pass

Design forward, for Kubernetes and horizontal scale. Anchor in what momentum
already is: read `docs/architecture.md`, the root `CLAUDE.md`, and the relevant
`src/<component>/CLAUDE.md` files rather than inventing a parallel convention.

Cover in `plan/target-architecture.md`:

- Proposed component boundaries under `src/`, one per deployable service or
  library, with the momentum naming conventions.
- Which existing momentum components absorb legacy responsibility versus what
  needs a new component. Name the gap where neither fits.
- Replacements for each legacy platform dependency, with the momentum-native
  choice: MSMQ or RabbitMQ to MassTransit, Redis to `valkey`, IIS or OWIN to
  Kestrel, Windows Service to a Deployment or a leader-elected Job, scheduled
  processors to CronJob or KEDA-scaled workers, FileStore to S3, WWF to a
  first-class engine decision.
- Statelessness and scaling: what has to become stateless, what genuinely needs
  singleton semantics and how that is achieved on k8s (leader election, queue
  partitioning) rather than by one big pod.
- The strangler facade: how traffic gets split between legacy and momentum during
  the years this takes. Momentum's BFF layer (`bff-platform`, `app-bff`,
  `acs-bff`) and `preview-routing` are the obvious places to put the switch, and
  whether the seam sits at the BFF, an ingress rule, or inside a legacy service
  is a per-slice decision.
- Cross-cutting: tenancy and isolation, authz (`authz`), schema migrations
  (`db-migration-runner` plus Atlas), observability, secrets, FIPS base images,
  localization, on-prem versus cloud parity.

And in `plan/data-contracts.md`, the contract inventory: for each contract
(database table or schema, HTTP API, message shape, Consul key, file layout),
whether the plan is `preserve`, `preserve behind an adapter`, or `break`, plus
who consumes it and what a break would cost. Default is `preserve`. Any `break`
needs a decision file in `decisions/`.

`plan/target-architecture.md` is a map, not a place to settle arguments. Anything
in it that is a genuine choice gets forked into a design brief (section 5) or an
evaluation (section 6) and linked from here. When this file starts asserting a
decision no brief supports, that is the signal a sub-task is missing.

## 5. Design proposals: options, tradeoffs, and the review brief

Every significant design question gets its own **design brief** at
`plan/designs/<id>-<slug>.md`. The brief is the artifact a human reviews, so it
has to stand on its own: someone who has read none of the other state files
should be able to read one brief and understand the problem, the options, and why
one won.

A brief is not done until it has all of:

1. **Problem statement.** What has to be decided, and what depends on it. With
   anchors into legacy code or the knowledge base.
2. **Constraints.** The non-negotiables it must satisfy: preserved data contracts,
   multi-tenancy, long-lived in-flight instances, on-prem parity, momentum's
   managed-first and FIPS posture, k8s scaling.
3. **Options: at least two, ideally three, genuinely different.** Not one real
   candidate plus two strawmen. Where it is reasonable, include the honest
   baseline option (port the legacy design as-is, or leave it on the legacy
   platform for now) so the cost of change is visible. Each option gets:
   - how it works, in prose plus a diagram when its shape differs from the others
   - pros, as concrete consequences, not adjectives
   - cons and risks, equally concrete
   - what it costs to reverse once shipped
   - how legacy data and in-flight instances reach it
4. **Comparison against stated criteria.** Name the criteria before scoring, and
   weight them if they are not equal. A table with a row per option and a column
   per criterion, then the reasoning. The table summarizes the argument, it does
   not replace it.
5. **Recommendation**, with a confidence level and the explicit conditions that
   would flip it to the runner-up.
6. **Case against the recommendation.** A real one. Argue the strongest version of
   why the recommendation is wrong before calling the brief ready. If nothing
   survives this section, say so and explain why the decision is genuinely
   uncontested; do not leave the heading empty.
7. **Open questions and sub-tasks spawned**, each also written into `TODO.md`.

### Diagrams are required, not decorative

A design brief without diagrams is incomplete. Use mermaid fenced blocks so the
markdown renders anywhere. Include whichever of these the design actually needs,
and skip the ones that would be empty ceremony:

| Diagram | Mermaid type | Shows |
|---|---|---|
| Component and context | `flowchart` | The component, its neighbours, and what crosses each boundary (HTTP, queue, database, cache) |
| Legacy versus target | two `flowchart` blocks side by side in the doc | What actually changes shape |
| Primary flows | `sequenceDiagram` | One per important flow, end to end, including the failure path |
| Lifecycle | `stateDiagram-v2` | Any long-lived entity's states and transitions, for example a process instance |
| Data ownership | `erDiagram` | Which service owns which tables, and where a table stays shared |
| Coexistence and cutover | `flowchart` | Where the routing switch sits while legacy and momentum both run, and how rollback works |
| Deployment topology | `flowchart` with `subgraph` per namespace | Pods, scaling units, queues, leader election, external dependencies |

Diagram rules:

- Every diagram carries a one-line caption saying what it shows and what to notice.
- The prose must stand alone. A diagram illustrates an argument, it never carries
  one by itself.
- Keep node labels short and put detail in the prose. Avoid parentheses, quotes,
  and colons inside labels; they break mermaid parsing more often than they help.
- Label edges with what actually crosses them, not just an arrow.
- If a flow needs more than roughly fifteen nodes to be honest, split it into two
  diagrams rather than shrinking the labels.

## 6. Build versus adopt: third-party evaluations

Do not default to writing everything ourselves, and do not default to a library
either. For each substantial capability, ask which is genuinely better and answer
it in an evaluation at `plan/evaluations/<id>-<slug>.md`.

Each evaluation covers:

- **The capability and what it must do**, drawn from the inventory, not imagined.
- **Candidates**, including "build it ourselves" as a named candidate with its own
  pros and cons. For each third-party candidate: license and its compatibility
  with shipping to customers, maturity and release cadence, size and health of the
  maintainer base, .NET 10 and Linux fit, whether it is managed-only (momentum's
  compliance posture rules out new native dependencies without explicit sign-off),
  extensibility at the points we need, and operational fit on k8s.
- **Contract fit**, which usually decides it here: can the candidate persist to
  and read the existing legacy schema and definition formats, or does it impose
  its own model? If it imposes one, what does the adapter cost, and does it
  survive contact with the legacy data we must keep working?
- **Lock-in and exit cost.** What it takes to leave two years in.
- **What we lose by adopting.** Control over semantics, debuggability, the ability
  to fix a customer-blocking bug on our own timeline.
- **What we lose by building.** Years of edge cases someone else already paid for.
- **Recommendation**, with confidence and flip conditions, plus a case against it,
  same as a design brief. Include diagrams when the candidates imply different
  runtime shapes.

Adopting a dependency is a proposal only. The repo requires asking before adding
one, so an evaluation ends at a recommendation and never at a decision to take on
a library.

Candidate questions worth seeding as sub-tasks, each its own evaluation:

| Question | Notes |
|---|---|
| Routing and workflow engine: Elsa versus building on momentum's `workflow-engine` versus a durable-execution service | The headline question of the epic. Legacy has two engines already (Reaction and WWF-era `WorkflowEngine83`), so also ask which of those the target replaces first. Contract fit against the existing BP definition XML is likely the deciding factor |
| Durable execution and long-running orchestration | Temporal, Dapr Workflows, or our own queue plus state machine, judged against instances that live for months |
| Rules and expression evaluation | What momentum's `rules-engine` already covers versus a rules library versus a scripting sandbox |
| Scheduling and recurring work | KEDA and k8s CronJob versus Quartz or Hangfire, for the legacy scheduled processors |
| Form definition and rendering runtime | What can be reused from the existing frontend versus rebuilt in `ui-app` |
| Reporting and analytics query layer | Build on the existing schema versus a reporting engine or warehouse |
| Document generation and rasterization | Already solved off-platform by `svc-app-renode` and `svc-app-pdf-rasterization`; confirm before re-planning it |
| Messaging semantics | MassTransit patterns versus raw SQS, for the MSMQ and RabbitMQ behavior being replaced |

Treat that table as a starting set. Write each one into `TODO.md` as a sub-task at
bootstrap so later sessions can pick them up cold, and add to it as discovery
turns up more.

## 7. Slice the migration, easy to hard

A slice is an independently shippable piece of the migration: something that can
go to production behind a switch, be verified, and be rolled back, without the
rest of the epic being finished. Slices go in `plan/slices.md` as a ranked index,
one `plan/slice-<id>.md` card each once a slice gets real attention.

Score each candidate 1 to 5, where 5 is easier or safer, and rank by total. The
score starts the argument, it does not settle it; always record the rationale
next to it.

| Dimension | 5 means |
|---|---|
| Fan-in | Almost nothing in legacy depends on it |
| Data coupling | Owns its tables outright; no shared writers |
| Windows coupling | Pure managed logic, no MSMQ, WWF, IIS, registry, or native SDK |
| Contract stability | Contract is documented, frozen, and small |
| Testability | Verifiable without a full BPM cluster |
| Blast radius | Failure degrades one feature, not a tenant or the cluster |
| Momentum reuse | An existing momentum component already covers most of it |

Each slice card carries: id and name, legacy owner (service plus paths), target
momentum component, in scope and explicitly out of scope, contracts touched, data
ownership plan, dependencies on other slices, coexistence strategy (routing
switch, dual write, read-through adapter, shadow or compare mode), in-flight
state handling, rollback plan, verification plan including the legacy behavior
oracle, effort as t-shirt size, score with rationale, open questions.

Bias the early slices toward: read-only paths, leaf services with few callers,
things with a clean HTTP contract, and anything momentum has already partly
built. Push to the back: the WWF engine, anything with cross-service database
transactions, the routing engine core, and anything with long-lived in-flight
instances that must survive cutover. Say plainly when the honest first slice is
unglamorous.

## 8. Draft the epic

`plan/epic-draft.md` holds the text a human reviews and eventually files in TFS.
Structure it as: epic summary and why now, scope and non-goals, the target
architecture in one page with the two or three diagrams that carry it, the
settled design briefs and build-versus-adopt recommendations as a decision list,
the slice backlog as proposed child features in order, the risk register, open
questions with owners, and what is explicitly deferred. Each still-open design or
evaluation sub-task appears here as a proposed child item of its own, so the
unresolved work is visible in the epic rather than buried in the backlog.

Keep it reviewable in one sitting: link to the state files for detail rather than
inlining them.

Filing to TFS is a separate, explicitly approved step. When the user asks for it,
use the `create-tfs` skill's conventions, one item at a time, and record each
created id back into `plan/epic-draft.md`. Never bulk-file a backlog.

## 9. Close out the session

Before replying, always:

1. Write or update the artifacts the session produced.
2. Append a `PROGRESS.md` entry: date, item worked, what was decided, what
   changed on disk, what is now blocked or open.
3. Update `TODO.md`: close what is done, add what the session uncovered, keep it
   ordered.
4. Add any new open question to `questions.md` with the reason it matters, and
   every open design or build-versus-adopt question to `TODO.md` as a pickup-ready
   sub-task (ground rule 8).
5. Move a planning decision into `decisions/NNN-<slug>.md` when the session
   settled something that later sessions must not silently relitigate. A design
   brief or evaluation that reached a recommendation gets its decision recorded
   there too, with a link to the brief, so the reasoning is not re-argued.
6. Update the index tables in `plan/designs/README.md` and
   `plan/evaluations/README.md` if either gained a file.

Then reply with, at most: what was worked, the three to five findings that matter,
files changed, the calls a human might overturn, open questions needing the user,
and the proposed next task. No recap of the whole mission.

In interactive mode that reply is the review gate: stop there and wait, do not
roll into the next task. In auto mode, add the list of decisions taken without a
human, each with its runner-up and flip condition, and drop the "open questions
needing the user" section into the same list.

## Cross-cutting considerations to keep raising

Check these against whatever the session touches. They are the ones that quietly
sink migrations of this shape:

- Long-lived in-flight process instances. A BP instance can be open for months.
  Cutover cannot assume an empty system, and "drain then switch" is not available.
- Multi-tenant database per customer, plus a cluster database. Per-tenant
  migration and per-tenant rollout is a first-class concern, not a detail.
- The legacy WWF engine (`WorkflowEngine83`) versus the newer Reaction engine:
  two engines, both live, different eras. Any plan that ignores one is wrong.
- Message ordering, idempotency, and poison handling when MSMQ semantics become
  MassTransit or SQS semantics.
- On-prem versus cloud parity. Some of this platform ships to on-prem customers;
  a cloud-only design decision may not be available.
- Licensing and entitlement checks embedded in legacy paths.
- Public and semi-public API surface, including customer scripts and integrations
  no one owns a list of.
- Localization and globalization, per the repo's code style.
- Compliance posture: managed-first, memory-safe, no new native code, FIPS base
  images.
- Observability continuity: existing log schemas and correlation ids are what
  support uses today. Losing them is a real regression.

## Reference anchors

| What | WSL path | Windows path |
|---|---|---|
| Momentum (this repo) | `git rev-parse --show-toplevel` | same worktree |
| Migration state | `<root>/artifacts/bpm-migration/` | same |
| Legacy BPM source | `/mnt/c/code/bpm` | `C:\code\bpm` |
| PA Forms knowledge base | `/mnt/c/code/forms_agent_kb` | `C:\code\forms_agent_kb` |

Entry points worth loading, and nothing more until a session needs them:
`forms_agent_kb/index.md` then the relevant `architecture/*.md`;
`bpm/CLAUDE.md` then the nested `CLAUDE.md` for the executable in question;
momentum's root `CLAUDE.md`, `docs/architecture.md`, `docs/spec-template.md`,
and `docs/adr/`.

Related skills: `forms-rca` for a real Forms defect (that is diagnosis, not
planning), `create-tfs` for filing an approved item, `spec-ui` and the momentum
spec template for graduating an approved slice into a spec.

## What this skill will not do

- Write, refactor, or scaffold any code, project, chart, or pipeline.
- Create branches, commits, or PRs.
- File TFS items without per-item approval.
- Commit to dates or headcount. Effort is t-shirt sizes and dependency order.
- Present an unverified guess as a finding. `UNKNOWN` is a valid, useful answer.
- Present one option as though it were the only one, or pad a brief with strawmen
  to make a favoured option look inevitable.
- Add a dependency. An evaluation recommends; the repo requires asking first.
- Run several tasks back to back in an interactive session, or skip the review
  gate and carry on into the next one. Batching tasks is what `auto` is for.
- Ship a design brief with no diagrams, or with diagrams doing the work the prose
  should be doing.
