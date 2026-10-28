#!/usr/bin/env bash
# Build and install Caido from the AUR (Arch Linux only).
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "⚠ install_caido.sh requires an Arch-based system (pacman not found)." >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  echo "⚠ Run this script as your normal user, not as root (makepkg refuses root)." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1 || ! command -v makepkg >/dev/null 2>&1; then
  echo "⚠ git and base-devel (makepkg) are required." >&2
  exit 1
fi

sudo pacman -S --needed --noconfirm git base-devel fuse2

BUILD_DIR="${TMPDIR:-/tmp}/caido-desktop-build"
rm -rf "$BUILD_DIR"

git clone https://aur.archlinux.org/caido-desktop.git "$BUILD_DIR"
cd "$BUILD_DIR"
makepkg -si --noconfirm
