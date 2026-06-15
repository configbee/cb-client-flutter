#!/bin/bash
# Generates lib/src/sdk_version.g.dart from pubspec.yaml
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //')
OUTPUT="lib/src/sdk_version.g.dart"
echo "const String sdkVersion = '$VERSION';" > "$OUTPUT"
echo "Generated $OUTPUT (sdkVersion = $VERSION)"
