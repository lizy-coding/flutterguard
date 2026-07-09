#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(grep '^version:' "$ROOT_DIR/packages/flutterguard_cli/pubspec.yaml" | awk '{print $2}')"
SRC="$ROOT_DIR/packages/flutterguard_cli/bin/flutterguard.dart"
DIST="$ROOT_DIR/dist"

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

NAME="flutterguard-${VERSION}-${OS}-${ARCH}"
BIN="$DIST/$NAME/flutterguard"
ARCHIVE="$DIST/$NAME.tar.gz"

rm -rf "$DIST/$NAME"
mkdir -p "$DIST/$NAME"

dart compile exe "$SRC" -o "$BIN"
chmod +x "$BIN"
"$BIN" --version

tar -czf "$ARCHIVE" -C "$DIST" "$NAME"
echo "Release artifact: $ARCHIVE"
