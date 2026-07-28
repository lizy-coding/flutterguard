#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/idea-plugin"
VERSION="$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}')"
export PLUGIN_VERSION="$VERSION"

printf 'FlutterGuard IDEA Plugin publish — version %s\n\n' "$VERSION"

# ---- Gate: preflight must pass ----
printf '== Running preflight ==\n'
if ! bash "$ROOT_DIR/scripts/idea_plugin_preflight.sh"; then
  printf '\nPublish aborted: preflight failed.\n' >&2
  exit 1
fi

# ---- Gate: token check ----
if [[ -z "${ORG_GRADLE_PROJECT_intellijPublishToken:-}" ]]; then
  printf '\nERROR: ORG_GRADLE_PROJECT_intellijPublishToken is not set.\n' >&2
  printf 'Generate a token at https://plugins.jetbrains.com/author/me/tokens\n' >&2
  printf 'Then: export ORG_GRADLE_PROJECT_intellijPublishToken=<token>\n' >&2
  exit 1
fi
printf 'Publish token: configured\n'

# ---- Publish ----
printf '\n== Publishing to JetBrains Marketplace ==\n'
cd "$PLUGIN_DIR"
./gradlew publishPlugin

printf '\nDone. Plugin version %s published.\n' "$VERSION"
printf 'Verify at https://plugins.jetbrains.com/\n'
