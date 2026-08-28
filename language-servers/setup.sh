#!/usr/bin/env bash
# Install the TypeScript and Vue language servers for Claude Code's LSP tool, and
# register the local vue-lsp plugin. Safe to re-run. WSL/Linux only; see README.md
# for the Windows commands.
set -euo pipefail

# Node ships its own CA list, so npm fails on GitHub-tarball deps behind the
# corporate TLS proxy while curl succeeds. Hand node the system bundle.
SYS_CA=/etc/ssl/certs/ca-certificates.crt
if [ -f "$SYS_CA" ]; then
  export NODE_EXTRA_CA_CERTS="$SYS_CA"
fi

command -v npm >/dev/null || { echo "npm not found. Load nvm first." >&2; exit 1; }
echo "node $(node -v), npm prefix $(npm root -g)"

# typescript@6 is load-bearing: 7.x is the native port and ships no lib/tsserver.js,
# so typescript-language-server dies with "Could not find a valid TypeScript
# installation".
echo "==> typescript-language-server + typescript@6"
npm install -g typescript-language-server 'typescript@6'

# Volar 3.x is hybrid-mode only. It forwards every TS request to a separate tsserver
# over a custom tsserver/request notification that the editor has to bridge, which
# Claude Code does not do, so it crashes on the first request. 2.x still runs
# standalone via initializationOptions.vue.hybridMode.
echo "==> @vue/language-server@2"
npm install -g '@vue/language-server@2'

TSDK="$(npm root -g)/typescript/lib"
[ -f "$TSDK/tsserver.js" ] || { echo "no tsserver.js under $TSDK" >&2; exit 1; }

# The vue server needs an absolute tsdk path, so this config is machine-specific and
# lives outside this repo, same reasoning as settings.json.
LP="$HOME/.claude/local-plugins"
mkdir -p "$LP/.claude-plugin" "$LP/plugins/vue-lsp/.claude-plugin"

cat > "$LP/.claude-plugin/marketplace.json" <<EOF
{
  "\$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "joey-local",
  "description": "Local, machine-specific plugins",
  "owner": { "name": "joey", "email": "joey.lin@laserfiche.com" },
  "plugins": [
    {
      "name": "vue-lsp",
      "description": "Vue SFC language server (.vue) via Volar 2.x in standalone mode",
      "version": "1.0.0",
      "author": { "name": "joey" },
      "source": "./plugins/vue-lsp",
      "category": "development",
      "strict": false,
      "lspServers": {
        "vue": {
          "command": "vue-language-server",
          "args": ["--stdio"],
          "extensionToLanguage": { ".vue": "vue" },
          "startupTimeout": 30000,
          "initializationOptions": {
            "vue": { "hybridMode": false },
            "typescript": { "tsdk": "$TSDK" }
          }
        }
      }
    }
  ]
}
EOF

cat > "$LP/plugins/vue-lsp/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "vue-lsp",
  "description": "Vue SFC language server (.vue) via Volar 2.x in standalone mode",
  "version": "1.0.0",
  "author": { "name": "joey" }
}
EOF

python3 -m json.tool "$LP/.claude-plugin/marketplace.json" >/dev/null
echo "==> wrote $LP (tsdk $TSDK)"

echo "==> registering with claude"
claude plugin marketplace add "$LP" 2>&1 | tail -1 || true
claude plugin install vue-lsp@joey-local 2>&1 | tail -1 || true
claude plugin install typescript-lsp@claude-plugins-official 2>&1 | tail -1 || true

cat <<'EOF'

Done. Restart Claude Code: LSP servers are read at session start.

Check it worked by asking for an LSP documentSymbol on a .ts file and a .vue file.
"No LSP server available for file type" means the config did not load.
EOF
