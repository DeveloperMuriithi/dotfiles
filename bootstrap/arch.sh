#!/usr/bin/env bash
# Arch Linux bootstrap.
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [[ "$DRY_RUN" == true ]]; then
  echo "  [DRY RUN] sudo pacman -Syu --noconfirm"
  echo "  [DRY RUN] sudo pacman -S --needed --noconfirm git stow curl wget"
  exit 0
fi

echo "Installing Arch packages via pacman..."

# Ensure system is up-to-date first
sudo pacman -Syu --noconfirm

# Install essentials
echo "Installing system essentials..."
sudo pacman -S --needed --noconfirm git stow curl wget

# AUR helper is needed for the yay entries in resources.toml. Do not install
# one automatically; just make the limitation visible.
if ! command -v yay >/dev/null 2>&1; then
  echo "  ⚠ yay not found — AUR packages will fail until an AUR helper is installed."
fi
