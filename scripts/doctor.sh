#!/usr/bin/env bash
echo "Checking essential commands..."
for cmd in git zsh kitty tmux stow; do
    if ! command -v $cmd &> /dev/null; then
        echo "⚠ $cmd is missing"
    else
        echo "✔ $cmd found"
    fi
done
