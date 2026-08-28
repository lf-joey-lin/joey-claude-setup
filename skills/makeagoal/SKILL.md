---
name: makeagoal
description: Reword a task, or a week's worth of tasks, into weekly goals a CTO can read and understand without knowing the codebase. Works from the text you type: a sentence, a bullet list, or a rough dump of the week. Returns one to three outcome-level goals in the chat, each one a state that is either true or not by the end of the week, with the tasks it covers listed under it. Asks about anything it cannot tell from the text rather than guessing, and only opens TFS or GitHub when you hand it an explicit work item id or PR link. Invoke when the user types /makeagoal, or asks to "turn this into a goal", "write my weekly goals", "make a goal out of these tasks", "how do I word this for the CTO", or hands over a task list and wants it framed for leadership.
---

# makeagoal: turn tasks into weekly goals a CTO reads once and gets

The input is engineering work described the way engineers describe it. The output
is one to three goals for the week, written so someone who has never opened this
repo knows what will be different when the week ends, and why that matters.

This skill answers in the chat. It writes no files, creates no work items, and
changes no code. If the goals should go on the board, say so at the end and stop.

## Invocation

```
/makeagoal [the tasks, in your own words]
```

The input is normally just text: a sentence, a bullet list, or a rough dump of what
the week holds. That is the expected case. Take it at face value and work from it.

If there is no input and nothing in the conversation covers the week, ask what the
work is. One question, then stop.

## Step 1: work from the text, and ask about what is missing

Do not write a goal from a task title alone. A title says which lever moved, never
what it did, and the goal lives or dies on the second part.

Two things are needed per task, and you need both:

1. **What becomes true when it is done.** The state of the product or the system
   after, not the activity.
2. **Who feels it.** A customer, an admin, the support team, the next developer,
   an auditor. If nobody feels it, it is a chore, and step 4 handles that honestly.

Most short task text carries neither. So **asking is the normal path here, not the
fallback.** Collect every gap first, then ask once, all questions in a single round,
then write. Do not ask in dribs, and do not ask about something the text already
answers.

Worth asking about:

- The outcome, when the text names only the mechanism ("add a cache", "split the
  service"). What does that let somebody do, or stop having to do?
- Who it is for, when the text does not say.
- Whether two tasks belong to the same objective or are separate tracks. Guessing
  this wrong reshapes the whole output.
- Whether it all lands this week, or only part of it does.
- Any number worth quoting, if the text implies a size or a speed without giving it.

Never invent a business reason, an owner, or a number to fill one of these gaps.
Ask, or leave it out and say you left it out.

## Fetching: only when explicitly pointed at something

Do not go looking. No board queries, no branch sniffing, no "what did I commit this
week". The one exception is a pointer typed into the input:

- A work item id or TFS link: read it with the `azure-devops` MCP
  (`wit_get_work_item`), and take the description and acceptance criteria, not just
  the title.
- A PR link or number: `gh pr view`, plus `gh pr diff` when the description is thin.

Even then, read only what was named. Everything else in the request stays text.

## Step 2: group the week into one to three goals

A week is usually one or two real objectives with several tasks under each, so
group by the outcome tasks share, not by component or by sprint order.

- Same outcome, different pieces: one goal. Six tickets that together make bulk
  delete work are one goal, not six.
- Genuinely unrelated tracks (a feature and an unrelated production fix): separate
  goals.
- More than three goals means the grouping is still at task level. Go up one level.
- A task that fits nowhere and matters to nobody does not get its own goal. Roll it
  into the nearest goal's task list, or leave it out and say you left it out.

If the work plainly cannot finish in a week, say that in one line before the goals
and write the goal for the part that can. A goal nobody can hit by Friday is worse
than a smaller one.

## Step 3: write each goal

Format, per goal. Three lines at most:

```
<Goal sentence.>
<One line of context or why, only if a CTO would not already have it.>
Covers: <the tasks it absorbs, in short, comma separated>
```

The goal sentence:

- One sentence. Present or future state, not an activity. "Customers can filter a
  table by any column" beats "Work on table filtering".
- No verb that has no end: started, continued, worked on, made progress on,
  improved. Either it is true on Friday or it is not.
- Plain nouns only. No class names, no file names, no framework names, no ticket
  numbers, no internal component names unless the CTO uses that word himself. If a
  component name is unavoidable, gloss it once in the context line.
- Numbers only if they are real and you read them somewhere. Never invent a
  percentage, a latency, or a count to make a goal sound measurable.

## Step 4: chores and invisible work stay honest

Test coverage, refactors, CI, dependency bumps, migrations. These have no customer
outcome and pretending otherwise is the fastest way to lose a CTO's trust.

Frame them by what they protect or unblock, in the same concrete way:

- A refactor: what the next piece of work stops costing, or which bug class stops
  recurring.
- Tests or coverage: which change can now land without a manual regression pass.
- Infra or pipeline: what deploys or ships that could not before, or what stops
  breaking at 2am.
- A dependency or security bump: the specific exposure that closes.

If none of those is true and the work is housekeeping, say it is housekeeping in
the context line. One honest line beats a manufactured outcome.

## Step 5: check it before sending

Read each goal back and kill it if any of these hold:

- A person outside engineering could not say what changes for them.
- It describes effort rather than a finished state.
- It carries a number you did not read in a real source.
- It uses a word only this team uses, with no gloss.
- Two goals are the same goal wearing different nouns. Merge them.
- It could have been written without reading the actual work. That means it is
  generic, and generic is what gets skimmed.

## Worked example

In, typed straight into the chat:

```
- filter chips on the data table
- keep filters in the url
- fix focus bug when you clear the last filter
```

That says what is being built and nothing about who wants it, so ask, once:

```
Two things before I word these:
1. Who asked for table filtering, and what are they doing today instead?
2. Is the focus bug part of this push, or an unrelated fix that happens to land
   the same week?
```

Say the answers are "the pilot accounts, they export to Excel and filter there"
and "part of it". Out:

```
Customers can narrow a large table down to what they need and share that exact
view as a link, instead of exporting to Excel to filter there.
Filtering was the top ask from the pilot accounts.
Covers: filter chips, filters in the url, focus fix on clearing the last filter
```

Without asking, the same three lines only ever produce this, which says nothing:

```
Improve the data table filtering experience and enhance state management.
```

## Writing style

Joey's rules apply (`~/.claude/joey-writing-style.md` and the writing section of
`CLAUDE.md`), plus one thing specific to this genre: this is the one place where
plain business English wins over his usual clipped engineering fragments. Full
sentences for the goal line, fragments are fine for the task list.

- No em dashes, no emoji, no arrows, no box-drawing characters.
- No headers, no tables, no bold scaffolding. Goal, context line, covers line.
- Short words. If a shorter word means the same thing, use it.
- Cut every adjective that is not carrying information. Comprehensive, robust,
  seamless, enhanced, streamlined, and improved are all noise here.
- No preamble about what you are about to do. Print the goals.

## Ending

After the goals, one line: what you assumed, what you left out, or what you could
not verify. If nothing, say nothing. Then offer the single obvious next step, which
is usually putting them on the board with `create-tfs` or trimming to one goal.
