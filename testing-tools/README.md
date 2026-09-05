# Testing tools

Hand-run snippets for testing things that are awkward to reach from a terminal.
Nothing here is installed by `bootstrap.ps1`; you copy the file you need.

## preview-api-console.js

Calls a momentum BFF route in a PR-preview deploy from the browser console, so a
work item's test plan can be run without building a curl session by hand.

Copy the whole file into devtools on any page, then:

```js
await testPreviewApiGet(666, "/tasks/00000000-0000-0000-0000-000000000000");
await testPreviewApiGet(666, "/tasks/whatever", { withSession: false });   // expect 401
await testPreviewApiPost(666, "/tasks/some-id/complete", { comment: "done" });
await testPreviewApiGet(666, "/internal/momentum/bff/acs/currentuser");    // other realm, full path
```

A query string is yours to build:

```js
const filter = JSON.stringify({ filterByTaskCategories: [1, 2, 5, 7, 8] });
await testPreviewApiGet(666, "/tasks?filterOptions=" + encodeURIComponent(filter));
```

`withSession: false` sends no cookies, which is how you test the unauthenticated case.

### How it reaches the PR deploy

`X-Preview-Pr: <N>` against the **canonical** host. A PR-scoped release of `app-bff` or
`acs-bff` renders no ingress of its own, so there is no `pr-666-app-bff` host to call.
Istio matches the header on canonical's host and routes to the PR sibling. The repo skill
`.claude/skills/preview-backend-test/SKILL.md` in momentum covers the other modes
(dash-form hosts, netshoot, port-forward).

### Three things that cost time the first time

- **Every call makes two Network rows.** `X-Preview-Pr` is not a CORS-safelisted request
  header, so each request is preceded by an OPTIONS preflight that answers `204`. The 204
  is not your result. The logged status is the real one; in devtools filter to
  `method:GET` or `method:POST`.
- **`r.json()` is the wrong reader.** A `401` comes back with an empty body and `r.json()`
  throws on it, which reads as "the call didn't work" when the status was exactly right.
  The snippet uses `r.text()` and parses defensively.
- **`X-Preview-Served-By` names the pod that answered, but script cannot read it.** It is
  not in `Access-Control-Expose-Headers`, so it only shows in the Network tab. Use it when
  you need to prove the PR pod served the request rather than canonical.

### Host and prefix

`PREVIEW_HOST` is the development `us-west-2` app host and `PREVIEW_PREFIX` is app-bff's.
Edit both at the top of the file for another environment or realm, or pass a full
`/internal/...` path to skip the prefix.
