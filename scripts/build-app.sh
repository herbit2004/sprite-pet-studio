#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export XDG_CACHE_HOME="$ROOT/.build/cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$XDG_CACHE_HOME"

swift build --disable-sandbox -c release --product SpritePetStudio
swift build --disable-sandbox -c release --product spritepetctl

BIN_DIR="$(swift build --disable-sandbox -c release --show-bin-path)"
APP="$ROOT/dist/SpritePetStudio.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Config/Info.plist" "$APP/Contents/Info.plist"
cp "$BIN_DIR/SpritePetStudio" "$APP/Contents/MacOS/SpritePetStudio"
cp "$BIN_DIR/spritepetctl" "$APP/Contents/MacOS/spritepetctl"

# Keep the Finder/Dock icon at the standard top-level app resource location.
cp "$ROOT/Sources/SpritePetStudio/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

RESOURCE_BUNDLE="$BIN_DIR/SpritePetStudio_SpritePetStudio.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2
    exit 1
fi
ditto "$RESOURCE_BUNDLE" "$APP/Contents/Resources/SpritePetStudio_SpritePetStudio.bundle"

BUILTIN_ROOT="$APP/Contents/Resources/SpritePetStudio_SpritePetStudio.bundle/BuiltinProjects"
for REQUIRED_FILE in \
    "$BUILTIN_ROOT/little-naruto/project.json" \
    "$BUILTIN_ROOT/little-naruto/spritesheet.png" \
    "$BUILTIN_ROOT/dimoo-heartfelt-mix/project.json" \
    "$BUILTIN_ROOT/dimoo-heartfelt-mix/spritesheet.png"; do
    if [[ ! -f "$REQUIRED_FILE" ]]; then
        echo "Missing built-in project resource: $REQUIRED_FILE" >&2
        exit 1
    fi
done

codesign --force --deep --sign - "$APP"
echo "$APP"
