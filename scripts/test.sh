#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_NAME="$(grep '^name:' project.yml | awk '{print $2}')"

echo "==> Generating Xcode project..."
xcodegen generate --quiet

echo "==> Running tests (macOS)..."
xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${PROJECT_NAME}" \
    -destination 'platform=macOS' \
    -quiet \
    test

echo "==> All tests passed."
