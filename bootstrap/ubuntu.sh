#!/usr/bin/env bash
set -e

echo "  → Updating apt..."
sudo apt update

echo "  → Installing core tools..."
sudo apt install -y build-essential curl git stow
