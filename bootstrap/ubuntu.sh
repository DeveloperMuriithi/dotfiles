#!/usr/bin/env bash
# Debian-family bootstrap (Ubuntu, Debian, Kali Linux).
set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

export DEBIAN_FRONTEND=noninteractive

if [[ "$DRY_RUN" == true ]]; then
  echo "  [DRY RUN] sudo apt update"
  echo "  [DRY RUN] sudo apt install -y build-essential curl git stow"
  exit 0
fi

echo "  → Updating apt..."
sudo apt update

echo "  → Installing core tools..."
sudo apt install -y build-essential curl git stow
