#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DESTINATION="/Applications/SpritePetStudio.app"

"$ROOT/scripts/build-app.sh"

if pgrep -x SpritePetStudio >/dev/null 2>&1; then
    osascript -e 'tell application id "com.herbit.sprite-pet-studio" to quit' >/dev/null 2>&1 || true
    for _ in {1..30}; do
        pgrep -x SpritePetStudio >/dev/null 2>&1 || break
        sleep 0.1
    done
fi

if pgrep -x SpritePetStudio >/dev/null 2>&1; then
    pkill -TERM -x SpritePetStudio >/dev/null 2>&1 || true
fi

rm -rf "$DESTINATION"
ditto "$ROOT/dist/SpritePetStudio.app" "$DESTINATION"
open -na "$DESTINATION"
