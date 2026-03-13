#!/usr/bin/env bash
set -e

echo "Installing Arch packages via pacman..."

while read -r pkg; do
    [[ -z "$pkg" ]] && continue

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] sudo pacman -S --needed $pkg"
    else
        sudo pacman -S --needed "$pkg"
    fi
done < "$HOME/dotfiles/pkg/pacman.txt"

