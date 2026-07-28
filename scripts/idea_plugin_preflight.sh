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

printf 'FlutterGuard IDEA Plugin release preflight\n'
printf 'Version: %s\n' "$VERSION"
printf 'Plugin dir: %s\n\n' "$PLUGIN_DIR"

# ---- 1. Verify plugin project exists ----
if [[ ! -f "$PLUGIN_DIR/build.gradle.kts" ]]; then
  fail 'idea-plugin/build.gradle.kts not found'
  printf '\nPreflight aborted: plugin project missing.\n' >&2
  exit 1
fi
pass 'plugin project exists'

# ---- 2. Verify native binaries are built for all 3 platforms ----
NATIVE_TARGETS=(
  "flutterguard-${VERSION}-macos-arm64/flutterguard"
  "flutterguard-${VERSION}-macos-x64/flutterguard"
  "flutterguard-${VERSION}-linux-x64/flutterguard"
  "flutterguard-${VERSION}-windows-x64/flutterguard.exe"
)
for target in "${NATIVE_TARGETS[@]}"; do
  if [[ -x "$NATIVE_DIST/$target" ]] || [[ -f "$NATIVE_DIST/$target" ]]; then
    pass "native binary: $target"
  else
    fail "native binary missing: $target (run scripts/package_release.sh on each platform first)"
  fi
done

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

sync_binary "flutterguard-${VERSION}-macos-arm64/flutterguard" "flutterguard-darwin-arm64"
sync_binary "flutterguard-${VERSION}-macos-x64/flutterguard" "flutterguard-darwin-x64"
sync_binary "flutterguard-${VERSION}-linux-x64/flutterguard" "flutterguard-linux-x64"
sync_binary "flutterguard-${VERSION}-windows-x64/flutterguard.exe" "flutterguard-windows-x64.exe"

# ---- 4. Verify plugin descriptor ----
PLUGIN_XML="$PLUGIN_DIR/src/main/resources/META-INF/plugin.xml"
if [[ -f "$PLUGIN_XML" ]]; then
  if grep -q '<id>com.flutterguard</id>' "$PLUGIN_XML"; then
    pass 'plugin.xml id matches'
  else
    fail 'plugin.xml id does not match com.flutterguard'
  fi
else
  fail "plugin.xml not found at $PLUGIN_XML"
fi

# ---- 5. Verify Gradle wrapper ----
if [[ -x "$PLUGIN_DIR/gradlew" ]]; then
  pass 'gradlew exists'
else
  fail 'gradlew missing (run: cd idea-plugin && gradle wrapper)'
fi

# ---- 6. Gradle check (compile + test) ----
run_gate 'gradle check' bash -c "cd '$PLUGIN_DIR' && ./gradlew check"

# ---- 7. Plugin verifier ----
run_gate 'plugin verifier' bash -c "cd '$PLUGIN_DIR' && ./gradlew verifyPlugin"

# ---- 8. Build plugin distribution ----
run_gate 'buildPlugin' bash -c "cd '$PLUGIN_DIR' && ./gradlew buildPlugin"

# ---- Report ----
PLUGIN_ZIP=$(ls "$PLUGIN_DIR/build/distributions/"*.zip 2>/dev/null | head -1)
if [[ -n "$PLUGIN_ZIP" ]]; then
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
