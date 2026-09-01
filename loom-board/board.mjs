#!/usr/bin/env node
// loom board: every momentum worktree, its live agent, and what its loom runs are
// doing, read from the flight ledgers. Read-only. See README.md.

import { execFile } from 'node:child_process';
import { readdir, readFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { basename, join } from 'node:path';
import { parseArgs } from 'node:util';
import { promisify } from 'node:util';
import {
    LANES,
    laneOf,
    openFor,
    parseLedger,
    progressOf,
    rail,
} from './ledger.mjs';

const run = promisify(execFile);
const ROOT = process.env.MOMENTUM_ROOT ?? join(process.env.HOME ?? '', 'm-code');
const MAIN = join(ROOT, 'momentum');
const LEDGER_DIR = join('src', 'ui-app', 'logs', 'loom');
const STALE_HOURS = 24;

/** Never let one slow or broken command take the board down. */
async function tryRun(cmd, args, opts = {}) {
    try {
        const { stdout } = await run(cmd, args, { timeout: 5000, maxBuffer: 8e6, ...opts });
        return stdout;
    } catch {
        return null;
    }
}

// ---------------------------------------------------------------- collectors

async function collectWorktrees() {
    const out = await tryRun('git', ['-C', MAIN, 'worktree', 'list', '--porcelain']);
    if (out === null) return [];
    const trees = [];
    let current = null;
    for (const line of out.split('\n')) {
        if (line.startsWith('worktree ')) {
            current = { path: line.slice(9).trim(), branch: null, prunable: false };
            trees.push(current);
        } else if (!current) continue;
        else if (line.startsWith('branch ')) current.branch = line.slice(7).replace('refs/heads/', '');
        else if (line.startsWith('prunable ')) current.prunable = true;
        else if (line === 'bare') current.bare = true;
    }
    return trees.filter((t) => !t.bare).map((t) => ({ ...t, name: basename(t.path), exists: existsSync(t.path) }));
}

async function collectGit(tree) {
    if (!tree.exists) return null;
    const [status, counts, last] = await Promise.all([
        tryRun('git', ['-C', tree.path, 'status', '--porcelain']),
        tryRun('git', ['-C', tree.path, 'rev-list', '--left-right', '--count', 'origin/main...HEAD']),
        tryRun('git', ['-C', tree.path, 'log', '-1', '--format=%h%x00%s%x00%cr']),
    ]);
    const [behind, ahead] = (counts ?? '').trim().split(/\s+/).map(Number);
    const [hash, subject, when] = (last ?? '').trim().split('\0');
    return {
        dirty: status === null ? null : status.split('\n').filter(Boolean).length,
        ahead: Number.isFinite(ahead) ? ahead : null,
        behind: Number.isFinite(behind) ? behind : null,
        last: hash ? { hash, subject, when } : null,
    };
}

/** herdr already answers in JSON. A missing herdr is not an error, just no column. */
async function collectAgents() {
    const out = await tryRun('herdr', ['agent', 'list']);
    if (out === null) return [];
    try {
        return JSON.parse(out).result?.agents ?? [];
    } catch {
        return [];
    }
}

async function collectRuns(tree) {
    if (!tree.exists) return [];
    const dir = join(tree.path, LEDGER_DIR);
    let names;
    try {
        names = await readdir(dir);
    } catch {
        return [];
    }
    const ledgers = names.filter((n) => n.endsWith('.md') && !n.endsWith('-report.md'));
    return Promise.all(
        ledgers.map(async (name) => {
            const path = join(dir, name);
            const [text, info] = await Promise.all([readFile(path, 'utf8'), stat(path)]);
            const slug = name.replace(/\.md$/, '');
            return parseLedger(text, {
                slug,
                path,
                mtime: info.mtime,
                report: existsSync(join(dir, `${slug}-report.md`)),
            });
        }),
    );
}

/**
 * live     an agent is working in this worktree
 * waiting  an agent is there but idle or blocked, and the run is unfinished
 * finished land is done
 * stalled  unfinished, nobody on it, and untouched for a day
 */
function classify(run, agents) {
    const progress = progressOf(run);
    if (progress === 'finished') return 'finished';
    const working = agents.some((a) => a.agent_status === 'working');
    if (working) return 'live';
    if (agents.length) return 'waiting';
    const hours = (Date.now() - run.mtime.getTime()) / 3.6e6;
    return hours > STALE_HOURS ? 'stalled' : 'waiting';
}

export async function collect() {
    const [trees, agents] = await Promise.all([collectWorktrees(), collectAgents()]);
    const worktrees = await Promise.all(
        trees.map(async (tree) => {
            const [git, runs] = await Promise.all([collectGit(tree), collectRuns(tree)]);
            const mine = agents.filter((a) => (a.foreground_cwd ?? a.cwd) === tree.path);
            for (const r of runs) r.status = classify(r, mine);
            runs.sort((a, b) => b.mtime - a.mtime);
            return { ...tree, git, agents: mine, runs };
        }),
    );
    // Worktrees with live work first, then any other run, then the bare ones.
    const rank = (w) =>
        w.runs.some((r) => r.status === 'live') ? 0 : w.runs.length ? 1 : w.exists ? 2 : 3;
    worktrees.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
    return { root: ROOT, worktrees, agents };
}

// ----------------------------------------------------------------- rendering

const useColor = process.stdout.isTTY && !process.env.NO_COLOR;
const paint = (code) => (s) => (useColor ? `[${code}m${s}[0m` : s);
const dim = paint('2');
const bold = paint('1');
const green = paint('32');
const yellow = paint('33');
const red = paint('31');
const cyan = paint('36');
const magenta = paint('35');

const AGENT_COLOR = { working: green, blocked: red, idle: dim, done: cyan };
const STATE_COLOR = { done: green, active: bold, blocked: red, pending: dim, unknown: dim };
const RUN_COLOR = { live: green, waiting: yellow, finished: dim, stalled: dim };

/** Each lane owns a colour, so a card says where it is without reading the header. */
const LANE_COLOR = {
    blocked: red,
    planned: dim,
    building: yellow,
    built: cyan,
    probed: magenta,
    done: green,
};

const width = () => Math.max(60, process.stdout.columns || 100);
const clip = (s, n) => (s.length <= n ? s : `${s.slice(0, Math.max(0, n - 1))}.`);
/** padEnd on a coloured string counts the escape bytes, so pad before painting. */
const cell = (s, n, colour) => {
    const text = clip(String(s ?? ''), n).padEnd(n);
    return colour ? colour(text) : text;
};

function renderRail(run) {
    return rail(run)
        .map((s) => {
            const label = s.current ? s.name.toUpperCase() : s.name;
            return (STATE_COLOR[s.state] ?? dim)(label);
        })
        .join('  ');
}

function renderLanes(run, indent) {
    const cards = new Map(LANES.map((l) => [l, []]));
    for (const slice of run.slices) {
        const open = openFor(slice, run).filter((f) => !run.resolved.has(f.id));
        const mustFix = open.filter((f) => f.severity === 'must-fix').length;
        const name = slice.name ? `${slice.id} ${slice.name}` : slice.id;
        const lane = laneOf(slice, run);
        cards.get(lane).push({
            name,
            mustFix,
            took: brief(slice.timing?.seconds),
            // The ledger path pins the run, so a card keeps its identity across redraws.
            key: `${run.path}\u0000${slice.id}`,
            slice,
            run,
            lane,
            open,
        });
    }
    // Blocked only earns a column when something is in it.
    const lanes = LANES.filter((l) => l !== 'blocked' || cards.get(l).length);
    const heads = lanes.map((l) => `${l} ${cards.get(l).length}`);

    // Every lane the same width. A busy lane clips sooner than it would if the
    // width were shared out by need, but the grid holds still between redraws.
    const available = width() - indent - RULE.length * (lanes.length - 1);
    const column = Math.max(9, Math.floor(available / lanes.length));

    const pad = ' '.repeat(indent);
    const bar = dim(RULE);
    const rule = (joint) => pad + dim(lanes.map(() => '\u2500'.repeat(column)).join(joint));
    const head = (l, i) => {
        const text = clip(heads[i], column);
        return (LANE_COLOR[l] ?? dim)(bold(i === lanes.length - 1 ? text : text.padEnd(column)));
    };

    const lines = [pad + lanes.map(head).join(bar), rule('\u2500\u253c\u2500')];
    const spans = [];

    const depth = Math.max(...lanes.map((l) => cards.get(l).length), 1);
    for (let row = 0; row < depth; row++) {
        const boxes = lanes.map((lane) => renderCard(cards.get(lane)[row], column, lane));
        lanes.forEach((lane, i) => {
            const card = cards.get(lane)[row];
            if (!card) return;
            const from = indent + i * (column + RULE.length);
            for (let line = 0; line < CARD_HEIGHT; line++) {
                spans.push({ row: lines.length + line, from, to: from + column, card });
            }
        });
        for (let line = 0; line < CARD_HEIGHT; line++) {
            lines.push(pad + boxes.map((b) => b[line]).join(bar));
        }
    }
    lines.push(rule('\u2500\u2534\u2500'));
    return { lines, spans };
}

/** The gutter between two lanes: a vertical rule the height of the board. */
const RULE = ' \u2502 ';
/** A card's border and the space inside it: "| " on the left, " |" on the right. */
const CARD_FRAME = 4;
const CARD_HEIGHT = 3;

/**
 * One slice as a bordered card in its lane's colour, or an empty slot of the same
 * height. Painted after padding, so the escape bytes never count towards a width.
 */
function renderCard(card, w, lane) {
    const colour = LANE_COLOR[lane] ?? dim;
    if (!card) return Array(CARD_HEIGHT).fill(' '.repeat(w));
    const full = suffixOf(card);
    const suffix = w - CARD_FRAME - full.length >= 1 ? full : '';
    const inner = w - CARD_FRAME - suffix.length;
    const name = clip(card.name, inner).padEnd(inner);
    const tail = suffix ? (card.mustFix ? yellow : dim)(suffix) : '';
    return [
        colour(`\u256d${'\u2500'.repeat(w - 2)}\u256e`),
        `${colour('\u2502')} ${name}${tail} ${colour('\u2502')}`,
        colour(`\u2570${'\u2500'.repeat(w - 2)}\u256f`),
    ];
}

/** What a card carries after its name: how long the slice took, then its open must-fixes. */
function suffixOf(card) {
    return `${card.took ? ` ${card.took}` : ''}${card.mustFix ? ` (${card.mustFix})` : ''}`;
}

function renderRun(run, indent = 2) {
    const pad = ' '.repeat(indent);
    const lines = [];
    const head = run.title ?? run.slug;
    const tag = RUN_COLOR[run.status] ?? dim;
    lines.push(`${pad}${bold(head)}  ${tag(`[${run.status}]`)}  ${dim(`${run.lane ?? '?'} ${run.mode ?? ''}`.trim())}`);
    lines.push(`${pad}${renderRail(run)}`);
    const lanes = renderLanes(run, indent);
    const spans = lanes.spans.map((s) => ({ ...s, row: s.row + lines.length }));
    lines.push(...lanes.lines);

    const trailer = [];
    if (run.gate.verdict) {
        trailer.push(run.gate.verdict === 'READY' ? green('gate READY') : red('gate NOT READY'));
    }
    if (run.land?.state === 'done') trailer.push(run.land.pushed ? 'pushed' : 'not pushed');
    const openMustFix = run.openFindings.filter((f) => f.severity === 'must-fix').length;
    const openPolish = run.openFindings.filter((f) => f.severity !== 'must-fix').length;
    if (openMustFix) trailer.push(yellow(`${openMustFix} must-fix open`));
    if (openPolish) trailer.push(dim(`${openPolish} polish open`));
    if (run.blockers?.length) trailer.push(red(`${run.blockers.length} blockers`));
    if (trailer.length) lines.push(`${pad}${trailer.join(dim('  |  '))}`);
    for (const note of run.notes) lines.push(`${pad}${dim(`note: ${note}`)}`);
    return { lines, spans };
}

function renderWorktree(tree, opts) {
    const lines = [];
    const spans = [];
    const agent = tree.agents[0];
    const status = agent ? (AGENT_COLOR[agent.agent_status] ?? dim)(agent.agent_status) : dim('-');
    const g = tree.git;
    const position = !g
        ? dim('missing')
        : [
              g.ahead !== null ? `+${g.ahead}/-${g.behind}` : '',
              g.dirty === null ? '' : g.dirty ? yellow(`${g.dirty} dirty`) : dim('clean'),
          ]
              .filter(Boolean)
              .join('  ');

    lines.push(
        [
            bold(cell(tree.name, 32)),
            cell(tree.branch ?? 'detached', 24, cyan),
            status,
            position,
            tree.prunable ? red('prunable') : '',
        ]
            .filter(Boolean)
            .join('  ')
            .trimEnd(),
    );

    // The title Claude writes into the terminal is the only thing that tells
    // several parallel runs apart at a glance.
    if (agent?.terminal_title_stripped) lines.push(`  ${dim(agent.terminal_title_stripped)}`);

    const active = tree.runs.filter((r) => r.status === 'live' || r.status === 'waiting');
    const rest = tree.runs.filter((r) => !active.includes(r));
    const shown = opts.all ? tree.runs : active;

    if (!tree.runs.length) lines.push(`  ${dim('no loom run')}`);
    for (const r of shown) {
        lines.push('');
        const rendered = renderRun(r);
        for (const span of rendered.spans) {
            span.card.tree = tree.name;
            spans.push({ ...span, row: span.row + lines.length });
        }
        lines.push(...rendered.lines);
    }
    if (!opts.all && rest.length) {
        const summary = rest
            .map((r) => {
                const bits = [r.status];
                if (r.gate.verdict) bits.push(r.gate.verdict);
                if (r.land?.state === 'done') bits.push(r.land.pushed ? 'pushed' : 'not pushed');
                return `${r.slug} (${bits.join(', ')}, ${ago(r.mtime)})`;
            })
            .join('; ');
        lines.push(`  ${dim(`inactive: ${summary}`)}`);
    }
    return { lines, spans };
}

/**
 * A slice's timing, read back the way the ledger wrote it. Clock times are taken
 * literally out of the stamp rather than through Date, so the board shows the
 * wall clock the run was actually on, not this machine's.
 */
function stamps(timing) {
    if (!timing) return null;
    const clock = (iso) => /[T ](\d{2}:\d{2})/.exec(iso ?? '')?.[1] ?? null;
    const from = clock(timing.started);
    const to = clock(timing.finished);
    const day = (timing.started ?? timing.finished)?.slice(5, 10) ?? null;
    // A stamp with no clock time in it is a date, so say the day and stop.
    const span = from || to ? `${day} ${from ?? '?'}-${to ?? '?'}` : day;
    return [span, timing.took ?? hhmmss(timing.seconds)].filter(Boolean).join('  ') || null;
}

function hhmmss(seconds) {
    if (seconds === null || seconds === undefined) return null;
    const parts = [Math.floor(seconds / 3600), Math.floor((seconds % 3600) / 60), seconds % 60];
    return parts.map((n) => String(n).padStart(2, '0')).join(':');
}

/** The same duration short enough for a kanban card: 45s, 8m, 1h02. */
function brief(seconds) {
    if (seconds === null || seconds === undefined) return null;
    if (seconds < 60) return `${seconds}s`;
    const minutes = Math.round(seconds / 60);
    if (minutes < 60) return `${minutes}m`;
    return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, '0')}`;
}

function ago(date) {
    const hours = (Date.now() - date.getTime()) / 3.6e6;
    if (hours < 1) return `${Math.round(hours * 60)}m ago`;
    if (hours < 48) return `${Math.round(hours)}h ago`;
    return `${Math.round(hours / 24)}d ago`;
}

function renderBoard(model, opts) {
    const runs = model.worktrees.flatMap((w) => w.runs);
    const live = runs.filter((r) => r.status === 'live').length;
    const counts = `${model.worktrees.length} worktrees, ${runs.length} runs, ${live} live`;
    const out = [`${bold('loom board')}  ${dim(counts)}`, ''];
    const spans = [];
    for (const tree of model.worktrees) {
        if (opts.run && !tree.runs.some((r) => r.slug === opts.run)) continue;
        const rendered = renderWorktree(tree, opts);
        for (const span of rendered.spans) spans.push({ ...span, row: span.row + out.length });
        out.push(...rendered.lines, '');
    }
    if (!model.agents.length) out.push(dim('herdr reported no agents. Is the server running?'), '');
    return { lines: out, spans };
}

/**
 * What a click on a card opens: that one slice, its evidence, and what is still
 * open on it. The card only has room for a name, so this is where the rest goes.
 */
function renderPanel(card, w) {
    const { slice, run, lane } = card;
    // Every line is measured before it is painted: one that ran past the pane
    // would wrap, and a wrapped line pushes the whole frame down.
    const lead = [slice.id, lane, slice.kind].filter(Boolean).join('  ');
    const where = clip(`${card.tree ?? ''}  ${run.title ?? run.slug}`.trim(), Math.floor(w / 3));
    const name = clip(slice.name ?? '(unnamed)', Math.max(0, w - lead.length - where.length - 4));
    const evidence = [
        stamps(slice.timing) ?? 'no timing',
        slice.red ? 'red first' : 'no red record',
        slice.green ? `green ${slice.green}` : 'no commit',
        `${slice.probes.length} probe pass${slice.probes.length === 1 ? '' : 'es'}`,
    ].join('  |  ');
    const head = `${bold(slice.id)}  ${(LANE_COLOR[lane] ?? dim)(lane)}${slice.kind ? `  ${slice.kind}` : ''}`;
    const lines = [
        dim('\u2500'.repeat(w)),
        `${head}  ${name}  ${dim(where)}`,
        dim(clip(evidence, w)),
    ];
    for (const f of card.open.slice(0, PANEL_FINDINGS)) {
        const label = `${f.id} ${f.severity}`;
        const colour = f.severity === 'must-fix' ? yellow : dim;
        lines.push(`${colour(label)} ${clip(f.summary, Math.max(0, w - label.length - 1))}`);
    }
    if (!card.open.length) lines.push(dim('nothing open on this slice'));
    const more = card.open.length - PANEL_FINDINGS;
    if (more > 0) lines.push(dim(`${more} more open`));
    lines.push(dim(clip(`esc closes.  m-board --run ${run.slug} for the whole run.`, w)));
    return lines;
}

/** A panel eats board rows, so it shows the first few findings and points at --run. */
const PANEL_FINDINGS = 4;

/** One run in full: every slice with its evidence, and every open finding. */
function renderDetail(model, slug) {
    const tree = model.worktrees.find((w) => w.runs.some((r) => r.slug === slug));
    if (!tree) return `no loom run called "${slug}"`;
    const run = tree.runs.find((r) => r.slug === slug);
    const out = [
        `${bold(run.title ?? slug)}  ${dim(`${tree.name} on ${tree.branch}`)}`,
        run.request ? dim(clip(run.request, width() - 2)) : '',
        '',
        renderRail(run),
        '',
    ];
    for (const slice of run.slices) {
        const open = openFor(slice, run).filter((f) => !run.resolved.has(f.id));
        out.push(
            `${cell(slice.id, 8, bold)}${cell(laneOf(slice, run), 10, LANE_COLOR[laneOf(slice, run)])}${cell(slice.kind ?? '-', 5)}${slice.name ?? ''}`,
        );
        const evidence = [
            stamps(slice.timing) ?? dim('no timing'),
            slice.red ? 'red first' : dim('no red record'),
            slice.green ? `green ${slice.green}` : dim('no commit'),
            `${slice.probes.length} probe pass${slice.probes.length === 1 ? '' : 'es'}`,
        ];
        out.push(`        ${dim(evidence.join('  |  '))}`);
        for (const f of open) {
            const colour = f.severity === 'must-fix' ? yellow : dim;
            out.push(`        ${colour(`${f.id} ${f.severity}`)} ${clip(f.summary, width() - 30)}`);
        }
    }
    if (run.notes.length) out.push('', ...run.notes.map((n) => dim(`note: ${n}`)));
    return out.join('\n');
}

// ---------------------------------------------------------------------- main

const { values } = parseArgs({
    options: {
        all: { type: 'boolean', default: false },
        json: { type: 'boolean', default: false },
        run: { type: 'string' },
        watch: { type: 'boolean', default: false },
        interval: { type: 'string', default: '5' },
        help: { type: 'boolean', short: 'h', default: false },
    },
    allowPositionals: false,
});

if (values.help) {
    console.log(
        [
            'm-board [--all] [--run <slug>] [--watch] [--json]',
            '',
            '  --all           expand finished and stalled runs too',
            '  --run <slug>    one run in full, with every slice and open finding',
            '  --watch         redraw until you close it (ctrl+c), click a card for a quick look',
            '  --interval <n>  seconds between redraws, default 5',
            '  --json          the whole model, for another renderer',
            '',
            `reads ${ROOT}/momentum* and herdr agent list. Writes nothing.`,
        ].join('\n'),
    );
    process.exit(0);
}

async function draw() {
    const model = await collect();
    if (values.json) {
        const json = JSON.stringify(model, (_key, value) => (value instanceof Set ? [...value] : value), 2);
        return { lines: json.split('\n'), spans: [] };
    }
    if (values.run) return { lines: renderDetail(model, values.run).split('\n'), spans: [] };
    return renderBoard(model, values);
}

if (!values.watch) {
    console.log((await draw()).lines.join('\n'));
} else {
    const seconds = Math.max(1, Number(values.interval) || 5);
    const interactive = process.stdin.isTTY;
    const write = (s) => process.stdout.write(s);
    // The alternate screen has no scrollback, so a redraw replaces the last frame
    // instead of pushing it up. It also takes the pane's scrollbar away, so the
    // board has to do its own scrolling from here.
    // SGR mouse reporting (1006) rather than the 223-column X10 encoding, so a
    // click still lands on the right card on a wide screen. It takes the
    // terminal's own text selection away; hold shift to get it back.
    const restore = () => {
        if (interactive) process.stdin.setRawMode(false);
        write(`${interactive ? '\x1b[?1006l\x1b[?1000l' : ''}\x1b[?25h\x1b[?1049l`);
    };
    write(`\x1b[?1049h\x1b[?25l${interactive ? '\x1b[?1000h\x1b[?1006h' : ''}`);
    process.on('exit', restore);
    for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, () => process.exit(0));

    let lines = [];
    let spans = [];
    let top = 0;
    let left = 0;
    // The card a click opened, and its key, so a redraw can find it again.
    let card = null;
    let picked = null;
    let panel = [];
    let visible = 0;
    const viewport = () => Math.max(3, (process.stdout.rows || 40) - 1 - panel.length);
    const maxTop = () => Math.max(0, lines.length - viewport());
    const pane = () => Math.max(20, process.stdout.columns || 100);
    /** Colour bytes take no columns, so measure and cut around them, not through them. */
    const SGR = /(\x1b\[[0-9;]*m)/;
    const parts = (line) => line.split(SGR).map((part) => ({ text: part, wide: !SGR.test(part) }));
    const columns = (line) => parts(line).reduce((n, part) => n + (part.wide ? part.text.length : 0), 0);
    const maxLeft = () => Math.max(0, Math.max(0, ...lines.map(columns)) - pane());
    /** The columns [from, from + count) of one line, with its colour codes kept. */
    const window = (line, from, count) => {
        let out = '';
        let seen = 0;
        for (const part of parts(line)) {
            if (!part.wide) {
                out += part.text;
                continue;
            }
            const start = Math.min(part.text.length, Math.max(0, from - seen));
            const end = Math.min(part.text.length, Math.max(0, from + count - seen));
            out += part.text.slice(start, end);
            seen += part.text.length;
        }
        return seen > from + count ? `${out}\x1b[0m` : out;
    };

    /** Home, then erase-to-end-of-line per row, so a redraw does not flicker. */
    const renderFrame = () => {
        panel = card ? renderPanel(card, pane()) : [];
        top = Math.max(0, Math.min(top, maxTop()));
        left = Math.max(0, Math.min(left, maxLeft()));
        const shown = lines.slice(top, top + viewport()).map((line) => window(line, left, pane()));
        visible = shown.length;
        const last = Math.min(lines.length, top + viewport());
        const where = maxTop() ? `  ${top + 1}-${last} of ${lines.length}` : '';
        const column = maxLeft() ? `  col ${left + 1}` : '';
        const how = (maxTop() || maxLeft()) && interactive ? '  hjkl pgup/pgdn g/G scroll' : '';
        const pick = interactive && !card && spans.length ? '  click a card' : '';
        const footer = clip(`refreshing every ${seconds}s.${where}${column}${how}${pick}  q closes.`, pane());
        const frame = [...shown, ...panel, dim(footer)];
        write(`\x1b[H${frame.map((line) => `${line}\x1b[K`).join('\n')}\x1b[J`);
    };

    if (interactive) {
        process.stdin.setRawMode(true);
        process.stdin.resume();
        process.stdin.setEncoding('utf8');
        // One read can carry several keypresses, so split it back into keys: a CSI
        // sequence, then a bare escape pair, then any single character.
        const KEYS = /\x1b\[<[0-9;]*[Mm]|\x1b\[[0-9;]*[A-Za-z~]|\x1b.|[\s\S]/g;
        // "\x1b[<button;column;rowM" on press, "m" on release, all 1-based.
        const MOUSE = /^\x1b\[<(\d+);(\d+);(\d+)([Mm])$/;
        const WHEEL_ROWS = 3;
        process.stdin.on('data', (chunk) => {
            let moved = false;
            for (const key of chunk.match(KEYS) ?? []) {
                // Raw mode swallows SIGINT, so ctrl+c arrives as a byte like any other.
                if (key === '\x03' || key === 'q') process.exit(0);
                const click = MOUSE.exec(key);
                if (click) {
                    const button = Number(click[1]);
                    // The wheel reports as a button, and reporting took it off the
                    // pane, so the board has to scroll on it itself.
                    if (button === 64 || button === 65) {
                        top += button === 64 ? -WHEEL_ROWS : WHEEL_ROWS;
                        moved = true;
                        continue;
                    }
                    // Left press only. Modifier bits sit above the low two.
                    if (click[4] !== 'M' || (button & 3) !== 0) continue;
                    const y = Number(click[3]);
                    const row = top + y - 1;
                    const column = left + Number(click[2]) - 1;
                    const hit =
                        y <= visible &&
                        spans.find((s) => s.row === row && column >= s.from && column < s.to);
                    // A click anywhere else, the panel included, puts the panel away.
                    card = hit ? hit.card : null;
                    picked = card?.key ?? null;
                    moved = true;
                    continue;
                }
                if (key === '\x1b' && card) {
                    card = null;
                    picked = null;
                    moved = true;
                    continue;
                }
                const page = Math.max(1, viewport() - 1);
                const rowStep = {
                    '\x1b[A': -1, k: -1,
                    '\x1b[B': 1, j: 1,
                    '\x1b[5~': -page, b: -page,
                    '\x1b[6~': page, ' ': page,
                    '\x1b[H': -Infinity, '\x1b[1~': -Infinity, g: -Infinity,
                    '\x1b[F': Infinity, '\x1b[4~': Infinity, G: Infinity,
                }[key];
                // Four columns a press: one is too slow to cross a padded column.
                const columnStep = {
                    '\x1b[D': -4, h: -4,
                    '\x1b[C': 4, l: 4,
                    0: -Infinity,
                    $: Infinity,
                }[key];
                if (rowStep === undefined && columnStep === undefined) continue;
                top += rowStep ?? 0;
                left += columnStep ?? 0;
                moved = true;
            }
            if (moved) renderFrame();
        });
    }
    process.stdout.on('resize', renderFrame);

    for (;;) {
        ({ lines, spans } = await draw());
        // A slice that changed lane moved to a new card object; one that vanished
        // from the ledger takes its panel with it.
        card = picked ? (spans.find((s) => s.card.key === picked)?.card ?? null) : null;
        if (!card) picked = null;
        renderFrame();
        await new Promise((resolve) => setTimeout(resolve, seconds * 1000));
    }
}
