#!/bin/bash
# Prepares package for publishing: generate files, analyze, dry-run
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Generating version file ==="
bash tool/generate_version.sh

echo ""
echo "=== Generating .pubignore ==="
bash tool/generate_pubignore.sh

echo ""
echo "=== flutter analyze ==="
flutter analyze

echo ""
echo "=== flutter pub publish --dry-run ==="
flutter pub publish --dry-run

echo ""
echo "All checks passed. Ready to publish."
