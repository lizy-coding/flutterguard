#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/idea-plugin"
VERSION="$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}')"
NATIVE_DIST="$ROOT_DIR/dist"
export PLUGIN_VERSION="$VERSION"

failures=()

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1" >&2; failures+=("$1"); }

run_gate() {
  local label="$1"; shift
  printf '\n== %s ==\n' "$label"
  if "$@"; then pass "$label"; else fail "$label"; fi
}

printf 'BoundaryLens IDEA Plugin release preflight\n'
printf 'Version: %s\n' "$VERSION"
printf 'Plugin dir: %s\n\n' "$PLUGIN_DIR"

# ---- 1. Verify plugin project exists ----
if [[ ! -f "$PLUGIN_DIR/build.gradle.kts" ]]; then
  fail 'idea-plugin/build.gradle.kts not found'
  printf '\nPreflight aborted: plugin project missing.\n' >&2
  exit 1
fi
pass 'plugin project exists'

# First Marketplace release is explicitly macOS ARM64. The descriptor must
# restrict delivery too; a filename or README statement is not a platform gate.
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  fail 'release validation requires the declared macOS ARM64 host'
  exit 1
fi
# ---- 2. Verify the declared native target before mutating resources ----
NATIVE_TARGETS=(
  "boundarylens-${VERSION}-macos-arm64/boundarylens"
)
for target in "${NATIVE_TARGETS[@]}"; do
  if [[ -x "$NATIVE_DIST/$target" ]] || [[ -f "$NATIVE_DIST/$target" ]]; then
    pass "native binary: $target"
  else
    fail "native binary missing: $target (run scripts/package_release.sh on each platform first)"
  fi
done

if (( ${#failures[@]} > 0 )); then
  printf '\nPreflight aborted: declared native target missing; existing plugin resources were not overwritten.\n' >&2
  exit 1
fi

# ---- 3. Sync native binaries into plugin resources ----
RESOURCES_DIR="$PLUGIN_DIR/src/main/resources/bin"
mkdir -p "$RESOURCES_DIR"

sync_binary() {
  local src_path="$1"
  local dst_name="$2"
  if [[ -f "$NATIVE_DIST/$src_path" ]]; then
    cp "$NATIVE_DIST/$src_path" "$RESOURCES_DIR/$dst_name"
    chmod +x "$RESOURCES_DIR/$dst_name" 2>/dev/null || true
    pass "synced: $src_path -> resources/bin/$dst_name"
  fi
}

sync_binary "boundarylens-${VERSION}-macos-arm64/boundarylens" "boundarylens-darwin-arm64"
run_gate 'native version' bash -c '[[ "$("$1" --version)" == "boundarylens $2" ]]' _ "$RESOURCES_DIR/boundarylens-darwin-arm64" "$VERSION"
run_gate 'native ARM64 Mach-O' bash -c 'file "$1" | grep -q "Mach-O 64-bit executable arm64"' _ "$RESOURCES_DIR/boundarylens-darwin-arm64"
for extra in boundarylens-darwin-x64 boundarylens-linux-x64 boundarylens-windows-x64.exe; do
  if [[ -e "$RESOURCES_DIR/$extra" ]]; then fail "undeclared native resource: $extra"; fi
done

# ---- 4. Verify plugin descriptor ----
PLUGIN_XML="$PLUGIN_DIR/src/main/resources/META-INF/plugin.xml"
if [[ -f "$PLUGIN_XML" ]]; then
  if grep -q '<id>com.boundarylens</id>' "$PLUGIN_XML"; then
    pass 'plugin.xml id matches'
  else
    fail 'plugin.xml id does not match com.boundarylens'
  fi
  for dependency in com.intellij.modules.os.mac com.intellij.modules.arch.arm64; do
    if grep -q "<depends>$dependency</depends>" "$PLUGIN_XML"; then
      pass "platform dependency: $dependency"
    else
      fail "missing platform dependency: $dependency"
    fi
  done
else
  fail "plugin.xml not found at $PLUGIN_XML"
fi

# ---- 5. Verify Gradle wrapper ----
if [[ -x "$PLUGIN_DIR/gradlew" ]]; then
  pass 'gradlew exists'
else
  fail 'gradlew missing (run: cd idea-plugin && gradle wrapper)'
fi

if (( ${#failures[@]} > 0 )); then exit 1; fi
gradle_args=(--no-daemon)
if [[ -n "${BOUNDARYLENS_LOCAL_IDE_PATH:-}" ]]; then
  gradle_args+=("-PlocalIdePath=$BOUNDARYLENS_LOCAL_IDE_PATH" "-PverifierIdePath=$BOUNDARYLENS_LOCAL_IDE_PATH")
fi
if [[ "${BOUNDARYLENS_GRADLE_OFFLINE:-false}" == true ]]; then gradle_args+=(--offline); fi
if [[ -n "${BOUNDARYLENS_VERIFIER_HOME:-}" ]]; then
  gradle_args+=("-PverifierHomePath=$BOUNDARYLENS_VERIFIER_HOME")
fi
# ---- 6-8. Build and verify the same declared distribution ----
cd "$PLUGIN_DIR"
run_gate 'gradle check/buildPlugin' ./gradlew "${gradle_args[@]}" check buildPlugin
verifier_marker="$PLUGIN_DIR/build/.release-verifier-start"
touch "$verifier_marker"
run_gate 'plugin verifier' ./gradlew "${gradle_args[@]}" verifyPlugin
fresh_report=false
for dependencies in "$PLUGIN_DIR"/build/reports/pluginVerifier/*/plugins/com.boundarylens/"$VERSION"/dependencies.txt; do
  if [[ -f "$dependencies" && "$dependencies" -nt "$verifier_marker" ]]; then
    fresh_report=true
    verdict="${dependencies%/dependencies.txt}/verification-verdict.txt"
    if grep -qx 'Compatible' "$verdict" && grep -Eq 'Dart:[0-9]' "$dependencies"; then
      pass 'fresh Compatible verdict with resolved Dart dependency'
    else
      fail 'Verifier must be Compatible and resolve the real Dart plugin'
    fi
  fi
done
if [[ "$fresh_report" != true ]]; then fail 'fresh Verifier dependency report missing'; fi

# ---- Report ----
PLUGIN_ZIP="$PLUGIN_DIR/build/distributions/boundarylens-idea-${VERSION}.zip"
if [[ -f "$PLUGIN_ZIP" ]]; then
  pass "plugin zip: $PLUGIN_ZIP"
else
  fail 'plugin zip not produced'
fi

printf '\n== Human checklist ==\n'
printf '[ ] Review plugin.xml: name, description, change-notes for version %s\n' "$VERSION"
printf '[ ] Verify plugin icon at src/main/resources/META-INF/pluginIcon.svg\n'
printf '[ ] Confirm JetBrains Marketplace token is set (env: ORG_GRADLE_PROJECT_intellijPublishToken)\n'
printf '[ ] Run: cd idea-plugin && ./gradlew publishPlugin\n'
printf '[ ] Verify listing at https://plugins.jetbrains.com/plugin/...\n'

if (( ${#failures[@]} > 0 )); then
  printf '\nPreflight FAILED (%d gate(s))\n' "${#failures[@]}" >&2
  for f in "${failures[@]}"; do printf ' - %s\n' "$f" >&2; done
  exit 1
fi

printf '\nPreflight PASSED. Plugin zip: %s\n' "$PLUGIN_ZIP"
printf 'To publish: cd idea-plugin && ./gradlew publishPlugin\n'
