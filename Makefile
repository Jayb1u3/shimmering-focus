.PHONY: build

build:
	[[ "$$OSTYPE" =~ "darwin" ]] && osascript -e 'display notification "Building…" with title "Shimmering Focus"' ; \
	zsh ./build.sh
