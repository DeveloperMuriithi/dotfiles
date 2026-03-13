#!/usr/bin/env bash
set -e

echo "Linking configs via stow..."
for dir in zsh kitty starship wezterm yabai; do
    stow -v -t $HOME $dir
done
