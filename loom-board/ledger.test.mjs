// Parser tests. Run with: node --test loom-board/
//
// The fixtures are small and hand-written, one per drift case the real ledgers
// showed. The last block is a smoke test over whatever real ledgers happen to be
// on this machine, asserting invariants only, so the corpus does not have to be
// copied into this repo to keep catching new drift.

import { strict as assert } from 'node:assert';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, it } from 'node:test';
import { laneOf, openFor, parseLedger, progressOf, rail } from './ledger.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const fixture = (name) =>
    parseLedger(readFileSync(join(here, 'fixtures', name), 'utf8'), {
        slug: name.replace(/\.md$/, ''),
        mtime: new Date(),
    });

const lane = (run, id) => laneOf(run.slices.find((s) => s.id === id), run);
const state = (run, key) => run.stages[key]?.state;

describe('header', () => {
    it('splits the two fields that share a line', () => {
        const run = fixture('flat.md');
        assert.equal(run.title, 'a plain feature run');
        assert.equal(run.lane, 'feature');
        assert.equal(run.mode, 'solo');
        assert.equal(run.branch, 'widgetThing');
        assert.equal(run.worktree, '/home/joeylin/m-code/momentum-widgetThing');
    });
});

describe('stage state', () => {
    it('reads the marker off a heading that has one', () => {
        const run = fixture('flat.md');
        assert.equal(state(run, 'scout'), 'done');
        assert.equal(state(run, 'tidy'), 'done');
        assert.equal(state(run, 'land'), 'done');
    });

    it('derives a container stage from its children, since it carries no marker', () => {
        const run = fixture('flat.md');
        // S1 done, S2 in progress.
        assert.equal(state(run, 'slices'), 'active');
        assert.equal(state(run, 'probe'), 'done');
    });

    it('ignores children that have no marker of their own', () => {
        // Fixes holds one unmarked "Carried to tidy" note and nothing else.
        const run = fixture('misfiled.md');
        assert.equal(state(run, 'fixes'), 'unknown');
    });

    it('never reports an unparsed stage as done', () => {
        const run = parseLedger('# loom: nothing\n\n## Gate\n\nsome prose\n');
        assert.notEqual(state(run, 'gate'), 'done');
        assert.equal(run.gate.verdict, null);
    });
});

describe('slices', () => {
    it('takes the name and kind from Plan and the evidence from Slices', () => {
        const run = fixture('flat.md');
        const s1 = run.slices.find((s) => s.id === 'S1');
        assert.equal(s1.name, 'The widget does the thing');
        assert.equal(s1.kind, 'ui');
        assert.equal(s1.green, 'a1b2c3d4');
        assert.equal(s1.red, true);
    });

    it('reads a commit hash whether or not it is wrapped in backticks', () => {
        assert.equal(fixture('flat.md').slices.find((s) => s.id === 'S1').green, 'a1b2c3d4');
        assert.equal(fixture('rounds.md').slices.find((s) => s.id === 'S1').green, '9f8e7d6c');
    });

    it('puts a planned-but-unbuilt slice in planned, and a started one in building', () => {
        const run = fixture('flat.md');
        assert.equal(lane(run, 'S2'), 'building');
        const rounds = fixture('rounds.md');
        assert.equal(lane(rounds, 'R1.S2'), 'planned');
    });

    it('holds a slice at probed while one of its must-fix findings is open', () => {
        const run = fixture('rounds.md');
        // F2 is raised by R1.P1 and never resolved.
        assert.equal(lane(run, 'R1.S1'), 'probed');
    });

    it('moves a slice to done once its must-fix findings are resolved', () => {
        const run = fixture('flat.md');
        // F1 must-fix is fixed; F2 is polish and does not gate.
        assert.equal(lane(run, 'S1'), 'done');
        assert.deepEqual(
            openFor(run.slices.find((s) => s.id === 'S1'), run)
                .filter((f) => !run.resolved.has(f.id))
                .map((f) => f.id),
            ['F2'],
        );
    });

    it('leaves a slice at built when nothing has probed it yet', () => {
        const run = parseLedger(
            [
                '# loom: unprobed',
                '## Slices',
                '### S1 - [x]',
                '- Green: abc1234 subject',
                '## Probe',
            ].join('\n'),
        );
        assert.equal(lane(run, 'S1'), 'built');
    });
});

describe('findings', () => {
    it('reads a severity tag that is not alone in its brackets', () => {
        const run = fixture('flat.md');
        const byId = Object.fromEntries(run.findings.map((f) => [f.id, f.severity]));
        assert.equal(byId.F1, 'must-fix');
        assert.equal(byId.F2, 'polish'); // "(polish, tidy's call)"
    });

    it('finds a tag that lands on a later line of the same finding', () => {
        const run = parseLedger(
            [
                '# loom: wrapped',
                '## Probe',
                '### P1 (quick, after S1) - [x]',
                '- F1: something long that runs on and on and only then',
                '  admits what it is (must-fix).',
            ].join('\n'),
        );
        assert.equal(run.findings[0].severity, 'must-fix');
    });

    it('counts a finding once when several passes restate it', () => {
        const run = parseLedger(
            [
                '# loom: restated',
                '## Probe',
                '### P1 (quick, after S1) - [x]',
                '- F1: the bug (must-fix).',
                '### P1 re-check (F1) - [x]',
                '- F1: still the bug (must-fix).',
            ].join('\n'),
        );
        assert.equal(run.findings.length, 1);
    });

    it('resolves on "fixed in <hash>", on a bare "fixed", and on "closed by"', () => {
        assert.ok(fixture('flat.md').resolved.has('F1')); // fixed in beef1234
        assert.ok(fixture('misfiled.md').resolved.has('F1')); // "F1: fixed." only
        const closed = parseLedger(
            ['# loom: c', '## Probe', '### P1 - [x]', '- F4: x (polish).', '## Fixes', '- F4: closed by the promoted spec.'].join('\n'),
        );
        assert.ok(closed.resolved.has('F4'));
    });

    it('keeps a deferred finding open', () => {
        const run = parseLedger(
            ['# loom: d', '## Probe', '### P1 - [x]', '- F5: x (must-fix).', '## Fixes', '- F5: deferred - not worth it.'].join('\n'),
        );
        assert.ok(run.deferred.has('F5'));
        assert.ok(!run.resolved.has('F5'));
        assert.deepEqual(run.openFindings.map((f) => f.id), ['F5']);
    });
});

