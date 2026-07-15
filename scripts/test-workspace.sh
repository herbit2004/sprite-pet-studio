#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export XDG_CACHE_HOME="$ROOT/.build/cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$XDG_CACHE_HOME"

swift build --disable-sandbox --product SpritePetStudio
BIN_DIR="$(swift build --disable-sandbox --show-bin-path)"
TEMP_ROOT="$(mktemp -d /private/tmp/spritepet-workspace-test.XXXXXX)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

ditto \
    "$BIN_DIR/SpritePetStudio_SpritePetStudio.bundle" \
    "$TEMP_ROOT/SpritePetStudio_SpritePetStudio.bundle"

swiftc \
    -parse-as-library \
    "$ROOT/Sources/SpritePetStudio/Core/Models.swift" \
    "$ROOT/Sources/SpritePetStudio/Core/CodexV2Schema.swift" \
    "$ROOT/Sources/SpritePetStudio/Core/DocumentStore.swift" \
    "$ROOT/Tests/WorkspaceStoreSmoke/main.swift" \
    -o "$TEMP_ROOT/workspace-store-smoke"

"$TEMP_ROOT/workspace-store-smoke" "$TEMP_ROOT/TestData"
