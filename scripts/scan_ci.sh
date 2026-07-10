#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FAIL_ON="${FLUTTERGUARD_FAIL_ON:-high}"
MIN_SCORE="${FLUTTERGUARD_MIN_SCORE:-80}"
TARGET="${1:-$ROOT_DIR/examples/scan_demo}"

echo "==> FlutterGuard CI Scan"
echo "    Target:    $TARGET"
echo "    Fail-on:   $FAIL_ON"
echo "    Min-score: $MIN_SCORE"
echo ""

if "$SCRIPT_DIR/flutterguard-dev" scan "$TARGET" --format json --fail-on "$FAIL_ON" --min-score "$MIN_SCORE"; then
    echo ""
    echo "All checks passed!"
else
    status=$?
    echo ""
    if [ "$status" -eq 1 ]; then
        echo "CI gate failed! Check $TARGET/.flutterguard/report.json for details."
    else
        echo "FlutterGuard scan setup failed with exit code $status."
    fi
    exit "$status"
fi
