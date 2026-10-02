APP_DIR    ?= /Applications
APP        := $(APP_DIR)/Mullion.app
# Before Mullion added itself to Login Items, `make install` started it with this LaunchAgent.
OLD_AGENT  := $(HOME)/Library/LaunchAgents/com.marcneuwirth.mullion.plist
QUIT       := pkill -x Mullion; while pgrep -qx Mullion; do sleep 0.1; done

.PHONY: build test check install uninstall restart logs release

build:
	scripts/bundle.sh

test:
	swift test

# Validate ~/.config/mullion/config.json without restarting anything.
check: build
	build/Mullion.app/Contents/MacOS/Mullion --check

# Opening the app adds it to Login Items on first launch.
install: build
	-launchctl bootout gui/$(shell id -u)/com.marcneuwirth.mullion 2>/dev/null
	rm -f "$(OLD_AGENT)"
	-$(QUIT)
	rm -rf "$(APP)"
	cp -R build/Mullion.app "$(APP)"
	open "$(APP)"
	@echo "Installed. Grant Accessibility access if prompted."

uninstall:
	-"$(APP)/Contents/MacOS/Mullion" --unregister
	-$(QUIT)
	rm -rf "$(APP)"
	@echo "Removed. Your config in ~/.config/mullion was left in place."

restart:
	-$(QUIT)
	open "$(APP)"

logs:
	tail -f "$(HOME)/Library/Logs/Mullion.log"

# Signed, notarized zip for distribution; see README, "Releasing".
release:
	scripts/release.sh
