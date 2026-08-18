---
name: what-manta-do
description: Answer "what does Manta do for X" by reading the manta-app source and reporting the pattern Manta actually ships, plus the exact place to go see it running. DESCRIPTIVE ONLY - no opinion, no recommendation, no edits. Takes a rough UX phrase ("table with details pane", "how does filtering work", "empty states", "bulk delete confirmation", "date format", "where do toasts appear") and returns what Manta does in plain UX language, whether it is a real convention or a one-off, and the live location - the URL path in the running app, the click path from the sidebar, the Storybook story, and the source files. Invoke when the user types /what-manta-do, or asks "what does Manta do for X", "how does Manta handle X", "does Manta have a X", "show me Manta's X", "where does Manta do X", or hands over a UI pattern and wants Manta's version of it before speccing or designing anything.
---

# what-manta-do Skill

Manta (`~/m-code/manta/manta-app` on WSL/Linux, `C:\code2\manta\manta-app` on
Windows) is the company's other established app. It has a real design system, a
documented brand voice, and a large shipped surface, so it is the fastest answer
to "has anyone here already solved this".

Someone hands you a rough UX phrase. Your job is to find Manta's version of it,
say what it does, and tell them exactly where to go look at it running.

## Hard boundaries

- **Read-only on manta.** Never edit, create, delete, or run anything that
  writes in the manta repo. No branches, no commits, no formatters. You read.
- **Descriptive, not advisory.** Report what Manta does. Do not say whether it
  is good, do not recommend it for this app, do not compare it to industry
  practice. If the user wants a judgment call, that is the `ux-review` skill and
  you should say so in one line and stop.
- **No code output.** Do not paste Svelte, props, or CSS into the answer. File
  paths are required (that is half the deliverable); implementation is not.
- **Never guess a location.** Every path, route, and story name you print must
  be one you actually opened or listed. An answer with a wrong path is worse
  than "I could not find it".

## Language

Describe behavior the way a designer or PM would read it: what the user sees,
what they can do, what happens when they do it. Same rule as `ux-review` -
"the panel slides in over the list and the list stays visible behind it", not
"an overlay organism with a transition".

The one exception is the **Where to see it** block. That block is meant for an
engineer to navigate with, so paths, route names, and story titles belong there
and nowhere else.

## Step 0 - Check the checkout

```bash
ls ~/m-code/manta/manta-app/src/lib/design
```

If it is not there, say so in one line and stop. There is no fallback; this
skill is entirely about reading that tree.

## Step 1 - Turn the rough phrase into Manta's vocabulary

Manta names components by what they are, not by the page that needed them, so
the folder name is usually the search key. Translate the user's words first,
then search on the translation *and* the original.

| The user says | Look for |
| --- | --- |
| table, grid, list of things | `organisms/ItemList`, `ItemGrid`, `ItemListRow`, `organisms/Table`, `atoms/Table`, `molecules/Table`, `templates/ListPanel`, `templates/GridPanel` |
| details pane, side panel, drawer, inspector | `organisms/Drawer`, `templates/ViewerOverlay`, `molecules/DetailsCard`, any `pages/<Surface>/<Entity>Detail/` |
| filtering, faceting, search | `molecules/Filter`, `molecules/FilterMenu`, `molecules/Search`, `organisms/TableFilter`, `organisms/TableToolbar`, `organisms/DateRangeFilterPicker` |
| empty state, no results, zero data | `molecules/EmptyState` |
| bulk actions, multi-select | `molecules/ListBulkBar`, `organisms/BulkTagModal`, `organisms/DeleteItemsModal` |
| confirm, destructive action, are-you-sure | `organisms/DeleteItemsModal`, plus the microcopy table in `DesignSystem.mdx` |
| toast, notification, flash message | `src/lib/utils/toast.ts`, `notFoundToast.ts`, plus `DesignSystem.mdx` |
| right-click, row actions, overflow menu | `molecules/ContextMenu`, `organisms/ActionDropdown`, `organisms/DropdownMenu` |
| inline edit, edit in place | `molecules/EditableText`, `EditableTextArea`, `EditableToggle` |
| form validation, when errors show | `FormValidation.mdx` and the `*Field` organisms |
| dates, durations, counts, file sizes | `src/lib/utils/format.ts`, `src/lib/utils/dateRange.ts`, and `DesignSystem.mdx` "Numbers, dates, and units" |
| navigation, sub-nav, breadcrumbs, tabs | `templates/AppLayout`, `templates/SubnavPageShell`, `organisms/CollapsibleNavSection`, `organisms/Breadcrumb`, `molecules/Tabs` |
| wizard, multi-step create | any `pages/<Surface>/<Entity>Create/`, `pages/DataCatalog/CreateTableWizard` |
| color, density, dark mode, icons, wording | `DesignSystem.mdx` - check this before searching components |

Then search:

```bash
cd ~/m-code/manta/manta-app/src/lib/design
ls atoms molecules organisms templates | grep -i '<term>'
ls pages/*/                                     # surface-level page folders
grep -rl '<term>' --include=*.svelte . | head
```

Copy questions (wording, casing, tone), format questions (dates, counts, sizes),
and naming questions are usually settled outright by `DesignSystem.mdx`. Read it
before you go component hunting.

## Step 2 - Read what it actually does

Once you have a candidate, read three things:

1. **The component** - what states it handles, what the user can do in it.
2. **Its `.stories.svelte`** - the story names are the state list somebody
   decided was worth showing. `Loading`, `Empty`, `WithAction`, `Error` in the
   story list tells you the pattern covers those states.
