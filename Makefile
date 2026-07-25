.PHONY: build test check fix

build:
	swift build --quiet

test:
	swift test --quiet

check:
	mise x -- hk check

fix:
	mise x -- hk fix
