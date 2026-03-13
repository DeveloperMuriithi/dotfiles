#!/usr/bin/env bash
DRY_RUN=${1:-false}

set -e

DOTFILES="$HOME/dotfiles"
OS="$(uname)"
LOG="$DOTFILES/.installed.log"

echo "Starting category-aware installer..."
echo "Detected OS: $OS"

# Ensure log exists
touch "$LOG"

echo "Running bootstrap..."
if [[ "$OS" == "Darwin" ]]; then
  bash "$DOTFILES/bootstrap/macos.sh"
else
  bash "$DOTFILES/bootstrap/arch.sh"
fi

# --- Dispatcher function ---
install_app() {
  local app="$1"
  local method="$2"

  [[ "$method" == "N/A" || -z "$method" ]] && return

  # Skip if already installed
  if grep -Fxq "$app" "$LOG"; then
    echo "[SKIP] $app already installed"
    return
  fi

  # Wrap Linux installs with sudo + flags
  if [[ "$OS" == "Linux" ]]; then
    if [[ "$method" =~ ^pacman ]]; then
      method="sudo $method --needed --noconfirm"
    elif [[ "$method" =~ ^yay ]]; then
      method="sudo $method --needed --noconfirm"
    fi
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] $method"
  else
    echo "[RUN] $method"
    eval "$method"
    echo "$app" >>"$LOG"
  fi
}

# --- Read resources ---
declare -A resources
while IFS=: read -r app macOS_method arch_method; do
  [[ -z "$app" ]] && continue
  app=$(echo "$app" | xargs)

  if [[ "$OS" == "Darwin" ]]; then
    resources["$app"]="$macOS_method"
  else
    resources["$app"]="$arch_method"
  fi
done <"$DOTFILES/resources.txt"

# --- Install a category ---
install_category() {
  local category_file="$1"
  while read -r app; do
    [[ "$app" =~ ^#.*$ || -z "$app" ]] && continue
    method="${resources[$app]}"
    if [[ -z "$method" ]]; then
      echo "⚠ No install method defined for '$app'"
      continue
    fi
    install_app "$app" "$method"
  done <"$category_file"
}

# --- Auto-install essential categories ---
echo "Installing system essentials..."
install_category "$DOTFILES/categories/system.txt"

echo "Installing core apps..."
install_category "$DOTFILES/categories/core.txt"

if [[ "$OS" == "Darwin" ]]; then
  echo "Installing macOS-specific apps..."
  install_category "$DOTFILES/categories/macOS.txt"
else
  echo "Installing Arch-specific apps..."
  install_category "$DOTFILES/categories/arch.txt"
fi

# --- Optional categories prompt ---
for category_file in "$DOTFILES"/categories/*.txt; do
  category_name=$(basename "$category_file" .txt)
  [[ "$category_name" == "core" || "$category_name" == "macOS" || "$category_name" == "arch" || "$category_name" == "system" ]] && continue

  read -rp "Do you want to install category '$category_name'? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    install_category "$category_file"
  fi
done

# --- Dynamic stow for config directories ---
for dir in "$DOTFILES"/*/; do
  dir_name=$(basename "$dir")
  [[ -d "$dir" && -f "$dir/.stow-target" ]] && stow -v -t "$HOME" "$dir_name"
done

# --- Git setup ---
echo "Setting up Git..."
bash git/gitsetup.sh

echo "Dotfiles setup complete!"
