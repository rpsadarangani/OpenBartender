.PHONY: build app run debug clean zip icon

APP := OpenBartender.app

## Compile the release binary
build:
	swift build -c release

## Assemble OpenBartender.app
app:
	./scripts/build-app.sh release

## Build and launch the app
run: app
	open $(APP)

## Build a debug binary (faster, for development)
debug:
	swift build -c debug

## Regenerate the app icon
icon:
	rm -rf build/AppIcon.iconset
	swift scripts/make-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

## Package a distributable zip
zip: app
	ditto -c -k --sequesterRsrc --keepParent $(APP) OpenBartender.zip
	@echo "Created OpenBartender.zip"

## Remove build artifacts
clean:
	rm -rf .build build $(APP) OpenBartender.zip
