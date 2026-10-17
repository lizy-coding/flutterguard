#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}')"
SRC="$ROOT_DIR/bin/boundarylens.dart"
DIST="$ROOT_DIR/dist"
cd "$ROOT_DIR"
dart pub get --enforce-lockfile

case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux) OS="linux" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64) ARCH="x64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

NAME="boundarylens-${VERSION}-${OS}-${ARCH}"
BIN="$DIST/$NAME/boundarylens"
ARCHIVE="$DIST/$NAME.tar.gz"

rm -rf "$DIST/$NAME"
mkdir -p "$DIST/$NAME"

dart compile exe "$SRC" -o "$BIN"
chmod +x "$BIN"
if [[ "$("$BIN" --version)" != "boundarylens $VERSION" ]]; then
  echo 'Compiled CLI version does not match pubspec.' >&2
  exit 1
fi
cp "$ROOT_DIR/LICENSE" "$DIST/$NAME/LICENSE"
cp "$ROOT_DIR/idea-plugin/docs/third-party-notices.txt" "$DIST/$NAME/third-party-notices.txt"
cp "$ROOT_DIR/idea-plugin/docs/license-inventory.json" "$DIST/$NAME/license-inventory.json"
cp -R "$ROOT_DIR/idea-plugin/docs/native-licenses" "$DIST/$NAME/native-licenses"

tar -czf "$ARCHIVE" -C "$DIST" "$NAME"
echo "Release artifact: $ARCHIVE"
