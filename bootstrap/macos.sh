#!/usr/bin/env bash
# macOS bootstrap (Homebrew).
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

echo "Running macOS bootstrap..."

# Install Homebrew if missing
if command -v brew >/dev/null 2>&1; then
  echo "Homebrew already installed."
elif [[ "$DRY_RUN" == true ]]; then
  echo "  [DRY RUN] install Homebrew from https://brew.sh"
else
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
