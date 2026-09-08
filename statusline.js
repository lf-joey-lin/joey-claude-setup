#!/usr/bin/env node
// Claude Code custom status line. Reads the status JSON on stdin, prints the segments
// packed into as many lines as the terminal is wide enough for.
// Docs: https://code.claude.com/docs/en/statusline.md
// Each segment is independent — delete a `push(...)` block to remove that segment.

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// --- ANSI helpers -----------------------------------------------------------
const c = (code, s) => `\x1b[${code}m${s}\x1b[0m`;
// ANSI 2 (faint) is unreadable on a dark theme, so label text is bright white and
// only the separator is toned down, to grey rather than faint.
const label = (s) => c("97", s);
const grey = (s) => c("90", s);
const bold = (s) => c("1", s);
const green = (s) => c("32", s);
const yellow = (s) => c("33", s);
const red = (s) => c("31", s);
const cyan = (s) => c("36", s);
const blue = (s) => c("34", s);
const magenta = (s) => c("35", s);
const SEP = grey("  │  ");

// --- width -------------------------------------------------------------------
// Claude Code renders every status line with ink's wrap="truncate", so an
// over-long line is clipped, never wrapped. It hands us the live terminal size
// in COLUMNS (stdout is a pipe here, so process.stdout.columns is undefined).
const ANSI = /\x1b\[[\d;]*m/g;
const vlen = (s) => s.replace(ANSI, "").length;

function usableWidth() {
  const cols = parseInt(process.env.COLUMNS, 10);
  if (!Number.isFinite(cols) || cols <= 0) return Infinity; // run outside Claude Code
  const padding = 0; // keep in sync with statusLine.padding in settings.json
  return Math.max(20, cols - padding * 2 - 1);
}

// Greedily pack segments into lines that fit. Every segment ends in a reset, so
// the color state Claude Code carries across lines stays neutral.
function pack(parts, width) {
  const lines = [];
  let line = null;
  let used = 0;
  for (const p of parts) {
    const w = vlen(p);
    if (line === null) { line = p; used = w; continue; }
    if (used + vlen(SEP) + w <= width) { line += SEP + p; used += vlen(SEP) + w; }
    else { lines.push(line); line = p; used = w; }
  }
  if (line !== null) lines.push(line);
  return lines.join("\n");
}

// --- read stdin -------------------------------------------------------------
let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (d) => (raw += d));
process.stdin.on("end", () => {
  let j = {};
  try { j = JSON.parse(raw); } catch { /* print what we can */ }
  try { process.stdout.write(render(j)); }
  catch (e) { process.stdout.write(red("statusline error: " + e.message)); }
});

// --- render -----------------------------------------------------------------
function render(j) {
  const parts = [];

  // 1) Current directory (basename)
  const dir = j?.workspace?.current_dir || j?.cwd;
  if (dir) parts.push("📁 " + cyan(path.basename(dir)));

  // 2) Git branch + dirty flag (cached-free; git in the cwd is fast enough)
  const git = gitInfo(dir);
  if (git) parts.push("⎇ " + git);

  // 3) Model + effort level
  const model = j?.model?.display_name;
  if (model) {
    let m = bold(model);
    const effort = j?.effort?.level;
    if (effort) m += label(" ·" + effort);
    parts.push(m);
  }

  // 4) Context-window usage bar (the headline metric)
  const ctx = contextBar(j?.context_window);
  if (ctx) parts.push(ctx);

  // 5) Rate-limit windows (only present on some plans; hidden otherwise)
  const rl = rateLimits(j?.rate_limits);
  if (rl) parts.push(rl);

  // 6) System memory
  const mem = memInfo();
  if (mem) parts.push(mem);

  // 7) Wedged .NET toolchain (silent unless something really is stuck)
  const wedge = buildWedge();
  if (wedge) parts.push(wedge);

  return pack(parts, usableWidth());
}

