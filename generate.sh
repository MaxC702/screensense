#!/usr/bin/env bash
# Regenerates ScreenSense.xcodeproj from project.yml.
# The project file is not committed, so run this after cloning or pulling.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install it with:  brew install xcodegen" >&2
  exit 1
fi

xcodegen generate
echo "Done. Open ScreenSense.xcodeproj and run on a physical device."
