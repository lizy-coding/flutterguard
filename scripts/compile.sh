#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT_DIR/packages/flutterguard_cli/bin/flutterguard.dart"
OUT="$ROOT_DIR/flutterguard"

echo "==> Compiling FlutterGuard CLI..."
dart compile exe "$SRC" -o "$OUT"

if [ -f "$OUT" ]; then
    echo "==> Done: $OUT"
    "$OUT" --version
else
    echo "==> Error: compilation failed"
    exit 1
fi
