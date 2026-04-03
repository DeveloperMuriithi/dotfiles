#!/usr/bin/env bash
# install.sh — Cross-platform dotfiles bootstrapper
# Supports: macOS (Homebrew) and Arch Linux (pacman + yay)
# Usage:
#   ./install.sh            — normal run
#   ./install.sh --dry-run  — preview commands without executing

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname)"
DISTRO=""

if [[ "$OS" == "Linux" ]]; then
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="$ID"
  fi
fi

LOG="$DOTFILES/.installed.log"
RESOURCES="$DOTFILES/resources.toml"

# ─── Sanity checks ───────────────────────────────────────────────────────────

if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
  echo "❌ Unsupported OS: $OS. Only macOS (Darwin) and Arch Linux are supported."
  exit 1
fi

if [[ ! -f "$RESOURCES" ]]; then
  echo "❌ resources.toml not found at: $RESOURCES"
  exit 1
fi

mkdir -p "$DOTFILES"
touch "$LOG"

# ─── Error tracing ───────────────────────────────────────────────────────────

trap 'echo ""; echo "❌ Installer failed at line $LINENO"; echo "   Command: $BASH_COMMAND"; exit 1' ERR

# ─── Logging helpers ─────────────────────────────────────────────────────────

info() { echo "  ℹ $*"; }
success() { echo "  ✔ $*"; }
warn() { echo "  ⚠ $*"; }
skip() { echo "  ↩ $*"; }

# ─── TOML parser ─────────────────────────────────────────────────────────────
# Minimal parser: reads [app] sections and extracts macos/arch values.
# Stores results in associative arrays: MACOS_CMDS and ARCH_CMDS.

declare -A MACOS_CMDS
declare -A ARCH_CMDS
declare -A UBUNTU_CMDS

