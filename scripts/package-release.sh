#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/SpritePetStudio.app"
ARCHIVE="$ROOT/dist/SpritePetStudio-macOS.zip"
CHECKSUM="$ARCHIVE.sha256"

"$ROOT/scripts/build-app.sh"

rm -f "$ARCHIVE" "$CHECKSUM"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ARCHIVE"

cd "$ROOT/dist"
shasum -a 256 "${ARCHIVE:t}" > "${CHECKSUM:t}"

echo "$ARCHIVE"
echo "$CHECKSUM"
