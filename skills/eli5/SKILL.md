---
name: eli5
description: Explain a piece of input in plain language, in the chat, with enough background to actually follow it. Takes whatever is handed over (a block of text, a diff or PR, a snippet of code, a comment, a code review finding, an error, a spec paragraph) and builds up from context to the point, defining every term it uses. Built for understanding someone else's work or a review comment on your own. For a code review item it separates the issue, the underlying concept, and the options. Invoke when the user types /eli5, or asks to "explain this", "explain this like I'm five", "what does this mean", "I don't understand this comment/finding/PR", "break this down", or "dumb this down for me".
---

# eli5: explain the thing in front of me, in plain language

Someone hands over a piece of input and wants to understand it. Explain it so they
finish reading with a real mental model, not a paraphrase they still cannot act on.

This skill answers in the chat. It writes no files. If the explanation turns out to
be something worth keeping, say so at the end and point at the `make-tutorial`
skill, which writes a lasting from-scratch guide into the tutorials repo. Do not
switch over on your own.

## Invocation

```
/eli5 [the thing, or a pointer to it]
```

The input can be anything:

- Pasted prose: a spec paragraph, a design doc section, a Slack message, an email.
- Code: a snippet, a file, a function, a whole diff.
- A pointer: a file path, a `file:line`, a PR link or number, a work item, a commit.
- A code review finding, from a human reviewer or from a tool.
- Something in this conversation: your own code, your own comment, your own review
  finding, an error you just printed. "this" and "that" usually mean the most
  recent one.

If no input is given and nothing in the conversation is an obvious referent, ask
what to explain. One question, then stop.

## Step 1: get the real thing before explaining it

The failure mode here is explaining a plausible version of the code instead of the
code. It reads fine and teaches the wrong thing, and the user has no way to catch
it, because not knowing is why they asked.

So resolve the input to its source first:

- A path or `file:line`: read it, plus enough around it to know what calls it and
  what it calls.
- A PR or commit: read the actual diff (`gh pr diff`, `git show`), not the
  description. Read the files it touches where the diff alone is not enough.
- A snippet with no context: find where it lives in the repo if it lives here. If
  it does not, say you are explaining it standalone and that behavior may depend on
  callers you cannot see.
- A review finding on code in this repo: read the code it points at and judge
  whether the finding actually holds. See step 4.
- Prose: take it as given, but check any claim it makes about this codebase against
  the codebase.

Anything you could not verify gets said out loud, in one clause, at the point where
it matters. Never paper over a gap with confident phrasing.

## Step 2: work out what the reader is missing

The reason a thing is confusing is almost never the thing itself. It is one or two
prerequisites nobody named. Before writing, list for yourself:

- The terms in the input that carry weight and are not defined by it.
- The pieces of surrounding machinery the input assumes (the framework's lifecycle,
  who calls this, what the data looks like when it arrives, what the platform
  guarantees).
- Why anyone wrote this at all: the problem it exists to solve.

That list becomes the background section. Order it by dependency so nothing is used
before it is introduced.

Calibrate to what the user already knows. If they have shown fluency in something
earlier in the conversation, do not lecture them on it. Name it and move on. If they
say what to assume, honor it. Default to assuming nothing about the specific
domain, and general programming literacy unless the input says otherwise.

## Step 3: explain, building up to the point

Structure the answer as a climb, not a dump:

1. **The one-line version.** What this is, in a sentence, before any detail. The
   reader should be able to stop here and be less confused than when they started.
2. **Background, in dependency order.** Each prerequisite from step 2, one short
   block each: everyday analogy first where one genuinely helps, then the precise
   definition. An analogy never stands alone as the explanation, and a bad analogy
   is worse than none.
3. **The thing itself.** Now walk the actual input. For code, go line by line or
   block by block where that is what the confusion needs, and keep saying what
   state looks like at each point. For prose, restate each claim in plain terms and
   say what it implies.
4. **Why it is like this.** The constraint, bug, or decision that produced it. This
   is usually the part that makes the whole thing click.
5. **What it means for you.** What the reader should now do, watch out for, or
   stop worrying about.

Rules that keep it readable:

- Never use a term you have not defined, including in the one-line version.
- Length tracks the input and the confusion, not the structure above. A confusing
  three-line comment gets a few paragraphs; a 40-file PR gets a real walkthrough.
  Do not pad a small question into all five sections.
- Quote the specific line you are talking about rather than describing it from a
  distance. For repo code, cite `file_path:line` so it is clickable.
- Where an ordered process or a set of moving parts is the hard part, a small
  mermaid diagram (`sequenceDiagram` or `flowchart`) earns its place. Keep `-` out
  of node ids. One diagram, not five.
- No hedging as a substitute for knowing. Either verify it or flag it as unverified.

## Step 4: code review items get a specific shape

A review finding, whether from a person or from a tool, is the most common reason
to reach for this skill and the one with the most ways to go wrong. Explain it in
four separate parts, clearly labeled, and never collapse them:

1. **The issue.** What the reviewer is claiming is wrong, in the concrete: the
   input or state that triggers it, and what actually happens then. If you cannot
   construct that concrete failure from the code, say so plainly, because it is
   real evidence the finding may not hold.
2. **The concept.** The general principle behind the finding, taught from scratch:
   what a race is, why a nullable slipped through, what a rolling deploy does to
   two versions of a contract. This is the part with lasting value. The reader
   should recognize the pattern the next time it appears somewhere else.
3. **The options.** Every reasonable response, including doing nothing. For each
   one, what it costs, what it buys, and what it gives up. Then give your own
   recommendation and the reason for it. Do not present a survey and leave the
   reader to guess which way you lean.
4. **Whether it is even right.** You read the code in step 1, so say whether you
   agree. Reviewers and review tools are both wrong sometimes, and a user who
   cannot yet evaluate the finding is exactly the person who will implement a
   bogus one. If you disagree, say so and show what in the code makes you think
   that.

Explaining your own code or your own review finding follows the same shape. Being
the author is not a reason to soften it.

## Writing style

- Plain, direct, and short-sentenced. Fewer clauses beats more precision here.
- House rules hold: no em dashes, no emoji, no arrows, no box-drawing characters.
- Do not open with a restatement of the question or a preamble about what you are
  about to do. Start explaining.
- Skip the reassurance. "This is a common point of confusion" and "great question"
  add nothing. The reader wants the answer.
- Never condescend. "Like I'm five" is about removing assumed knowledge, not about
  talking down to somebody who is good at their job and new to this corner of it.

## Ending

Close with one line offering the obvious next step, chosen from what actually fits:
which part to go deeper on, whether to apply a fix now, or that this would make a
good `make-tutorial` topic if they want it written down. One offer, not a menu.
