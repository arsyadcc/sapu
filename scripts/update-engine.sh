#!/bin/bash
# Pulls the latest upstream Mole into engine/ as a squashed subtree commit.
# Usage: scripts/update-engine.sh [ref]   (default: main)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
REF="${1:-main}"

git remote get-url upstream > /dev/null 2>&1 \
    || git remote add upstream https://github.com/tw93/Mole.git
git fetch --depth 1 upstream "$REF"
SHA="$(git rev-parse --short FETCH_HEAD)"
git subtree pull --prefix engine upstream "$REF" --squash -m "Update engine to upstream $SHA"
