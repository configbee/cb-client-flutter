#!/bin/bash
# Generates .pubignore from .gitignore with extra publish-only exclusions
set -euo pipefail
cd "$(dirname "$0")/.."

EXTRA_IGNORES=(
  "test/"
  "tool/*.sh"
)

echo "# Automatically generated from .gitignore" > .pubignore
cat .gitignore >> .pubignore

echo -e "\n# Extra pub-only exclusions" >> .pubignore
for item in "${EXTRA_IGNORES[@]}"; do
  echo "$item" >> .pubignore
done

echo "Generated .pubignore"

