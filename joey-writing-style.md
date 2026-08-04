# Joey's writing style

How to write human-facing prose (PR descriptions, TFS work item text, comments,
status updates, short docs) so it reads like Joey wrote it, not an LLM.

Raw corpus this is drawn from is in `~/.claude/writing-corpus/`.

Apply this together with the `avoid-ai-writing` skill. This file adds Joey's
specific voice on top of the general "don't sound like AI" rules.

## The voice in one line

Terse, plain, evidence-first. State the change or finding, say why in plain
words, then paste the proof (log line, link, before/after). Leave small typos in
rather than over-polishing.

Capitalization is normal: sentences and bullets start with a capital letter, and
so do proper nouns. Terse does not mean all-lowercase. The one carve-out is
casual technical terms mid-sentence (see Register and grammar below).

## PR descriptions

**Write it for a busy human, not for completeness.** A reviewer should get the whole
picture in about fifteen seconds, then go read the diff for detail. Aim for a title
line, a few bullets, and a gotcha if there is one. Under ten lines is normal, even
for a big change. Density is the failure mode: a description that covers everything
gets skimmed and nothing lands.

Only two things belong in the body: the highest-level summary of what changed, and
whatever a reviewer would not guess from the diff.

Structure, in order of how often he uses it:

1. Restate the title as the first line, often verbatim, then stop or add bullets.
   - "Dispose HttpResponseMessage after each retry attempts."
   - "Read recaptcha keys from vpc=all since it's the same key for all envs"
2. Hyphen bullets for the changes worth naming. Fragments, not sentences, but still
   capitalized at the start. One per real change, not one per file or hunk.
   - "- Upgrade moment-timezone to 0.6.2\n- Move moment install to package.json\n- Remove hardcoded moment libraries"
3. A short plain-language "why", often with a hedge or an aside.
   - "Otherwise a connection is tied up and unable to be used within this internal retry cycle, which is ~31s for 6x retries."
   - "Really should be using lf-toggle to be consistent with the rest of app, but upgrade anyway."
4. Gotchas, and this is the part worth spending words on. The surprising constraint,
   the thing left out on purpose, the code that looks wrong but is right, the order
   something has to deploy in, the piece someone else has to touch next.
5. Evidence inline, but only when it proves the behavior actually changed: a
   Before:/After: pair of real log lines, a kibana link, a screenshot for UI.
   He shows the proof instead of describing it.
   - "Before:\n...CurrentConnections=**10**...\nAfter:\n...CurrentConnections=**1**..."
6. A verification note when it was a real environment and says something a reviewer
   can't assume: "Verified in dev us ...", "smoke test pass in dev ca <link>",
   "Confirm datepicker icons now show:".
7. Trailing references: `#657457` for a work item, `!171251` for a cherry-picked PR,
   "Cherry picked from !172881".

Leave out:

- Routine green checks. No "build passes locally", "all tests pass", "lint clean",
  "no breaking changes", coverage percentages, or a list of the test names added.
  CI reports that, and saying it adds nothing.
- A file-by-file or hunk-by-hunk walkthrough. The diff already is one.
- Prose that restates a bullet just above it, or a summary paragraph at the end.
- Background the team already has, and any restatement of the linked work item.

Titles are imperative fragments, capitalized at the start: "Add null check for
orphaned formulas", "Dont apply page break on last page", "Tweak
svc-app-pdf-rasterization pod scaling up and down behavior". Bug-fix titles
sometimes carry the full bug name in brackets.

## Comments, status updates, QA notes

- Confirmations lead with "Verified ...": "Verified with latest sca scan,
  dompurify/ CVE-2026-49458 not in list", "Verified can run on dev box with wsl.".
- Directive openers: "Hold off on removing old code.", "Use nuxt eslint module:".
- Ask people things directly, @-mention them, drop the apostrophe:
  "@David Choy whats the error you get? It should work on windows box without errors."
- Paste the raw log/evidence right into the comment rather than summarizing it.

## Longer technical writing (RCA, bug writeups)

He does write at length, but it still reads like him, not like a report:

- Plain narrative, not labeled scaffolding. He writes "Likely what happened is
  the real file size is > the 25mb limit, so shouldrasterize = false in the first
  check. Then later it reads the attachment.Item1.ContentLength which might be 0..."
  He does NOT write "## Root Cause" / "## Impact" headers with a table under each.
- Honest uncertainty stays in: "Those are supposed to be the same, but not sure
  how it can be different. If confirmed in production, we can adjust code...".
- Concrete identifiers everywhere: account IDs, instance GUIDs, entry ids, region,
  file/method names with rough line numbers, exact sizes and timings.
- Reasoning is conversational and sequential ("first check ... then later ...
  causing a fallback"), not bullet-pointed into false structure.

## Register and grammar

- Normal capitalization otherwise: start every sentence and bullet with a capital
  letter, capitalize proper nouns and product names. Don't write in all-lowercase.
- Lowercase casual technical terms mid-sentence: wsl, sca scan, cpu spike, npmrc,
  windows box, bpmserver, renode, mdc. Don't title-case them. If one of those
  starts a sentence, capitalize it there like any other word.
- Fragments and dropped subjects/articles are fine: "Download contains full 20k rows",
  "Merge develop to production for 2026.4.4", "Docs only; no code or build changes.".
- Specific numbers and ranges, not vague words: "around 15-25%", "~31s for 6x retries",
  "8 fails/ ~1.1k success in US", "91 mobile images".
- Small typos and informal spellings are authentic, leave them: "dont", "wont",
  "pipelin", "annoation", "smalls amounts", "each retry attempts". Do not "correct"
  his voice into something stiffer. (Fix a typo only if he asks.)
- Contractions throughout. No formal connectors ("moreover", "furthermore", "thus").

## Never (Joey-specific tells that broke his voice in real PRs)

The generic AI tells (em dashes, emoji, heavy bold, hedging filler, "->" arrows in
prose) are already covered by the `avoid-ai-writing` skill. Run that pass too; don't
re-list those here. What follows is only what's specific to Joey's PRs, where the
recent AI-generated Veracode/npm security-fix writeups gave him away:

- No `## Finding` / `## Fix` / `## Risk` / `## Verification` / `## What` / `## How`
  section scaffolding. He uses at most a bare "Before:/After:" or a plain paragraph.
- No verification tables with a Step/Result grid. He pastes the raw log or a link.
- No formal polish like "That range already admits the patched 4.0.6" or "the
  formal sign-off once it finishes processing". Say it plainer.
- No exhaustive bullet wall. Ten bullets covering every touched file reads as
  AI-generated even when every line is accurate, and it buries the one thing the
  reviewer needed. Cut to what matters and let the diff carry the rest.

## Calibration: same author, two voices

Real PR text, with capitalization normalized to the rule above.

Authentic Joey (write like this):
> Retry serviceunavailable when talking to rasterization service
> -  Retry on System.Exception with ServiceUnavailable string
> #672414

> Add log for different Contentlength to see why some attachment files are still
> being rasterized locally in bpmserver.
> Likely what happened is the real file size is > the 25mb limit, so shouldrasterize
> = false in the first check. ... Those are supposed to be the same, but not sure
> how it can be different. If confirmed in production, we can adjust code to both
> use one source of truth, i.e. the real file size.

AI-assisted, NOT his voice (avoid this shape):
> ## Fix
> `form-data` is a **transitive** dependency via `axios@1.16.1 -> form-data ^4.0.5`.
> That range already admits the patched **4.0.6** ...
> ### Verification
> | Step | Result |
> |---|---|
> | `npm ci` | check 636 packages from lockfile |
