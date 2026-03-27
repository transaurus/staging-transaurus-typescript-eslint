#!/usr/bin/env bash
set -euo pipefail

# prepare.sh for transaurus/typescript-eslint
# Nx monorepo, Yarn 3.8.2 (Corepack), Node 20
# Docusaurus path: packages/website/
# Clones repo, installs deps, builds workspace packages.
# Does NOT run write-translations or build.

REPO_URL="https://github.com/transaurus/typescript-eslint"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== prepare.sh: transaurus/typescript-eslint ==="

# --- Node version: Node 20 via nvm ---
export NVM_DIR="${HOME}/.nvm"
if [ ! -f "$NVM_DIR/nvm.sh" ]; then
    echo "Installing nvm..."
    curl -fsSL -o /tmp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh
    bash /tmp/nvm-install.sh
fi
source "$NVM_DIR/nvm.sh"
nvm install 20 --no-progress
nvm use 20
echo "Node: $(node --version)"
echo "npm: $(npm --version)"

# --- Corepack + Yarn 3.8.2 ---
corepack enable
echo "Corepack enabled"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning $REPO_URL (depth 1, branch $BRANCH)..."
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
    echo "Clone complete."
else
    echo "source-repo/ already exists, skipping clone."
fi

cd "$REPO_DIR"

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes from fixes.json..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            } else if (op.type === 'replace') {
                console.log('  skip (find not found):', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

# --- Install dependencies ---
echo "=== Installing dependencies ==="
yarn install --immutable

# --- Build workspace packages (needed for workspace imports in docusaurus config) ---
echo "=== Building workspace packages ==="
export NX_NO_CLOUD=true
export NX_DAEMON=false
yarn nx run-many -t build --exclude website website-eslint

echo "[DONE] Repository is ready for docusaurus commands."
