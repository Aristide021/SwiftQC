# SwiftQCCLI Makefile
# Provides convenient targets for building and running the CLI with XCTest libraries

# Xcode paths for XCTest libraries
XCODE_PLATFORM_PATH = /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer
XCODE_LIB_PATH = $(XCODE_PLATFORM_PATH)/usr/lib
XCODE_FRAMEWORKS_PATH = $(XCODE_PLATFORM_PATH)/Library/Frameworks
XCODE_PRIVATE_FRAMEWORKS_PATH = $(XCODE_PLATFORM_PATH)/Library/PrivateFrameworks

# Export required environment variables
export DYLD_LIBRARY_PATH = $(XCODE_LIB_PATH)
export DYLD_FRAMEWORK_PATH = $(XCODE_FRAMEWORKS_PATH):$(XCODE_PRIVATE_FRAMEWORKS_PATH)

# Default target
.PHONY: help
help:
	@echo "SwiftQC CLI Build and Run Commands:"
	@echo ""
	@echo "  build          - Build the SwiftQC CLI"
	@echo "  run            - Run SwiftQC CLI with sample properties"
	@echo "  run-help       - Show SwiftQC CLI help"
	@echo "  run-examples   - Show SwiftQC CLI examples"
	@echo "  run-interactive - Start interactive SwiftQC session"
	@echo "  clean          - Clean build artifacts"
	@echo "  test           - Run SwiftQC tests"
	@echo ""
	@echo "Run 'make run ARGS=\"your-args-here\"' to pass custom arguments"

.PHONY: build
build:
	swift build --target SwiftQCCLI

.PHONY: run
run: build
	DYLD_LIBRARY_PATH="$(XCODE_LIB_PATH)" \
	DYLD_FRAMEWORK_PATH="$(XCODE_FRAMEWORKS_PATH):$(XCODE_PRIVATE_FRAMEWORKS_PATH)" \
	./.build/debug/SwiftQCCLI $(ARGS)

.PHONY: run-help
run-help: build
	DYLD_LIBRARY_PATH="$(XCODE_LIB_PATH)" \
	DYLD_FRAMEWORK_PATH="$(XCODE_FRAMEWORKS_PATH):$(XCODE_PRIVATE_FRAMEWORKS_PATH)" \
	./.build/debug/SwiftQCCLI --help

.PHONY: run-examples
run-examples: build
	DYLD_LIBRARY_PATH="$(XCODE_LIB_PATH)" \
	DYLD_FRAMEWORK_PATH="$(XCODE_FRAMEWORKS_PATH):$(XCODE_PRIVATE_FRAMEWORKS_PATH)" \
	./.build/debug/SwiftQCCLI examples

.PHONY: run-interactive
run-interactive: build
	DYLD_LIBRARY_PATH="$(XCODE_LIB_PATH)" \
	DYLD_FRAMEWORK_PATH="$(XCODE_FRAMEWORKS_PATH):$(XCODE_PRIVATE_FRAMEWORKS_PATH)" \
	./.build/debug/SwiftQCCLI interactive

.PHONY: run-sample
run-sample: build
	DYLD_LIBRARY_PATH="$(XCODE_LIB_PATH)" \
	DYLD_FRAMEWORK_PATH="$(XCODE_FRAMEWORKS_PATH):$(XCODE_PRIVATE_FRAMEWORKS_PATH)" \
	./.build/debug/SwiftQCCLI run --count 5 --properties=integers

.PHONY: clean
clean:
	swift package clean

.PHONY: test
test:
	swift test 