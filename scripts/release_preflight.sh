#!/usr/bin/env bash
# Runs the publish checks that can be automated before creating a pub.dev release.
# It never uploads a package.
set -u -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

failures=()

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  failures+=("$1")
}

run_gate() {
  local label="$1"
  shift
  printf '\n== %s ==\n' "$label"
  if "$@"; then
    pass "$label"
  else
    fail "$label"
  fi
}

printf 'FlutterGuard release preflight (no package upload)\n'
printf 'Repository: %s\n\n' "$ROOT_DIR"

for required_file in pubspec.yaml README.md CHANGELOG.md LICENSE; do
  if [[ -s "$required_file" ]]; then
    pass "required file: $required_file"
  else
    fail "required file: $required_file"
  fi
done

if git diff --check; then
  pass 'no whitespace errors'
else
  fail 'no whitespace errors'
fi

if [[ -z "$(git status --porcelain)" ]]; then
  pass 'clean Git worktree'
else
  fail 'clean Git worktree (commit, stash, or remove local changes before publishing)'
fi

run_gate 'resolve dependencies' dart pub get
run_gate 'format gate' dart format --output=none --set-exit-if-changed bin lib test
run_gate 'static analysis' dart analyze
run_gate 'test suite' dart test
run_gate 'CLI smoke scan' dart run bin/flutterguard.dart scan example --format json --no-color --fail-on high
run_gate 'pub.dev dry run' dart pub publish --server https://pub.dev --dry-run

VERSION="$(awk '/^version:[[:space:]]*/ { print $2; exit }' pubspec.yaml)"
EXPECTED_TAG="v$VERSION"

printf '\n== Human release checklist ==\n'
printf '[ ] Inspect the file list and warnings printed by "pub.dev dry run"; do not publish unwanted files.\n'
printf '[ ] Confirm that every included file may legally be redistributed and the LICENSE is correct.\n'
printf '[ ] Confirm %s is a new pub.dev version and CHANGELOG.md describes this release.\n' "$VERSION"
printf '[ ] Create and push tag %s at the intended release commit.\n' "$EXPECTED_TAG"
printf '[ ] Confirm the publishing Google account has access to the intended pub.dev publisher.\n'

if git rev-parse -q --verify "refs/tags/$EXPECTED_TAG" >/dev/null; then
  tag_commit="$(git rev-list -n 1 "$EXPECTED_TAG")"
  head_commit="$(git rev-parse HEAD)"
  if [[ "$tag_commit" == "$head_commit" ]]; then
    pass "local tag $EXPECTED_TAG points at HEAD"
  else
    printf 'INFO  local tag %s does not point at HEAD; verify the release commit before pushing it.\n' "$EXPECTED_TAG"
  fi
else
  printf 'INFO  local tag %s has not been created yet.\n' "$EXPECTED_TAG"
fi

if (( ${#failures[@]} > 0 )); then
  printf '\nRelease preflight failed (%d gate(s)):\n' "${#failures[@]}" >&2
  for failure in "${failures[@]}"; do
    printf ' - %s\n' "$failure" >&2
  done
  exit 1
fi

printf '\nAutomated preflight passed. Complete every human checklist item before running dart pub publish.\n'
