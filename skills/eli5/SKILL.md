---
name: eli5
description: Turn a concept into a from-scratch tutorial that assumes no prior knowledge, builds up from small pieces, and goes from high-level to low-level detail. Writes to the C:\code2\claude-explains-like-im-five repo as a folder per topic (main page plus subpages for abstractable detail), with mermaid diagrams for the hierarchy and a shared library for reusable building blocks. Invoke when the user types /eli5, or asks to "explain X like I'm five", "write a tutorial on X", "teach me how X works from scratch", or "make an ELI5 for X".
---

# eli5: explain a concept from scratch, as a built-up tutorial

Take one concept and produce a tutorial that a reader with no prior knowledge can
follow start to finish. Begin with the smallest building blocks, explain every
technology or term the first time it appears, and build upward until the whole
concept is assembled. Move from high altitude (one sentence, then the big picture)
down to low-level mechanics, and push detail that can be abstracted out into
subpages so the main page stays a clean narrative.

The output style is already modeled by the tutorials sitting in the target repo
(`ACS-Login-Tutorial.md`, `Momentum-Login-Tutorial.md`,
`momentum-make-run-tutorial.md`). Match their clarity and top-down flow; this skill
just standardizes the structure and adds the folder/subpage/mermaid conventions.

## Invocation

```
/eli5 <concept> [assume: <what the reader already knows>]
```

- `<concept>` is what to explain (e.g. "how DNS works", "how ACS login works",
  "Kubernetes pods"). Required. If missing, ask what to explain before doing
  anything.
- `assume:` is optional. By default assume the reader knows **nothing** and explain
  every term. If the caller states prior knowledge (e.g. `assume: I know Vue and
  HTTP`), skip re-explaining that layer but still name it when it appears. Record
  what was assumed in the tutorial's "How to read" section so a later reader knows
  the starting line.

## Output location

Always write to the repo at `C:\code2\claude-explains-like-im-five`. Never write
tutorials anywhere else.

```
claude-explains-like-im-five/
  README.md                 # index of every topic + a mermaid map of topics
  _shared/                  # reusable building-block explainers, one concept each
    <primitive-slug>.md     # e.g. cookies.md, tcp.md, oauth.md
  <topic-slug>/
    README.md               # the tutorial's main page (top-down narrative)
    <subpage-slug>.md       # abstracted deep-dives for this topic
```

- One folder per topic, `kebab-case` slug derived from the concept
  (e.g. "how DNS works" -> `dns`, "ACS login" -> `acs-login`). The main page is
  always `README.md` inside that folder so it renders as the folder's landing page
  on GitHub.
- Subpages are `kebab-case` `.md` files beside the `README.md`.
- The three existing flat tutorials stay where they are; do not migrate them unless
  asked. New topics use the folder convention.
- If the topic folder already exists, this is an update: read what is there,
  extend or correct it, and keep existing subpage/anchor links working rather than
  rewriting from scratch.

## Step 1: ground the content (detect, then verify)

Accuracy matters most here, and a from-scratch tutorial is exactly where a wrong
detail does the most damage. Before writing, decide what kind of concept this is:

- **Codebase- or system-specific** (names a repo, component, internal system, file,
  or product - e.g. ACS, Momentum, `bpm`, `ui-app`): investigate the real source
  first. Use Explore/Grep/Read against the relevant repo(s) and cite concrete
  anchors (`file_path:line`, repo/module names) the way the ACS tutorial does. Do
  not invent module names, flows, or file paths.
- **General/standard concept** (TCP, OAuth, hashing, DNS): write from model
  knowledge, but web-verify anything version-specific, numeric, or likely to have
  changed (default ports, RFC behavior, current API shapes). When a detail is
  genuinely uncertain and you could not verify it, say so plainly rather than
  guessing confidently.
- **Ambiguous**: if you cannot tell whether the concept is internal or general,
  ask one clarifying question before investing in a wrong grounding path.

## Step 2: reuse and build the shared library

Before explaining a primitive from scratch, check `_shared/` for an existing
explainer and link to it instead of re-explaining. When a building block is
general and likely to recur across topics (a cookie, a hash, TCP, a JWT), write it
once as `_shared/<primitive>.md` and link from the topic. Topic-specific detail
never goes in `_shared/`.