describe('rounds', () => {
    it('prefixes a round\'s slices and keeps them separate from the first pass', () => {
        const run = fixture('rounds.md');
        assert.deepEqual(run.slices.map((s) => s.id), ['S1', 'R1.S1', 'R1.S2']);
        assert.equal(run.slices.find((s) => s.id === 'R1.S2').kind, 'bff');
    });

    it('takes Kind off the Slices heading when the round has no Plan', () => {
        const run = fixture('rounds.md');
        assert.equal(run.slices.find((s) => s.id === 'R1.S1').kind, 'ui');
    });

    it('rails the latest round, not the finished first pass', () => {
        const run = fixture('rounds.md');
        const names = rail(run).map((s) => s.name);
        assert.ok(names.includes('adopt'));
        assert.ok(names.includes('reconcile'));
        assert.equal(progressOf(run), 'open');
    });
});

describe('gate and land', () => {
    it('finds a verdict written as prose after a table', () => {
        assert.equal(fixture('flat.md').gate.verdict, 'READY');
    });

    it('reads whether the branch was pushed', () => {
        assert.equal(fixture('flat.md').land.pushed, true);
        const solo = parseLedger(
            ['# loom: s', '## Land - [x]', '- Push: local only. Solo mode never pushes.'].join('\n'),
        );
        assert.equal(solo.land.pushed, false);
    });

    it('reports the latest round\'s land, not a finished earlier one', () => {
        // rounds.md landed its first pass and is mid-way through round 1, so the
        // run has not pushed anything for the work it is doing now.
        const run = fixture('rounds.md');
        assert.equal(run.land.state, 'pending');
        assert.equal(run.land.pushed, null);
    });

    it('highlights no current stage on a finished run', () => {
        // An unmarked Fixes section otherwise reads as the stage the run sits at,
        // long after it landed.
        assert.equal(rail(fixture('misfiled.md')).some((s) => s.current), false);
        assert.equal(rail(fixture('flat.md')).some((s) => s.current), false);
        assert.equal(rail(fixture('rounds.md')).some((s) => s.current), true);
    });

    it('calls a run finished only once land is done', () => {
        assert.equal(progressOf(fixture('flat.md')), 'finished');
        assert.equal(progressOf(fixture('rounds.md')), 'open');
    });
});

describe('misfiled content', () => {
    it('finds a slice recorded outside the Slices section, and says so', () => {
        const run = fixture('misfiled.md');
        const s2 = run.slices.find((s) => s.id === 'S2');
        assert.ok(s2, 'S2 was filed under Blockers and must still be found');
        assert.equal(s2.misfiled, true);
        assert.match(run.notes.join(' '), /S2 recorded outside the Slices section/);
    });

    it('honours a fix recorded outside the Fixes section', () => {
        assert.ok(fixture('misfiled.md').resolved.has('F1'));
    });
});

// A run whose ledger is only a title must not throw, and must claim nothing.
describe('degenerate input', () => {
    it('survives an empty ledger', () => {
        const run = parseLedger('');
        assert.deepEqual(run.slices, []);
        assert.equal(progressOf(run), 'open');
        assert.equal(rail(run).length, 0);
    });
});

// Invariants over the real ledgers on this machine, if there are any. This is what
// catches drift the fixtures have not learned about yet.
describe('real ledgers on this machine', () => {
    const root = process.env.MOMENTUM_ROOT ?? join(process.env.HOME ?? '', 'm-code');
    const found = [];
    if (existsSync(root)) {
        for (const dir of readdirSync(root).filter((d) => d.startsWith('momentum'))) {
            const ledgers = join(root, dir, 'src', 'ui-app', 'logs', 'loom');
            if (!existsSync(ledgers)) continue;
            for (const name of readdirSync(ledgers)) {
                if (name.endsWith('.md') && !name.endsWith('-report.md')) {
                    found.push(join(ledgers, name));
                }
            }
        }
    }

    it(`parses all ${found.length} of them without throwing`, { skip: !found.length }, () => {
        for (const path of found) {
            const run = parseLedger(readFileSync(path, 'utf8'), { slug: path, mtime: new Date() });
            assert.ok(run.slices.length > 0, `${path} yielded no slices`);
            for (const slice of run.slices) assert.ok(laneOf(slice, run), `${slice.id} has no lane`);
            const unknown = run.findings.filter((f) => f.severity === 'unknown');
            assert.deepEqual(
                unknown.map((f) => f.id),
                [],
                `${path} has findings with no severity, so the tag format has drifted`,
            );
        }
    });
});
