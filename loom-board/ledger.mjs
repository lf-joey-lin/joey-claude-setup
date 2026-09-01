// Flight ledger parser.
//
// Reads a loom ledger (src/ui-app/logs/loom/<slug>.md in a momentum worktree) and
// returns the run's stages, slices, probe findings and gate verdict.
//
// The ledger format is documented in skills/shared/loom-contract.md, but real
// ledgers drift from it, so nothing here requires a line the template promises.
// Anything unrecognised is recorded in `notes` and the affected state stays
// "unknown". A stage is never reported done because it failed to parse.

const MARKER = /\s-\s\[([ x~!])\]/;

/** Stage names, in pipeline order. Matched as a prefix of the heading text. */
export const STAGES = [
    { key: 'scout', match: /^brief\b|^scout\b/i },
    { key: 'adopt', match: /^adopt\b/i },
    { key: 'plan', match: /^plan\b/i },
    { key: 'slices', match: /^slices\b/i },
    { key: 'probe', match: /^probe\b/i },
    { key: 'reconcile', match: /^reconcile\b/i },
    { key: 'fixes', match: /^fixes\b/i },
    { key: 'tidy', match: /^tidy\b/i },
    { key: 'gate', match: /^gate\b/i },
    { key: 'land', match: /^land\b/i },
];

const OTHER_SECTIONS = [
    { key: 'needsHuman', match: /^needs human eyes\b/i },
    { key: 'blockers', match: /^blockers\b/i },
];

const STATE = { ' ': 'pending', x: 'done', '~': 'active', '!': 'blocked' };

/**
 * Roll a container's children up into one state. Children with no marker of their
 * own are ignored rather than held against it: a Fixes section that ends with a
 * "Carried to tidy" note is still finished.
 */
function derive(all) {
    const states = all.filter((s) => s !== 'unknown');
    if (!states.length) return 'unknown';
    if (states.includes('blocked')) return 'blocked';
    if (states.every((s) => s === 'done')) return 'done';
    if (states.some((s) => s === 'done' || s === 'active')) return 'active';
    return 'pending';
}