This keeps topics connected into one knowledge base instead of duplicating the
basics in every folder.

## Step 3: write the topic main page (README.md)

The main page is the top-down narrative. Structure, mirroring the existing
tutorials:

1. **Title** - `# How <concept> works` plus a short line naming the intended
   reader and what they will be able to do by the end.
2. **One sentence to hold onto** - a single blockquote that captures the whole idea
   before any detail.
3. **How to read this guide** - what to read in order, and the assumed starting
   knowledge (from `assume:`, default none).
4. **Hierarchy map** - a mermaid `graph TD` showing the concept broken into its
   building blocks, and which blocks live in subpages or `_shared/` (see Mermaid
   conventions).
5. **Building blocks, from scratch** - each primitive gets an everyday **analogy
   first**, then the precise definition. Small, self-contained, in dependency
   order so nothing is used before it is introduced.
6. **The big picture** - assemble the blocks into the whole system at a high level.
7. **Mechanics / walkthroughs** - the low-level detail, step by step. Use mermaid
   sequence or flow diagrams for processes with ordered steps.
8. **Reference + glossary** - lookup tables and every term defined in one place.
9. **Links** - to this topic's subpages and to `_shared/` pages used.

### Altitude: high to low, enforced

Do not flatten everything to one depth. Every topic moves through levels:

- **L1** - one sentence (the "hold onto this" line).
- **L2** - the big picture: the blocks and how they connect.
- **L3** - the mechanics on the main page: how each step actually works.
- **L4** - deep or optional detail, moved into subpages so L1-L3 stay readable.

### When to spin out a subpage

A sub-concept becomes a subpage when it is (a) reusable across topics -> put it in
`_shared/`; (b) detailed enough that inlining it would break the main narrative's
flow; or (c) optional depth a first-time reader can skip. Otherwise keep it inline.
Avoid both extremes: no wall of text, and no death-by-fragmentation where the
reader chases ten tiny files to understand one idea. Each subpage is self-contained
with its own short intro and a link back to the topic's `README.md`.

## Mermaid conventions

- Every topic main page carries a hierarchy diagram (`graph TD`) with the concept
  at the top decomposing into its building blocks. Mark nodes that link out to a
  subpage or `_shared/` page (e.g. a trailing `*`), and explain the marker in a
  line under the diagram. Mermaid nodes cannot themselves be hyperlinks in plain
  GitHub markdown, so pair the diagram with a bullet list of the links.
- Use sequence/flow diagrams (`sequenceDiagram`, `flowchart`) for walkthroughs and
  ordered processes.
- Keep `-` out of mermaid node **ids** (use `acsLogin`, not `acs-login`); it is a
  reserved character in some contexts. Labels (quoted text) may contain anything.

## Writing style

This is human-facing prose, so the writing rules apply:

- Run the **`avoid-ai-writing`** skill over the finished prose before committing
  (full pass for a whole tutorial; inline rules for a small subpage edit).
- Follow the repo/house rules: no em dashes, no emoji, no arrows or box-drawing
  characters, sentence-case headings. Write for a global audience.
- Analogies are the ELI5 half of the job - lead each new primitive with one - but
  the precise definition must always follow. An analogy never stands alone as the
  explanation.

## Step 4: update the index

Keep the root `README.md` current: add the new topic (title, one-line hook, link)
and reflect it in the topic-map mermaid diagram there. Create the root `README.md`
if it does not exist yet.

## Step 5: commit

After the files are written and the writing pass is done, stage the new/changed
files and commit to the target repo (`C:\code2\claude-explains-like-im-five`) on
its current branch. Do not push. Commit message: a short imperative subject naming
the topic (e.g. `Add DNS tutorial`), applying the writing rules. Commit only the
files this run created or changed, not unrelated untracked files already in the
repo.

## Final report

Report what was produced: the topic folder, the main page and any subpages, which
`_shared/` pages were created or reused, how the content was grounded (source
investigated vs general knowledge, and anything you could not verify), and the
commit made. Note the paths so the user can open and review before pushing.
