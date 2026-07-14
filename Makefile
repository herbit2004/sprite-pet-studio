.PHONY: build app release install clean

build:
	CLANG_MODULE_CACHE_PATH="$(CURDIR)/.build/ModuleCache" XDG_CACHE_HOME="$(CURDIR)/.build/cache" swift build --disable-sandbox

app:
	./scripts/build-app.sh

release:
	./scripts/package-release.sh

install:
	./scripts/install-local.sh

clean:
	swift package clean
	rm -rf dist/SpritePetStudio.app
	rm -f dist/SpritePetStudio-macOS.zip dist/SpritePetStudio-macOS.zip.sha256
