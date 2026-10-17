#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/idea-plugin"
VERSION="$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}')"
export PLUGIN_VERSION="$VERSION"

printf 'BoundaryLens IDEA Plugin publish — version %s\n\n' "$VERSION"

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  printf 'Publish aborted: freeze and commit the reviewed source before uploading.\n' >&2
  exit 1
fi

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

printf '\nUpload completed for version %s; Marketplace verification and approval are still pending.\n' "$VERSION"
printf 'Verify at https://plugins.jetbrains.com/\n'
