#!/usr/bin/env bash
# Report which essential commands are available.
set -uo pipefail

shell_name="$(basename "${SHELL:-bash}")"
case "$shell_name" in
bash | zsh | fish) ;;
*) shell_name="zsh" ;;
esac

echo "Checking essential commands (shell: $shell_name)..."
missing=0
for cmd in git stow starship tmux nvim "$shell_name"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "⚠ $cmd is missing"
    missing=$((missing + 1))
  else
    echo "✔ $cmd found"
  fi
done

exit $((missing > 0))
