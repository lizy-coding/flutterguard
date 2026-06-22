#!/usr/bin/env bash
set -euo pipefail

FAIL_ON="${FLUTTERGUARD_FAIL_ON:-high}"
MIN_SCORE="${FLUTTERGUARD_MIN_SCORE:-80}"
TARGET="${1:-.}"

echo "==> FlutterGuard CI Scan"
echo "    Target:    $TARGET"
echo "    Fail-on:   $FAIL_ON"
echo "    Min-score: $MIN_SCORE"
echo ""

flutterguard scan "$TARGET" --format json --fail-on "$FAIL_ON" --min-score "$MIN_SCORE"

if [ $? -eq 0 ]; then
    echo ""
    echo "All checks passed!"
else
    echo ""
    echo "CI gate failed! Check .flutterguard/report.json for details."
    exit 1
fi
