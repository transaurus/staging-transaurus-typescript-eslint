#!/usr/bin/env bash
set -euo pipefail

# rebuild.sh for transaurus/typescript-eslint
# Runs on existing source tree (no clone). Current directory should be the
# monorepo root. Installs deps, builds workspace packages (including
# website-eslint which is required for docusaurus build), then builds site.

echo "=== rebuild.sh: transaurus/typescript-eslint ==="

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

# --- Install dependencies ---
echo "=== Installing dependencies ==="
yarn install --immutable

# --- Build workspace packages ---
# Note: website-eslint IS included here (unlike prepare.sh) because
# @typescript-eslint/website-eslint/dist/index.js is required for docusaurus build.
echo "=== Building workspace packages ==="
export NX_NO_CLOUD=true
export NX_DAEMON=false
yarn nx run-many -t build --exclude website

# --- Build Docusaurus site ---
echo "=== Building Docusaurus site ==="
cd packages/website
../../node_modules/.bin/docusaurus build

echo "[DONE] Build complete."
