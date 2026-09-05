// Paste into the browser devtools console on any page, then call
// testPreviewApiGet / testPreviewApiPost. See README.md in this folder.
//
// Hit a PR-scoped preview release of a BFF through the canonical host.
// `api` can be a full URL or a path; a bare path gets the app-bff prefix.
const PREVIEW_HOST = "https://app.a.clouddev.laserfiche.com";
const PREVIEW_PREFIX = "/internal/momentum/bff/app";

function previewUrl(api) {
  if (/^https?:\/\//.test(api)) return api;
  if (api.startsWith("/internal/")) return PREVIEW_HOST + api;
  return PREVIEW_HOST + PREVIEW_PREFIX + (api.startsWith("/") ? api : "/" + api);
}

async function callPreviewApi(prNum, api, { method = "GET", body, withSession = true } = {}) {
  const url = previewUrl(api);
  const headers = { "X-Preview-Pr": String(prNum) };
  if (body !== undefined) headers["Content-Type"] = "application/json";

  const r = await fetch(url, {
    method,
    credentials: withSession ? "include" : "omit",
    cache: "no-store",
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  // 401 and 204 have empty bodies, so r.json() would throw on a perfectly good answer.
  const text = await r.text();
  let parsed = text;
  try { parsed = JSON.parse(text); } catch {}

  console.log(`${method} ${url} (pr ${prNum}) -> ${r.status} ${r.statusText}`);
  console.log(parsed);
  return { status: r.status, ok: r.ok, body: parsed };
}

function testPreviewApiGet(prNum, api, opts) {
  return callPreviewApi(prNum, api, { ...opts, method: "GET" });
}

function testPreviewApiPost(prNum, api, body, opts) {
  return callPreviewApi(prNum, api, { ...opts, method: "POST", body });
}
