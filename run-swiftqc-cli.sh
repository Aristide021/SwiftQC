#!/bin/bash

# SwiftQC CLI Runner with XCTest Libraries
# This script sets up the necessary library paths to run SwiftQC CLI
# Note: We renamed main.swift to SwiftQCCLI.swift to avoid @main conflicts

export DYLD_LIBRARY_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib"
export DYLD_FRAMEWORK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks:/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"

# Run the SwiftQC CLI with all arguments passed through
./.build/debug/SwiftQCCLI "$@" 