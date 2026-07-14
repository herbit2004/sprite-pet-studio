#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
"$ROOT/scripts/build-app.sh"
ditto "$ROOT/dist/SpritePetStudio.app" "/Applications/SpritePetStudio.app"
open "/Applications/SpritePetStudio.app"
