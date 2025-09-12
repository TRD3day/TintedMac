# TintedMac Makefile
# Build automation for TintedMac project

# Variables
PROJECT_NAME = TintedMac
BUILD_DIR = .build
DYLIB_PATH = $(BUILD_DIR)/universal/debug/libTintedMacInject.dylib
INSTALL_PATH = /var/ammonia/core/tweaks

# Default target
.PHONY: all
all: build

# Build all targets
.PHONY: build
build: tintedmac tintedmacinject tintedmachelper sign-helper

# Build TintedMac GUI application
.PHONY: tintedmac
tintedmac:
	@echo "Building TintedMac GUI application..."
	swift build --product TintedMac

# Build TintedMacInject dynamic library
.PHONY: tintedmacinject
tintedmacinject:
	@echo "Building TintedMacInject for multiple architectures..."
	@echo "Building for arm64..."
	swift build --arch arm64 --product TintedMacInject
	@echo "Building for arm64e..."
	swift build --arch arm64e --product TintedMacInject
	@echo "Building for x86_64..."
	swift build --arch x86_64 --product TintedMacInject
	@echo "Creating universal binary..."
	@mkdir -p $(BUILD_DIR)/universal/debug
	lipo -create \
		$(BUILD_DIR)/arm64-apple-macosx/debug/libTintedMacInject.dylib \
		$(BUILD_DIR)/arm64e-apple-macosx/debug/libTintedMacInject.dylib \
		$(BUILD_DIR)/x86_64-apple-macosx/debug/libTintedMacInject.dylib \
		-output $(BUILD_DIR)/universal/debug/libTintedMacInject.dylib
	@echo "Code signing TintedMacInject..."
	codesign --force --sign - --entitlements Resources/TintedMacInject.entitlements $(BUILD_DIR)/universal/debug/libTintedMacInject.dylib
	@echo "Universal TintedMacInject binary created successfully!"

# Build TintedMacHelper
.PHONY: tintedmachelper
tintedmachelper:
	@echo "Building TintedMacHelper..."
	swift build --product TintedMacHelper

# Code sign TintedMacHelper for XPC connections
.PHONY: sign-helper
sign-helper: tintedmachelper
	@echo "Code signing TintedMacHelper..."
	codesign --force --sign - --entitlements Resources/TintedMacHelper.entitlements .build/debug/TintedMacHelper
	@echo "TintedMacHelper signed successfully!"

# Run the GUI theme customizer application
.PHONY: run
run: tintedmac
	@echo "Running $(PROJECT_NAME) GUI theme customizer..."
	swift run $(PROJECT_NAME)

# Install the tweak and helper to system
.PHONY: install
install: build
	@echo "Installing TintedMac to $(INSTALL_PATH)..."
	sudo mkdir -p $(INSTALL_PATH)
	sudo rm -f $(INSTALL_PATH)/TintedMac.dylib $(INSTALL_PATH)/TintedMac.dylib.blacklist
	sudo cp $(DYLIB_PATH) $(INSTALL_PATH)/TintedMac.dylib
	@echo "Code signing TintedMac.dylib..."
	sudo codesign --force --sign - --entitlements Resources/TintedMacInject.entitlements $(INSTALL_PATH)/TintedMac.dylib
	@if [ -f "Resources/TintedMacInject.dylib.blacklist" ]; then \
		sudo cp Resources/TintedMacInject.dylib.blacklist $(INSTALL_PATH)/TintedMac.dylib.blacklist; \
	fi
	sudo chown root:wheel $(INSTALL_PATH)/TintedMac.dylib
	sudo chmod 755 $(INSTALL_PATH)/TintedMac.dylib
	@if [ -f "$(INSTALL_PATH)/TintedMac.dylib.blacklist" ]; then \
		sudo chown root:wheel $(INSTALL_PATH)/TintedMac.dylib.blacklist; \
		sudo chmod 644 $(INSTALL_PATH)/TintedMac.dylib.blacklist; \
	fi
	@echo "TintedMac dylib installed successfully!"
	@echo "Installing TintedMacHelper..."
	@echo "Building TintedMacHelper..."
	swift build --product TintedMacHelper --configuration release
	@echo "Code signing TintedMacHelper..."
	codesign --force --sign - --entitlements Resources/TintedMacHelper.entitlements .build/release/TintedMacHelper
	@echo "Installing TintedMacHelper to /usr/local/bin..."
	sudo mkdir -p /usr/local/bin
	sudo cp .build/release/TintedMacHelper /usr/local/bin/TintedMacHelper
	sudo chmod +x /usr/local/bin/TintedMacHelper
	sudo chown root:wheel /usr/local/bin/TintedMacHelper
	@echo "Installing LaunchAgent..."
	mkdir -p "$$HOME/Library/LaunchAgents"
	cp Resources/com.aspauldingcode.TintedMac.helper.xpc.plist "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist"
	@echo "Loading LaunchAgent..."
	launchctl unload "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist" 2>/dev/null || true
	launchctl load "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist"
	@echo "TintedMac and TintedMacHelper installed successfully!"

# Uninstall everything from system
.PHONY: uninstall
uninstall:
	@echo "Uninstalling TintedMac from system..."
	sudo rm -f $(INSTALL_PATH)/TintedMac.dylib
	sudo rm -f $(INSTALL_PATH)/TintedMac.dylib.blacklist
	@echo "Uninstalling TintedMacHelper..."
	@if [ -f "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.plist" ]; then \
		echo "Unloading LaunchAgent..."; \
	fi
	@if [ -f "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist" ]; then \
		launchctl unload "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist" 2>/dev/null || true; \
	fi
	@if [ -f "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist" ]; then \
		echo "Removing LaunchAgent plist..."; \
	fi
	@if [ -f "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist" ]; then \
		rm -f "$$HOME/Library/LaunchAgents/com.aspauldingcode.TintedMac.helper.xpc.plist"; \
	else \
		echo "LaunchAgent plist not found, skipping..."; \
	fi
	@if [ -f "/usr/local/bin/TintedMacHelper" ]; then \
		echo "Removing TintedMacHelper binary..."; \
	fi
	@if [ -f "/usr/local/bin/TintedMacHelper" ]; then \
		sudo rm -f /usr/local/bin/TintedMacHelper; \
	else \
		echo "TintedMacHelper binary not found, skipping..."; \
	fi
	@if [ -f "/tmp/tintedmac-helper.log" ]; then \
		echo "Removing log file..."; \
	fi
	@if [ -f "/tmp/tintedmac-helper.log" ]; then \
		rm -f /tmp/tintedmac-helper.log; \
	fi
	@echo "TintedMac and TintedMacHelper uninstalled successfully!"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	@echo "Clean completed successfully!"

# Help
.PHONY: help
help:
	@echo "TintedMac Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  build         - Build all targets"
	@echo "  tintedmac     - Build TintedMac GUI application"
	@echo "  tintedmacinject - Build TintedMacInject dynamic library"
	@echo "  tintedmachelper - Build TintedMacHelper utility"
	@echo "  run           - Run the TintedMac GUI application"
	@echo "  install       - Install tweak and helper to system"
	@echo "  uninstall     - Uninstall everything from system"
	@echo "  clean         - Remove build artifacts and test files"
	@echo "  help          - Show this help message"