// A stopped process holding a NuGet lock blocks every `dotnet restore` on the
// box, in every worktree, and nothing anywhere says so - `make dev` just hangs.
// `m-doctor` (shell/momentum.sh) diagnoses and clears it; this is the nudge to
// run it, because otherwise you find out by waiting.
//
// Two tiers, so an idle box pays almost nothing. Tier 1 is a fork-free /proc
// pass, about 2ms, and on a healthy machine finds no stopped process at all and
// stops there. Only when something IS stopped does it shell out to confirm the
// process actually holds a lock, and that answer is cached for 15s so a
// long-suspended job (a Ctrl+Z'd editor, say) cannot make every redraw pay for
// the sweep.
function buildWedge() {
  let entries;
  try { entries = fs.readdirSync("/proc"); } catch { return null; } // not Linux

  let stopped = false;
  for (const e of entries) {
    const c0 = e.charCodeAt(0);
    if (c0 < 48 || c0 > 57) continue;
    let stat;
    try { stat = fs.readFileSync("/proc/" + e + "/stat", "utf8"); } catch { continue; }
    // The state field sits after the comm, which is parenthesised and may itself
    // contain spaces - so read past the last ") " rather than splitting on space.
    const i = stat.lastIndexOf(") ");
    if (i >= 0 && stat[i + 2] === "T") { stopped = true; break; }
  }
  if (!stopped) return null;

  const cache = (process.env.TMPDIR || "/tmp") + "/m-doctor-sniff." + (process.getuid ? process.getuid() : "u");
  let out = null;
  try {
    if (Date.now() - fs.statSync(cache).mtimeMs < 15000) out = fs.readFileSync(cache, "utf8").trim();
  } catch { /* no cache yet, or unreadable */ }

  if (out === null) {
    // Non-zero exit is m-doctor saying there is nothing wrong, and is also what a
    // box without m-doctor on PATH does. Both mean: say nothing.
    try {
      out = execSync("m-doctor --sniff", {
        stdio: ["ignore", "pipe", "ignore"], encoding: "utf8", timeout: 3000,
      }).trim();
    } catch { out = ""; }
    try { fs.writeFileSync(cache, out); } catch { /* the cache is an optimisation */ }
  }

  // The sniff reports the bare fact; the way out belongs to whoever shows it. On
  // the m-dev board that is the d key, here it is the command to type.
  return out ? red("! " + out + " - m-doctor --fix") : null;
}

// Under WSL this is the WSL2 VM's own budget (~50% of Windows RAM by default),
// not the machine's. MemAvailable, not MemFree: Node's os.freemem() maps to
// MemFree, which reads as near-empty whenever the page cache is warm.
function memInfo() {
  let text;
  try { text = fs.readFileSync("/proc/meminfo", "utf8"); }
  catch { return null; } // not Linux
  const kb = (key) => {
    const m = text.match(new RegExp("^" + key + ":\\s+(\\d+) kB", "m"));
    return m ? parseInt(m[1], 10) : null;
  };
  const total = kb("MemTotal");
  const avail = kb("MemAvailable");
  if (!total || avail == null) return null;
  const usedPct = ((total - avail) / total) * 100;
  const gib = (x) => (x / 1048576).toFixed(1);
  const color = usedPct >= 85 ? red : usedPct >= 65 ? yellow : green;
  return label("mem ") + color(usedPct.toFixed(0) + "%") + label(" · " + gib(avail) + "G free");
}

function contextBar(cw) {
  if (!cw) return null;
  let pct = cw.used_percentage;
  if (pct == null) {
    // Early in a session used_percentage can be null; fall back to a manual calc.
    const size = cw.context_window_size;
    const used = cw.total_input_tokens;
    if (size && used != null) pct = (used / size) * 100;
  }
  if (pct == null) return null;
  pct = Math.max(0, Math.min(100, pct));

  const width = 10;
  const filled = Math.round((pct / 100) * width);
  const bar = "▓".repeat(filled) + "░".repeat(width - filled);
  const color = pct >= 80 ? red : pct >= 50 ? yellow : green;
  return color(bar) + " " + color(pct.toFixed(0) + "%") + label(" ctx");
}

function rateLimits(rl) {
  if (!rl) return null;
  const segs = [];
  if (rl.five_hour?.used_percentage != null)
    segs.push("5h " + pctColor(rl.five_hour.used_percentage));
  if (rl.seven_day?.used_percentage != null)
    segs.push("7d " + pctColor(rl.seven_day.used_percentage));
  return segs.length ? label("⏱ ") + segs.join(" ") : null;
}

function pctColor(p) {
  const color = p >= 80 ? red : p >= 50 ? yellow : green;
  return color(Math.round(p) + "%");
}

function gitInfo(dir) {
  if (!dir) return null;
  try {
    const opts = { cwd: dir, stdio: ["ignore", "pipe", "ignore"], encoding: "utf8" };
    const branch = execSync("git rev-parse --abbrev-ref HEAD", opts).trim();
    if (!branch) return null;
    const dirty = execSync("git status --porcelain", opts).trim().length > 0;
    return magenta(branch) + (dirty ? yellow("*") : "");
  } catch {
    return null; // not a git repo, or git unavailable
  }
}