/** Split markdown into a flat list of headings with their depth, text and body. */
function sections(text) {
    const lines = text.split('\n');
    const out = [];
    let current = null;
    for (const line of lines) {
        const heading = /^(#{1,6})\s+(.*)$/.exec(line);
        if (heading) {
            current = { depth: heading[1].length, heading: heading[2].trim(), body: [] };
            out.push(current);
        } else if (current) {
            current.body.push(line);
        }
    }
    return out;
}

/** Read the `- [x]` marker off a heading, and give back the heading without it. */
function marker(heading) {
    const found = MARKER.exec(heading);
    if (!found) return { state: 'unknown', title: heading.trim() };
    return {
        state: STATE[found[1]],
        title: heading.slice(0, found.index).trim(),
        tail: heading.slice(found.index + found[0].length).trim(),
    };
}

/** The header bullets above the first stage: Request, Lane, Mode, Branch, Started. */
function header(text) {
    const head = text.split(/^##\s/m)[0];
    const field = (name) => {
        const found = new RegExp(`^-\\s*${name}:\\s*(.*)$`, 'im').exec(head);
        return found ? found[1].trim() : null;
    };
    const title = /^#\s+loom:\s*(.*)$/im.exec(head);
    // Lane and Mode share one line: "- Lane: feature    Mode: solo".
    const laneLine = field('Lane') ?? '';
    const modeOnLane = /\bMode:\s*(\S+)/i.exec(laneLine);
    const branchLine = field('Branch') ?? '';
    const worktreeOnBranch = /\bWorktree:\s*(\S+)/i.exec(branchLine);
    return {
        title: title ? title[1].trim() : null,
        request: field('Request'),
        lane: laneLine.split(/\s{2,}|\s+Mode:/)[0]?.trim() || null,
        mode: modeOnLane ? modeOnLane[1] : field('Mode'),
        branch: branchLine.split(/\s{2,}|\s+Worktree:/)[0]?.trim() || null,
        worktree: worktreeOnBranch ? worktreeOnBranch[1] : field('Worktree'),
        started: field('Started'),
    };
}

/**
 * Group sections into rounds. A flat ledger is one implicit round with stages at
 * depth 2; a loom-finish ledger nests each round's stages one level down under a
 * `## Round <n>` heading.
 */
function rounds(all) {
    const groups = [];
    let open = null;
    for (const section of all) {
        const isRound = section.depth === 2 && /^round\s+(\d+)/i.test(section.heading);
        if (isRound) {
            const n = /^round\s+(\d+)/i.exec(section.heading)[1];
            open = { number: Number(n), prefix: `R${n}.`, stageDepth: 3, sections: [] };
            groups.push(open);
            continue;
        }
        if (!open) {
            open = { number: null, prefix: '', stageDepth: 2, sections: [] };
            groups.push(open);
        }
        open.sections.push(section);
    }
    return groups.length ? groups : [{ number: null, prefix: '', stageDepth: 2, sections: [] }];
}

/** Everything under a stage heading, up to the next heading at or above its depth. */
function childrenOf(list, index) {
    const parent = list[index];
    const kids = [];
    for (let i = index + 1; i < list.length; i++) {
        if (list[i].depth <= parent.depth) break;
        kids.push(list[i]);
    }
    return kids;
}

/** `Kind: ui` off a heading tail. */
function kindOf(tail) {
    const found = /\bKind:\s*(\w+)/i.exec(tail ?? '');
    return found ? found[1].toLowerCase() : null;
}

/** An iso8601 stamp as the ledgers write it, date-only tolerated. */
const ISO = String.raw`(\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?)`;

/** `00:08:01` as seconds, or seconds between two stamps that were both written. */
function durationOf(took, started, finished) {
    if (took) {
        const [h, m, s] = took.split(':').map(Number);
        return h * 3600 + m * 60 + s;
    }
    if (!started || !finished) return null;
    const from = Date.parse(started);
    const to = Date.parse(finished);
    if (!Number.isFinite(from) || !Number.isFinite(to) || to < from) return null;
    return Math.round((to - from) / 1000);
}

/**
 * `- Timing: started <iso>, finished <iso>, took <hh:mm:ss>` off a section body.
 * The bullet wraps over several lines in real ledgers and sometimes carries a
 * parenthetical, so it is read as a block up to the next bullet. Whatever was
 * not written down stays null, and a duration is only ever computed from two
 * stamps that were - never from prose and never guessed.
 */
function timing(body) {
    const lines = body.split('\n');
    const start = lines.findIndex((l) => /^\s*-\s*Timing:/i.test(l));
    if (start === -1) return null;
    const block = [lines[start].replace(/^\s*-\s*Timing:\s*/i, '')];
    for (let i = start + 1; i < lines.length; i++) {
        if (!lines[i].trim() || /^\s*-\s/.test(lines[i]) || /^#/.test(lines[i])) break;
        block.push(lines[i].trim());
    }
    const text = block.join(' ');
    const stamp = (name) => {
        const found = new RegExp(`\\b${name}\\s+${ISO}`, 'i').exec(text);
        return found ? found[1] : null;
    };
    const took = /\btook\s+(\d{1,3}:\d{2}:\d{2})/i.exec(text);
    const started = stamp('started');
    const finished = stamp('finished');
    return {
        started,
        finished,
        took: took ? took[1] : null,
        seconds: durationOf(took ? took[1] : null, started, finished),
    };
}

/** `S1`, `R2.S1`, and the name that may follow it. */
function sliceId(title, prefix) {
    const found = /^(?:R(\d+)\.)?S(\d+)\b\s*(.*)$/i.exec(title);
    if (!found) return null;
    const round = found[1] ? `R${found[1]}.` : prefix;
    return { id: `${round}S${found[2]}`, n: Number(found[2]), name: found[3].trim() || null };
}

/**
 * `- F3: text (must-fix)` anywhere in a probe section, including its subsections.
 * A finding runs over several lines and the severity tag often lands on a later
 * one, so each is collected as a block: from its bullet until the next finding,
 * the next heading, or the next line at column zero that is not a bullet.
 */
function findings(text) {
    const lines = text.split('\n');
    const out = [];
    let open = null;
    const close = () => {
        if (!open) return;
        const body = open.lines.join(' ');
        // The tag is not always alone in its brackets: "(polish, tidy's call)".
        open.severity = /\(must-fix\b/i.test(body)
            ? 'must-fix'
            : /\(polish\b/i.test(body)
              ? 'polish'
              : 'unknown';
        open.summary = open.lines[0].replace(/\s*\((must-fix|polish)[^)]*\)/i, '').trim();
        delete open.lines;
        out.push(open);
        open = null;
    };
    for (const line of lines) {
        const start = /^\s*-\s*F(\d+):\s*(.*)$/i.exec(line);
        if (start) {
            close();
            open = { id: `F${start[1]}`, n: Number(start[1]), lines: [start[2]] };
            continue;
        }
        if (!open) continue;
        if (/^#/.test(line) || /^\S/.test(line)) close();
        else open.lines.push(line.trim());
    }
    close();
    return out;
}

/** Same finding id reported by several passes (a re-check restates it). First wins. */
function dedupeFindings(list) {
    const byId = new Map();
    for (const f of list) {
        const seen = byId.get(f.id);
        if (!seen) byId.set(f.id, f);
        else if (seen.severity === 'unknown' && f.severity !== 'unknown') byId.set(f.id, f);
    }
    return [...byId.values()].sort((a, b) => a.n - b.n);
}

/** Which slice a probe pass covered: "P1 (quick, after S1)". P-deep covers none. */
function probeCovers(title, prefix) {
    const found = /\bafter\s+(?:R(\d+)\.)?S(\d+)/i.exec(title);
    if (!found) return null;
    return `${found[1] ? `R${found[1]}.` : prefix}S${found[2]}`;
}

/**
 * A second pass over the whole document, because real ledgers file things under
 * the wrong heading. `inboxInfiniteScroll.md` records two fix turns and the whole
 * of slice S5 under `## Blockers`, long after `## Land` is marked done.
 *
 * A fix recorded anywhere is still a fix and a slice heading anywhere is still a
 * slice, so both are collected document-wide. Where that finds something the
 * section walk missed, it is called out in `notes` rather than quietly absorbed.
 */
function sweep(text, all, run) {
    const resolution = /^\s*-\s*F(\d+):\s*(fixed|closed|deferred)\b/gim;
    let found;
    while ((found = resolution.exec(text)) !== null) {
        if (found[2].toLowerCase() === 'deferred') run.deferred.add(`F${found[1]}`);
        else run.resolved.add(`F${found[1]}`);
    }

    const misfiled = [];
    for (const section of all) {
        const m = marker(section.heading);
        const slice = sliceId(m.title, '');
        if (!slice) continue;
        if (run.slices.some((s) => s.id === slice.id)) continue;
        const body = section.body.join('\n');
        const green = /^-\s*Green:\s*`?([0-9a-f]{7,40})`?\b/im.exec(body);
        run.slices.push({
            id: slice.id,
            n: slice.n,
            round: null,
            name: slice.name,
            kind: kindOf(m.tail),
            planned: 'unknown',
            built: m.state,
            green: green ? green[1] : null,
            timing: timing(body),
            red: /^-\s*Red:/im.test(body),
            probes: [],
            misfiled: true,
        });
        misfiled.push(slice.id);
    }

    if (misfiled.length) {
        run.notes.push(`${misfiled.join(', ')} recorded outside the Slices section`);
    }
}

export function parseLedger(text, meta = {}) {
    const all = sections(text);
    const notes = [];
    const run = {
        ...meta,
        ...header(text),
        stages: {},
        slices: [],
        findings: [],
        openFindings: [],
        resolved: new Set(),
        deferred: new Set(),
        blockers: [],
        deepProbe: null,
        gate: { verdict: null, state: 'unknown' },
        land: { state: 'unknown', push: null, pushed: null, merge: null },
        notes,
    };

    for (const group of rounds(all)) {
        const list = group.sections;
        for (let i = 0; i < list.length; i++) {
            const section = list[i];
            if (section.depth !== group.stageDepth) continue;

            const { state, title } = marker(section.heading);
            const stage =
                STAGES.find((s) => s.match.test(title)) ?? OTHER_SECTIONS.find((s) => s.match.test(title));
            if (!stage) {
                notes.push(`unrecognised section "${title}"`);
                continue;
            }

            const kids = childrenOf(list, i);
            const bodyOf = (s) => s.body.join('\n');
            const whole = [bodyOf(section), ...kids.map((k) => `${k.heading}\n${bodyOf(k)}`)].join('\n');
            const key = group.prefix ? `${group.prefix}${stage.key}` : stage.key;
            // Slices, Probe and Fixes are containers: the template gives them no
            // marker of their own, so their state comes from their children.
            const childStates = kids
                .filter((k) => k.depth === group.stageDepth + 1)
                .map((k) => marker(k.heading).state);
            run.stages[key] = {
                key: stage.key,
                round: group.number,
                state: state === 'unknown' ? derive(childStates) : state,
                derived: state === 'unknown' && childStates.length > 0,
                title,
            };

            switch (stage.key) {
                case 'plan':
                    for (const kid of kids) {
                        const m = marker(kid.heading);
                        const slice = sliceId(m.title, group.prefix);
                        if (!slice) continue;
                        const kind = kindOf(m.tail);
                        run.slices.push({
                            id: slice.id,
                            n: slice.n,
                            round: group.number,
                            name: slice.name,
                            kind,
                            planned: m.state,
                            built: null,
                            green: null,
                            timing: null,
                            probes: [],
                        });
                    }
                    break;

                case 'slices':
                    for (const kid of kids) {
                        const m = marker(kid.heading);
                        const slice = sliceId(m.title, group.prefix);
                        if (!slice) continue;
                        const body = bodyOf(kid);
                        // The hash is bare in one ledger and backtick-wrapped in another.
                        const green = /^-\s*Green:\s*`?([0-9a-f]{7,40})`?\b/im.exec(body);
                        const existing = run.slices.find((s) => s.id === slice.id);
                        const target =
                            existing ??
                            (run.slices.push({
                                id: slice.id,
                                n: slice.n,
                                round: group.number,
                                name: slice.name,
                                kind: null,
                                planned: 'unknown',
                                built: null,
                                green: null,
                                timing: null,
                                probes: [],
                            }),
                            run.slices[run.slices.length - 1]);
                        target.built = m.state;
                        target.green = green ? green[1] : null;
                        target.timing = timing(body);
                        target.red = /^-\s*Red:/im.test(body);
                        if (!target.name && slice.name) target.name = slice.name;
                        // A loom-finish round has no Plan, so Kind lands here instead.
                        if (!target.kind) target.kind = kindOf(m.tail);
                    }
                    break;

                case 'probe':
                    for (const kid of kids.filter((k) => k.depth === group.stageDepth + 1)) {
                        const m = marker(kid.heading);
                        const nested = childrenOf(kids, kids.indexOf(kid));
                        const body = [bodyOf(kid), ...nested.map(bodyOf)].join('\n');
                        const pass = {
                            title: m.title,
                            state: m.state,
                            covers: probeCovers(m.title, group.prefix),
                            findings: findings(body),
                        };
                        run.findings.push(...pass.findings);
                        const slice = run.slices.find((s) => s.id === pass.covers);
                        if (slice) slice.probes.push(pass);
                        else if (pass.covers) notes.push(`probe "${m.title}" names an unknown slice`);
                        else run.deepProbe = pass;
                    }
                    break;

                case 'fixes':
                    // Resolutions are collected document-wide instead, below.
                    break;

                case 'gate': {
                    const verdict = /\bVerdict:\s*(NOT READY|READY)\b/i.exec(whole);
                    run.gate = { verdict: verdict ? verdict[1].toUpperCase() : null, state };
                    if (!verdict && state === 'done') notes.push('gate is done but states no verdict');
                    break;
                }

                case 'land': {
                    const push = /^-\s*Push:\s*(.*)$/im.exec(whole);
                    const merge = /^-\s*Merge:\s*(.*)$/im.exec(whole);
                    run.land = {
                        state,
                        push: push ? push[1].trim() : null,
                        pushed: push ? /^yes\b/i.test(push[1].trim()) : null,
                        merge: merge ? merge[1].trim() : null,
                    };
                    break;
                }

                case 'blockers':
                    run.blockers = bodyOf(section)
                        .split('\n')
                        .filter((l) => /^\s*-\s+\S/.test(l))
                        .map((l) => l.replace(/^\s*-\s+/, '').trim());
                    break;

                default:
                    break;
            }
        }
    }

    sweep(text, all, run);

    run.slices.sort((a, b) => (a.round ?? 0) - (b.round ?? 0) || a.n - b.n);
    run.findings = dedupeFindings(run.findings);
    run.openFindings = run.findings.filter((f) => !run.resolved.has(f.id));
    run.rounds = [...new Set(run.slices.map((s) => s.round))].filter((r) => r !== null);
    return run;
}

/**
 * Which lane a slice card sits in. Read off evidence in the ledger, never prose.
 * Order matters: the first match wins.
 */
export const LANES = ['blocked', 'planned', 'building', 'built', 'probed', 'done'];

export function laneOf(slice, run) {
    if (slice.planned === 'blocked' || slice.built === 'blocked') return 'blocked';
    if (slice.probes.some((p) => p.state === 'blocked')) return 'blocked';
    // A loom-finish round has no Plan, so its slices are described under Slices
    // before anything is built. A pending entry with no red and no commit is still
    // only planned; building means a check has actually been written or run.
    if (slice.built === null) return 'planned';
    if (slice.built === 'pending' && !slice.red && !slice.green) return 'planned';
    if (slice.built !== 'done' || !slice.green) return 'building';

    const passes = slice.probes.filter((p) => p.state === 'done');
    if (!passes.length) return 'built';

    const open = passes
        .flatMap((p) => p.findings)
        .filter((f) => f.severity === 'must-fix' && !run.resolved.has(f.id));
    return open.length ? 'probed' : 'done';
}

/** Open must-fix findings raised by the probe passes that covered this slice. */
export function openFor(slice, run) {
    return slice.probes
        .flatMap((p) => p.findings)
        .filter((f) => !run.resolved.has(f.id));
}

/**
 * The stage the run is at: the first one it actually has that is not done. Stages
 * absent from the ledger are skipped rather than reported as pending, because a
 * patch-lane run has no plan and a feature run has no adopt.
 */
export function currentStage(run) {
    // A landed run is not sitting anywhere. Without this, a Fixes section that
    // never marked its children highlights as "current" on a finished run.
    if (progressOf(run) === 'finished') return null;

    const latest = run.rounds.length ? Math.max(...run.rounds) : null;
    const inRound = Object.entries(run.stages).filter(([, s]) => s.round === latest);
    const scope = inRound.length ? inRound : Object.entries(run.stages);

    const blocked = scope.find(([, s]) => s.state === 'blocked');
    if (blocked) return { key: blocked[0], stage: blocked[1] };

    for (const stage of STAGES) {
        const found = scope.find(([, s]) => s.key === stage.key);
        if (found && found[1].state !== 'done') return { key: found[0], stage: found[1] };
    }
    return null;
}

/** The stage rail for one run: every stage it has, in pipeline order. */
export function rail(run) {
    const latest = run.rounds.length ? Math.max(...run.rounds) : null;
    const inRound = Object.entries(run.stages).filter(([, s]) => s.round === latest);
    const scope = inRound.length ? inRound : Object.entries(run.stages);
    const current = currentStage(run);
    return STAGES.map((stage) => scope.find(([, s]) => s.key === stage.key))
        .filter(Boolean)
        .map(([key, s]) => ({ key, name: s.key, state: s.state, current: current?.key === key }));
}

/** finished | blocked | open. Liveness comes from herdr, not from here. */
export function progressOf(run) {
    if (Object.values(run.stages).some((s) => s.state === 'blocked')) return 'blocked';
    if (run.land?.state === 'done') return 'finished';
    return 'open';
}
