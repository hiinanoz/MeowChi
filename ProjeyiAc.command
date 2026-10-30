#!/bin/bash
# Generates Meowchi.xcodeproj from project.yml with XcodeGen and opens it (double-click in Finder).
# On CI it only generates. Run again after adding, moving or deleting files.
set -e
cd "$(dirname "$0")"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "XcodeGen is missing. Install Homebrew (https://brew.sh), then run: brew install xcodegen"
    exit 1
  fi
fi
xcodegen generate
if [ -z "$CI" ]; then open Meowchi.xcodeproj; fi
