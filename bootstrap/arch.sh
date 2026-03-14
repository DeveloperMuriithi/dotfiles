#!/usr/bin/env bash
set -e

echo "Installing Arch packages via pacman..."

# Ensure system is up-to-date first
sudo pacman -Syu --noconfirm

# Install essentials
echo "Installing system essentials..."
sudo pacman -S --needed --noconfirm git stow curl wget

# Loop through resources.txt
while IFS=: read -r app macOS_cmd Arch_cmd; do
  # Skip empty lines
  [[ -z "$app" ]] && continue
  [[ "$Arch_cmd" == "N/A" ]] && continue

  cmd="$Arch_cmd"

  # Wrap pacman installs
  if [[ "$cmd" =~ "pacman -S" ]]; then
    cmd="${cmd//pacman -S/pacman -S --needed --noconfirm}"
  fi

  # Wrap yay installs
  if [[ "$cmd" =~ "yay -S" ]]; then
    cmd="${cmd//yay -S/yay -S --needed --noconfirm}"
  fi

  echo "[RUN] $cmd"
  eval "$cmd"

done <~/dotfiles/resources.toml
