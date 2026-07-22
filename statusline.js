#!/usr/bin/env node
// Claude Code custom status line. Reads the status JSON on stdin, prints one line.
// Docs: https://code.claude.com/docs/en/statusline.md
// Each segment is independent — delete a `push(...)` block to remove that segment.

const { execSync } = require("child_process");
const path = require("path");

// --- ANSI helpers -----------------------------------------------------------
const c = (code, s) => `\x1b[${code}m${s}\x1b[0m`;
const dim = (s) => c("2", s);
const bold = (s) => c("1", s);
const green = (s) => c("32", s);
const yellow = (s) => c("33", s);
const red = (s) => c("31", s);
const cyan = (s) => c("36", s);
const blue = (s) => c("34", s);
const magenta = (s) => c("35", s);
const SEP = dim("  │  ");

// --- read stdin -------------------------------------------------------------
let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (d) => (raw += d));
process.stdin.on("end", () => {
  let j = {};
  try { j = JSON.parse(raw); } catch { /* print what we can */ }
  try { process.stdout.write(render(j)); }
  catch (e) { process.stdout.write(dim("statusline error: " + e.message)); }
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
    if (effort) m += dim(" ·" + effort);
    parts.push(m);
  }

  // 4) Context-window usage bar (the headline metric)
  const ctx = contextBar(j?.context_window);
  if (ctx) parts.push(ctx);

  // 5) Rate-limit windows (only present on some plans; hidden otherwise)
  const rl = rateLimits(j?.rate_limits);
  if (rl) parts.push(rl);

  return parts.join(SEP);
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
  return color(bar) + " " + color(pct.toFixed(0) + "%") + dim(" ctx");
}

function rateLimits(rl) {
  if (!rl) return null;
  const segs = [];
  if (rl.five_hour?.used_percentage != null)
    segs.push("5h " + pctColor(rl.five_hour.used_percentage));
  if (rl.seven_day?.used_percentage != null)
    segs.push("7d " + pctColor(rl.seven_day.used_percentage));
  return segs.length ? dim("⏱ ") + segs.join(" ") : null;
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