parse_resources() {
  local current_app=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip inline comments
    line="${line%%#*}"
    # Trim leading/trailing whitespace WITHOUT xargs (xargs strips quotes)
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    # Section header: [app_name]
    if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
      current_app="${BASH_REMATCH[1]}"
      continue
    fi

    [[ -z "$current_app" ]] && continue

    # macos = "..."
    if [[ "$line" =~ ^macos[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      MACOS_CMDS["$current_app"]="${BASH_REMATCH[1]}"
    fi

    # arch = "..."
    if [[ "$line" =~ ^arch[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      ARCH_CMDS["$current_app"]="${BASH_REMATCH[1]}"
    fi

    # ubuntu = "..."
    if [[ "$line" =~ ^ubuntu[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      UBUNTU_CMDS["$current_app"]="${BASH_REMATCH[1]}"
    fi

  done <"$RESOURCES"
}

# ─── Command builder ─────────────────────────────────────────────────────────
# Normalises a raw command from resources.toml into a safe, runnable string.
# On Linux: strips any flags already in the command, extracts the package name,
# then rebuilds with sudo + --needed + --noconfirm.
# Chained commands (&&) pass through unchanged on both platforms.

build_command() {
  local raw="$1"

  if [[ "$OS" == "Linux" ]]; then

    # ─── Arch ─────────────────────────────
    if [[ "$DISTRO" == "arch" ]]; then
      if [[ "$raw" == pacman* ]]; then
        local pkg
        pkg=$(echo "$raw" |
          sed 's/^pacman[[:space:]]*-S[[:space:]]*//' |
          sed 's/--needed//g' |
          sed 's/--noconfirm//g' |
          xargs)
        echo "sudo pacman -S --needed --noconfirm $pkg"
        return
      fi

      if [[ "$raw" == yay* ]]; then
        local pkg
        pkg=$(echo "$raw" |
          sed 's/^yay[[:space:]]*-S[[:space:]]*//' |
          sed 's/--needed//g' |
          sed 's/--noconfirm//g' |
          xargs)
        echo "yay -S --needed --noconfirm $pkg"
        return
      fi
    fi

    # ─── Ubuntu / Debian ──────────────────
    if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
      if [[ "$raw" == apt* ]]; then
        local pkg
        pkg=$(echo "$raw" |
          sed 's/^apt[[:space:]]*install[[:space:]]*//' |
          sed 's/-y//g' |
          xargs)

        echo "sudo apt update && sudo apt install -y $pkg"
        return
      fi
    fi
  fi

  echo "$raw"
}


# ─── Install dispatcher ──────────────────────────────────────────────────────

install_app() {
  local app="$1"
  local raw_cmd="$2"

  # Skip N/A entries
  if [[ "$raw_cmd" == "N/A" || -z "$raw_cmd" ]]; then
    return
  fi

  # Skip already-installed apps (log check is fast; --needed is the safety net)
  if grep -Fxq "$app" "$LOG"; then
    skip "$app (already installed)"
    return
  fi

  local cmd
  cmd=$(build_command "$raw_cmd")

  if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY RUN] $cmd"
    return
  fi

  info "Installing $app..."
  echo "  → $cmd"

  # Execute in a subshell to prevent environment pollution.
  # && ensures we only log the app on success.
  if (bash -c "$cmd"); then
    echo "$app" >>"$LOG"
    success "$app installed"
  else
    warn "$app install failed — skipping (exit code: $?)"
  fi
}

# ─── Category runner ─────────────────────────────────────────────────────────

install_category() {
  local category_file="$1"
  local category_name
  category_name=$(basename "$category_file" .txt)

  if [[ ! -f "$category_file" ]]; then
    warn "Category file not found: $category_file"
    return
  fi

  echo ""
  echo "▶ Category: $category_name"

  while IFS= read -r app || [[ -n "$app" ]]; do
    # Skip comments and blank lines
    [[ "$app" =~ ^[[:space:]]*# || -z "${app// /}" ]] && continue
    app="$(echo "$app" | xargs)"

    local cmd=""
    if [[ "$OS" == "Darwin" ]]; then
  cmd="${MACOS_CMDS[$app]:-}"

  elif [[ "$OS" == "Linux" ]]; then
    case "$DISTRO" in
      arch)
        cmd="${ARCH_CMDS[$app]:-}"
        ;;
      ubuntu|debian)
        cmd="${UBUNTU_CMDS[$app]:-}"
        ;;
      *)
        warn "Unsupported Linux distro: $DISTRO"
        return
        ;;
    esac
  fi


    if [[ -z "$cmd" ]]; then
      warn "No install entry found for '$app' in resources.toml"
      continue
    fi

    install_app "$app" "$cmd"
  done <"$category_file"
}

# ─── Bootstrap ───────────────────────────────────────────────────────────────

run_bootstrap() {
  echo ""
  echo "▶ Bootstrap"

  if [[ "$OS" == "Darwin" ]]; then
    bash "$DOTFILES/bootstrap/macos.sh"

  elif [[ "$OS" == "Linux" ]]; then
    case "$DISTRO" in
      arch)
        bash "$DOTFILES/bootstrap/arch.sh"
        ;;
      ubuntu|debian)
        bash "$DOTFILES/bootstrap/ubuntu.sh"
        ;;
      *)
        warn "No bootstrap for distro: $DISTRO"
        ;;
    esac
  fi
}


# ─── Main ────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       Dotfiles Installer             ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  OS:       $OS"
echo "  Distro:   ${DISTRO:-N/A}"
echo "  Dotfiles: $DOTFILES"
echo "  Log:      $LOG"
[[ "$DRY_RUN" == true ]] && echo "  Mode:     DRY RUN (no changes will be made)"
echo ""

# 1. Parse resources.toml
parse_resources
info "Loaded ${#MACOS_CMDS[@]} macOS, ${#ARCH_CMDS[@]} Arch, ${#UBUNTU_CMDS[@]} Ubuntu entries"

# 2. Bootstrap package manager
run_bootstrap

# 3. Auto-install essential categories
echo ""
echo "━━━ Essential packages ━━━━━━━━━━━━━━━━━━"
install_category "$DOTFILES/categories/system.txt"
install_category "$DOTFILES/categories/core.txt"

# 4. Platform-specific category
echo ""
echo "━━━ Platform packages ━━━━━━━━━━━━━━━━━━━"
if [[ "$OS" == "Darwin" ]]; then
  install_category "$DOTFILES/categories/macOS.txt"

elif [[ "$OS" == "Linux" ]]; then
  case "$DISTRO" in
    arch)
      install_category "$DOTFILES/categories/arch.txt"
      ;;
    ubuntu|debian)
      # optional: create ubuntu.txt later
      ;;
  esac
fi


# 5. Optional categories — prompt user
echo ""
echo "━━━ Optional categories ━━━━━━━━━━━━━━━━━"

SKIP_CATEGORIES=("core" "macOS" "arch" "system")

for category_file in "$DOTFILES"/categories/*.txt; do
  category_name=$(basename "$category_file" .txt)

  # Skip auto-installed categories
  skip=false
  for s in "${SKIP_CATEGORIES[@]}"; do
    [[ "$category_name" == "$s" ]] && skip=true && break
  done
  $skip && continue

  read -rp "  Install '$category_name'? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    install_category "$category_file"
  else
    info "Skipped '$category_name'"
  fi
done

# 6. Apply dotfiles via stow
echo ""
echo "━━━ Applying dotfiles (stow) ━━━━━━━━━━━━"
for dir in "$DOTFILES"/*/; do
  dir_name=$(basename "$dir")
  if [[ -d "$dir" && -f "$dir/.stow-target" ]]; then
    info "Stowing $dir_name..."
    stow -v -t "$HOME" "$dir_name" || warn "stow failed for $dir_name"
  fi
done

# 7. Git setup
echo ""
echo "━━━ Git setup ━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$DOTFILES/git/gitsetup.sh"

# 8. Done
echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✔  Setup complete!                  ║"
echo "╚══════════════════════════════════════╝"
echo ""
