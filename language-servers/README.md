# Language servers

Claude Code's `LSP` tool needs a language server per file type. Neither server is
bundled, and neither is installed by `bootstrap.ps1`, so a new machine has to do this
separately. Without it the tool answers "No LSP server available for file type" and
goes unused. `typescript-lsp` sat enabled and unused for 176 startups that way.

Usage guidance is in the `# Code intelligence` section of `CLAUDE.md`. This file is
only about getting the servers running.

## WSL and Linux

```bash
bash language-servers/setup.sh
```

Then restart Claude Code. Servers are read at session start, so a running session
never picks up a change here.

## Windows

No script yet. Run these by hand, in PowerShell:

```powershell
npm install -g typescript-language-server typescript@6
npm install -g @vue/language-server@2
```

Then write `%USERPROFILE%\.claude\local-plugins\.claude-plugin\marketplace.json` with
the same content `setup.sh` generates, changing `tsdk` to the Windows path
(`npm root -g` + `\typescript\lib`, with backslashes escaped for JSON), and register
it:

```powershell
claude plugin marketplace add "$env:USERPROFILE\.claude\local-plugins"
claude plugin install vue-lsp@joey-local
```

## Why the versions are pinned

Both pins are load-bearing. Neither is a preference.

**`typescript@6`.** A plain `npm i -g typescript` now installs 7.x, the native Go
port. Its `lib/` has no `tsserver.js`, only `tsc.js` and a shim to the native binary,
so `typescript-language-server` starts and immediately exits with "Could not find a
valid TypeScript installation".

**`@vue/language-server@2`.** Volar 3.x is hybrid-mode only. It does no TypeScript
itself: it forwards every TS request to a separate tsserver over a custom
`tsserver/request` notification the editor is expected to bridge. VS Code's Vue
extension implements that bridge; Claude Code speaks plain LSP and does not, so 3.x
crashes on the first request with
`Cannot read properties of undefined (reading 'protocol')`. No config avoids it.
2.x still supports standalone mode through `initializationOptions.vue.hybridMode`.

## Why the vue config is not in this repo

It needs `typescript.tsdk` as an absolute path to a TypeScript `lib` directory. That
path is machine-specific (on WSL it also carries the nvm version), so the generated
config lives in `~/.claude/local-plugins/` and stays out of the repo. Same reasoning
as `settings.json`. `setup.sh` resolves the path and writes the file, which is the
whole reason it is a script and not a copied-in file.

If `tsdk` is missing or wrong, the server starts and reports its capabilities
normally, then answers "Unhandled method" to every request. It fails quietly, so
check a real `.vue` file after setup rather than trusting a clean start.

## Things that bite

- **nvm.** Global installs land in the active Node version's prefix only. Switching
  Node makes both servers vanish and the `tsdk` path stale. Re-run `setup.sh`.
- **Corporate TLS.** Node ships its own CA list, so npm fails on GitHub-tarball deps
  with `UNABLE_TO_GET_ISSUER_CERT_LOCALLY` while curl on the same URL works.
  `setup.sh` exports `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt`, which
  already carries `laserfiche.crt` and `zscaler.crt`.
- **No Nuxt server exists, and none is needed.** Auto-imports, `#imports`, and route
  and component types come from the generated `.d.ts` files in `src/ui-app/.nuxt/`,
  which `tsconfig.json` pulls in by project reference. Stale types mean
  `nuxt prepare`, not another server.
- **C# gets nothing** from either server.

## The config schema is wider than it looks

Every official LSP plugin uses only `command`, `args`, `extensionToLanguage`, and
`startupTimeout`. The client also accepts `transport`, `env`, `initializationOptions`,
`settings`, and a workspace path. `initializationOptions` is what makes the Vue
server possible at all, so do not assume the four keys are the whole schema.
