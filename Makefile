APP_DIR    ?= /Applications
APP        := $(APP_DIR)/Mullion.app
LABEL      := com.marcneuwirth.mullion
AGENT      := $(HOME)/Library/LaunchAgents/$(LABEL).plist
DOMAIN     := gui/$(shell id -u)

.PHONY: build test check install uninstall restart logs

build:
	scripts/bundle.sh

test:
	swift test

# Validate ~/.config/mullion/config.json without restarting anything.
check: build
	build/Mullion.app/Contents/MacOS/Mullion --check

install: build
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	rm -rf "$(APP)"
	cp -R build/Mullion.app "$(APP)"
	mkdir -p "$(HOME)/Library/LaunchAgents" "$(HOME)/Library/Logs"
	sed -e 's|__APP__|$(APP)|' -e 's|__HOME__|$(HOME)|' Resources/$(LABEL).plist > "$(AGENT)"
	launchctl bootstrap $(DOMAIN) "$(AGENT)"
	@echo "Installed. Grant Accessibility access if prompted, then run 'make restart'."

uninstall:
	-launchctl bootout $(DOMAIN)/$(LABEL) 2>/dev/null
	rm -f "$(AGENT)"
	rm -rf "$(APP)"
	@echo "Removed. Your config in ~/.config/mullion was left in place."

restart:
	launchctl kickstart -k $(DOMAIN)/$(LABEL)

logs:
	tail -f "$(HOME)/Library/Logs/Mullion.log"
