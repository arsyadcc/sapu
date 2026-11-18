#!/bin/bash
# Builds the engine's Go helpers (if needed) and copies the engine runtime
# into the app bundle. Usage: bundle-engine.sh <destination-dir>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$ROOT/engine"
DEST="${1:?destination directory required}"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if [[ ! -x "$ENGINE/bin/analyze-go" || ! -x "$ENGINE/bin/status-go" ]] \
    || [[ -n "$(find "$ENGINE/cmd" "$ENGINE/internal" -name '*.go' -newer "$ENGINE/bin/status-go" 2> /dev/null | head -1)" ]]; then
    echo "Building engine Go helpers..."
    make -C "$ENGINE" build
fi

mkdir -p "$DEST"
rsync -a --delete \
    --include='/mole' --include='/mo' --include='/LICENSE' \
    --include='/bin/***' --include='/lib/***' \
    --exclude='*' \
    "$ENGINE/" "$DEST/"
echo "Engine bundled into $DEST"
