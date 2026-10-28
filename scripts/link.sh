#!/usr/bin/env bash
# Link this repository's dotfile packages with GNU Stow.
#
# Usage:
#   ./scripts/link.sh [--shell bash|zsh|fish] [--dry-run]
#
# This is the manual, thin wrapper. install.sh additionally installs packages
# and can back up conflicting files before linking.
set -euo pipefail

DRY_RUN=false
SHELL_CHOICE=""

usage() {
  cat <<'EOF'
Usage: ./scripts/link.sh [--shell bash|zsh|fish] [--dry-run]

  --shell <name>  Link this shell's config (default: your login shell).
  --dry-run       Show the Stow commands without changing anything.
EOF
}

while (($# > 0)); do
  case "$1" in
  --dry-run) DRY_RUN=true ;;
  --shell)
    [[ $# -ge 2 ]] || { echo "--shell needs a value" >&2; exit 2; }
    SHELL_CHOICE="$2"
    shift 2
    continue
    ;;
  --shell=*) SHELL_CHOICE="${1#*=}" ;;
  -h | --help) usage; exit 0 ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

valid_shell() {
  case "$1" in
  bash | zsh | fish) return 0 ;;
  *) return 1 ;;
  esac
}

if [[ -z "$SHELL_CHOICE" ]]; then
  SHELL_CHOICE="$(basename "${SHELL:-}")"
fi
SHELL_CHOICE="${SHELL_CHOICE,,}"
if ! valid_shell "$SHELL_CHOICE"; then
  echo "Unsupported shell: '$SHELL_CHOICE' (choose bash, zsh, or fish)." >&2
  exit 2
fi

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGES=(starship kitty wezterm nvim "$SHELL_CHOICE")
[[ "$(uname)" == "Darwin" ]] && PACKAGES+=(yabai)
FAILED=0

if ! command -v stow >/dev/null 2>&1; then
  echo "⚠ GNU Stow is not installed — install it first." >&2
  exit 1
fi

echo "Linking configs via stow (shell: $SHELL_CHOICE)..."

# Remove links owned by Stow for the shells that were not selected.
for other in bash zsh fish; do
  [[ "$other" == "$SHELL_CHOICE" ]] && continue
  [[ -d "$DOTFILES/$other" ]] || continue
  if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY RUN] stow -D -d $DOTFILES -t $HOME $other"
  else
    stow -D -d "$DOTFILES" -t "$HOME" --ignore='.stow-target' "$other" >/dev/null 2>&1 || true
  fi
done

for dir in "${PACKAGES[@]}"; do
  if [[ ! -d "$DOTFILES/$dir" ]]; then
    echo "  ⚠ Missing package directory: $DOTFILES/$dir" >&2
    FAILED=1
    continue
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY RUN] stow -d $DOTFILES -t $HOME --ignore='.stow-target' $dir"
    continue
  fi

  rc=0
  stow -d "$DOTFILES" -t "$HOME" --ignore='.stow-target' "$dir" || rc=$?
  if ((rc == 0)); then
    echo "  ✔ Stowed $dir"
  else
    echo "  ⚠ stow failed for $dir (exit code $rc) — resolve the conflict and re-run" >&2
    echo "     To back up conflicting files automatically, use: ./install.sh --backup-existing --shell $SHELL_CHOICE" >&2
    FAILED=1
  fi
done

exit "$FAILED"
