#!/bin/bash

# Define your publish-only exclusions here
EXTRA_IGNORES=(
  "test/"
  "*.sh"
)

# Check if .gitignore exists
if [ ! -f .gitignore ]; then
  echo "❌ Error: .gitignore not found!"
  exit 1
fi

# 1. Copy .gitignore contents
echo "# Automatically generated from .gitignore" > .pubignore
cat .gitignore >> .pubignore

# 2. Append extra publish-only ignores
echo -e "\n# Extra pub-only exclusions" >> .pubignore
for item in "${EXTRA_IGNORES[@]}"; do
  echo "$item" >> .pubignore
done

echo "✅ Success: .pubignore generated."