3. **The real usage** - who imports it. This is what separates a shipped
   pattern from a component that exists.

```bash
cd ~/m-code/manta/manta-app/src
grep -rl 'ComponentName/ComponentName.svelte' routes lib/design/pages
```

## Step 3 - Decide whether it is a convention or a one-off

Say which, every time. The user is deciding whether to copy it, and "Manta does
this everywhere" and "one page does this" carry very different weight.

- **Convention** - documented in `DesignSystem.mdx`, `CONVENTIONS.md`, or
  `FormValidation.mdx`, or used across several surfaces.
- **One-off** - one component on one page, no doc behind it. Say so plainly.
  It may still be the right answer, but it is somebody's week, not a decision.
- **Split** - two surfaces do the same job differently. Report both and say
  they disagree. Do not pick a winner; that is `ux-review`'s job.

`CONVENTIONS.md` §4 is worth knowing by heart: Manta has seven top-level
surfaces (Notebooks, Projects, Automations, Content, Code, Settings,
Dashboards), auth sits outside them, and inside a surface pages take a uniform
Overview / `<Entity>List` / `<Entity>Detail` / `<Entity>Create` / `<Entity>Modal`
shape that mirrors the route tree. If the question is about hierarchy,
navigation, or what a thing is called, start there.

## Step 4 - Pin the live location

This is the half of the deliverable that people actually use. Give as many of
these as you can verify.

**The URL path in the running app.** Find the route file that renders it. A
shared component almost never sits in a route directly - a page component under
`lib/design/pages/` uses it, and the route uses that. So it is two hops:

```bash
cd ~/m-code/manta/manta-app/src
# hop 1 - who uses the component
grep -rl 'ComponentName/ComponentName.svelte' routes lib/design/pages
# hop 2 - for each page component that turned up, who routes to it
grep -rl 'pages/Surface/EntityList/EntityList.svelte' routes
```

Keep going until you land on a `+page.svelte` under `routes/`. Then convert:
`src/routes/(app)/data-catalog/datasets/+page.svelte` → `/data-catalog/datasets`.
The rules: drop `src/routes`, drop any `(group)` segment - `(app)`, `(content)`,
`(automations)`, `(security)` are grouping only and never appear in the URL -
drop `+page.svelte`, and leave `[param]` segments as a named placeholder
(`/data-catalog/datasets/<dataset uuid>`) rather than inventing an id.

**The click path.** The sidebar items are defined in
`src/routes/(app)/+layout.svelte` (the `label` / `href` list around lines
295-320). Give the real sidebar label, not the route slug: "Data Catalog in the
left sidebar, then the Datasets tab", not "/data-catalog/datasets".

**The Storybook story.** Fastest way to see a component in isolation, and it
works with no backend. `npm run storybook` in `manta-app` serves it at
`http://127.0.0.1:6006`. Take the `title` from the `defineMeta` block and the
`name` from the `<Story>` tag, lowercase and hyphenate:

- `title: 'Molecules/EmptyState'` + `<Story name="WithAction" />`
  → `http://127.0.0.1:6006/?path=/story/molecules-emptystate--withaction`
- `title: 'Pages/DataCatalog/DatasetList'`
  → `.../?path=/story/pages-datacatalog-datasetlist--<story>`

Only print a story URL when you have read both the title and a story name out
of the file.

**Running it for real.** Local dev is `npm run dev` in `manta-app`; the
clustered local stack is `https://manta.local` (see the manta README). Mention
this once if the answer needs live data, and do not run either yourself.

**The source files.** Component, its stories, the page folder, the route.

## Step 5 - Report

Keep it short. Someone asked a question, not for a tour.

```
## What Manta does

Two or three sentences in plain UX language. What the user sees, what they
can do, what happens. Include the states it handles if the stories show them.

## Convention or one-off

One line. Which one, and the evidence - the doc that says so, or the count of
surfaces using it.

## Where to see it

- App: /data-catalog/datasets — "Data Catalog" in the sidebar, then "Datasets"
- Storybook: http://127.0.0.1:6006/?path=/story/pages-datacatalog-datasetlist--default
- Component: src/lib/design/organisms/ItemList/ItemList.svelte
- Stories:   src/lib/design/organisms/ItemList/ItemList.stories.svelte
- Used by:   src/routes/(app)/data-catalog/datasets/+page.svelte

## Nearby

Only when it earns a line. Variants of the same pattern elsewhere, or the doc
section that governs it.
```

Drop any heading you have nothing for. If several Manta patterns answer the
question, lead with the one that has the most usage and list the others under
Nearby with one line each.

## When Manta does not do it

Say so in one line and stop. "No counterpart in Manta" is a complete, useful
answer, and it is much more useful than the nearest thing stretched to fit.

If there is a genuinely near miss - Manta solves an adjacent problem, or has a
piece of it - name it and say plainly what is missing. Do not describe a pattern
Manta ships as if it covered a case it does not.

## Scaling

- **A single lookup** ("does Manta have an empty state component") - one search,
  read the component and its stories, three-line answer.
- **A pattern question** ("how does Manta do table filtering") - search the
  vocabulary, read two or three candidates, check usage across surfaces, run the
  convention-or-one-off test, full report.
- **A surface question** ("how does Manta lay out a detail page") - read
  `CONVENTIONS.md` §4 first, then walk two or three real surfaces under
  `pages/` and their routes, and report the shared shape plus where it varies.
