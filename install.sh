#!/usr/bin/env bash
# install.sh — Cross-platform dotfiles bootstrapper
# Supports: macOS (Homebrew), Arch Linux (pacman + yay), and Debian-family
# distributions (Ubuntu, Debian, Kali Linux).
#
# Usage:
#   ./install.sh                 — normal run (prompts for a shell)
#   ./install.sh --shell fish    — choose bash, zsh, or fish up front
#   ./install.sh --dry-run       — preview actions without making changes
#
# Testing hooks (optional, non-interactive):
#   DOTFILES_OS=Linux DOTFILES_OS_RELEASE=/path/to/os-release \
#     bash -c 'source install.sh; init_platform; build_command "apt install git"'

set -euo pipefail

# Associative arrays (used by the resources parser) need Bash 4+. macOS still
# ships Bash 3.2, so re-exec a Homebrew Bash when one is available.
if ((BASH_VERSINFO[0] < 4)) && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  for _modern_bash in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [[ -x "$_modern_bash" ]]; then
      exec "$_modern_bash" "$0" "$@"
    fi
  done
  echo "❌ Bash 4 or newer is required. Install it with: brew install bash" >&2
  exit 1
fi
unset _modern_bash 2>/dev/null || true

# ─── Config ──────────────────────────────────────────────────────────────────

DRY_RUN=false
SHELL_CHOICE=""
BACKUP_EXISTING=false
BACKUP_ROOT=""
SHELL_PACKAGES=(bash zsh fish)
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="${DOTFILES_OS:-$(uname)}"
OS_RELEASE_FILE="${DOTFILES_OS_RELEASE:-/etc/os-release}"
DISTRO=""
DISTRO_LIKE=""
PLATFORM="unsupported"
PACKAGE_SUPPORT=true

if [[ "$OS" == "Linux" && -r "$OS_RELEASE_FILE" ]]; then
  # Parse only the fields we need instead of sourcing the file into our shell.
  while IFS='=' read -r key value; do
    value="${value%\"}"
    value="${value#\"}"
    case "$key" in
    ID) DISTRO="$value" ;;
    ID_LIKE) DISTRO_LIKE="$value" ;;
    esac
  done <"$OS_RELEASE_FILE"
  DISTRO="${DISTRO,,}"
  DISTRO_LIKE="${DISTRO_LIKE,,}"
fi

LOG="$DOTFILES/.installed.log"
RESOURCES="$DOTFILES/resources.toml"

# ─── Counters ────────────────────────────────────────────────────────────────

INSTALLED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
DRY_ACTIONS=0
FAILED_STEPS=()

# ─── Logging helpers ─────────────────────────────────────────────────────────

info() { echo "  ℹ $*"; }
success() { echo "  ✔ $*"; }
warn() { echo "  ⚠ $*" >&2; }
skip() { echo "  ↩ $*"; }

record_failure() {
  FAILED_COUNT=$((FAILED_COUNT + 1))
  FAILED_STEPS+=("$1")
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

usage() {
  cat <<EOF
Usage: ./install.sh [--shell bash|zsh|fish] [--dry-run] [--backup-existing]

  --shell <name>     Apply the configuration for this shell. If omitted, the
                     installer asks (or uses your current login shell when
                     non-interactive).
  --backup-existing  Back up existing files that conflict with Stow instead of
                     asking. Useful for unattended runs; the default is no.
  --dry-run          Show what would be done without installing packages,
                     running bootstrap scripts, changing Git/SSH configuration,
                     creating SSH keys, moving files, or modifying symlinks.
  -h, --help         Show this help.
EOF
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
    --dry-run) DRY_RUN=true ;;
    --backup-existing) BACKUP_EXISTING=true ;;
    --shell)
      if (($# < 2)); then
        echo "❌ --shell needs a value: bash, zsh, or fish." >&2
        exit 2
      fi
      SHELL_CHOICE="$2"
      shift 2
      continue
      ;;
    --shell=*)
      SHELL_CHOICE="${1#*=}"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    esac
    shift
  done
}

# ─── Shell selection ─────────────────────────────────────────────────────────

valid_shell() {
  case "$1" in
  bash | zsh | fish) return 0 ;;
  *) return 1 ;;
  esac
}

resolve_shell_choice() {
  local default candidate reply=""

  if [[ -n "$SHELL_CHOICE" ]]; then
    SHELL_CHOICE="${SHELL_CHOICE,,}"
    if ! valid_shell "$SHELL_CHOICE"; then
      echo "❌ Unsupported shell: '$SHELL_CHOICE' (choose bash, zsh, or fish)." >&2
      exit 2
    fi
    return 0
  fi

  candidate="$(basename "${SHELL:-}")"
  if valid_shell "$candidate"; then
    default="$candidate"
  else
    default="zsh"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    SHELL_CHOICE="$default"
    info "[DRY RUN] would use shell '$SHELL_CHOICE' (override with --shell bash|zsh|fish)"
    return 0
  fi

  if [[ -t 0 ]]; then
    while :; do
      if ! IFS= read -rp "  Choose shell [bash/zsh/fish] (default: $default): " reply; then
        reply="$default"
      fi
      reply="$(trim "$reply")"
      [[ -z "$reply" ]] && reply="$default"
      reply="${reply,,}"
      if valid_shell "$reply"; then
        SHELL_CHOICE="$reply"
        return 0
      fi
      warn "Please choose bash, zsh, or fish."
    done
  fi

  SHELL_CHOICE="$default"
  info "Using shell '$SHELL_CHOICE' (non-interactive; override with --shell bash|zsh|fish)"
}

install_selected_shell() {
  local raw
  if [[ "$PACKAGE_SUPPORT" != true ]]; then
    return 0
  fi

  raw="$(commands_for_app "$SHELL_CHOICE")"
  if [[ -z "$raw" ]]; then
    warn "No install entry for '$SHELL_CHOICE' in resources.toml — skipping shell package"
    record_failure "shell: $SHELL_CHOICE (no install entry)"
    return 0
  fi

  echo ""
  echo "▶ Shell: $SHELL_CHOICE"
  install_app "$SHELL_CHOICE" "$raw"

  if [[ "$DRY_RUN" != true ]] && ! command -v "$SHELL_CHOICE" >/dev/null 2>&1; then
    warn "$SHELL_CHOICE is still not on PATH after installation"
    record_failure "shell: $SHELL_CHOICE (not found)"
  fi
}

# ─── TOML parser ─────────────────────────────────────────────────────────────
# Minimal parser: reads [app] sections and extracts macos/arch/ubuntu values.
# Debian-family systems (including Kali) use the ubuntu commands because they
# are all APT-based.

declare -A MACOS_CMDS
declare -A ARCH_CMDS
declare -A UBUNTU_CMDS
declare -A SEEN_APPS

parse_resources() {
  local current_app=""
  local line

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip inline comments
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    # Section header: [app_name]
    if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
      current_app="${BASH_REMATCH[1]}"
      continue
    fi

    [[ -z "$current_app" ]] && continue

    if [[ "$line" =~ ^macos[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      MACOS_CMDS["$current_app"]="${BASH_REMATCH[1]}"
    fi

    if [[ "$line" =~ ^arch[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      ARCH_CMDS["$current_app"]="${BASH_REMATCH[1]}"
    fi

    if [[ "$line" =~ ^ubuntu[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
      UBUNTU_CMDS["$current_app"]="${BASH_REMATCH[1]}"
    fi
  done <"$RESOURCES"
}

# ─── Platform detection ──────────────────────────────────────────────────────

detect_platform() {
  PLATFORM="unsupported"
  PACKAGE_SUPPORT=true

  case "$OS" in
  Darwin)
    PLATFORM="macos"
    return 0
    ;;
  Linux) ;;
  *)
    PLATFORM="unsupported"
    return 0
    ;;
  esac

  case ",$DISTRO,$DISTRO_LIKE," in
  *,arch,* | *,manjaro,* | *,endeavouros,*)
    PLATFORM="arch"
    ;;
  *,ubuntu,* | *,debian,* | *,kali,* | *,linuxmint,* | *,pop,*)
    # Kali is Debian-based and uses the same APT package handling.
    PLATFORM="debian"
    ;;
  *)
    if [[ "$DISTRO_LIKE" == *arch* ]]; then
      PLATFORM="arch"
    elif [[ "$DISTRO_LIKE" == *debian* || "$DISTRO_LIKE" == *ubuntu* ]]; then
      PLATFORM="debian"
    else
      PLATFORM="unsupported"
    fi
    ;;
  esac
}

init_platform() {
  detect_platform
  if [[ "$PLATFORM" == "unsupported" && "$OS" == "Linux" ]]; then
    PACKAGE_SUPPORT=false
    warn "Unsupported Linux distribution: '${DISTRO:-unknown}'."
    warn "Package installation and bootstrap will be skipped (warned only once)."
    warn "Dotfile linking and Git setup will still be attempted."
  fi
}

# ─── Command builder ─────────────────────────────────────────────────────────
# Normalises a raw command from resources.toml into a safe, runnable string.
# Arch:   pacman/yay get --needed --noconfirm.
# Debian: apt/apt-get install gets a fresh index and -y.
# Other commands (git clone, helper scripts, brew) pass through unchanged.

strip_pkg_args() {
  local raw="$1" tool="$2" rest=""
  local -a tokens=()
  local tok

  case "$tool" in
  pacman)
    if [[ "$raw" =~ ^(sudo[[:space:]]+)?(pacman|yay)[[:space:]]+-S[^[:space:]]*[[:space:]]+(.*)$ ]]; then
      rest="${BASH_REMATCH[3]}"
    fi
    ;;
  apt)
    if [[ "$raw" =~ ^(sudo[[:space:]]+)?apt(-get)?[[:space:]]+install[[:space:]]+(.*)$ ]]; then
      rest="${BASH_REMATCH[3]}"
    fi
    ;;
  esac

  if [[ -z "$rest" ]]; then
    printf '%s' "$raw"
    return 0
  fi

  for tok in $rest; do
    case "$tok" in
    -y | --yes | --needed | --noconfirm | --no-install-recommends) ;;
    *) tokens+=("$tok") ;;
    esac
  done

  if ((${#tokens[@]} == 0)); then
    printf '%s' "$raw"
    return 0
  fi

  printf '%s' "${tokens[*]}"
}

build_command() {
  local raw="$1"
  local pkgs

  # Expand $DOTFILES ourselves: the command runs through `bash -c`, where the
  # variable is not exported.
  raw="${raw//\$\{DOTFILES\}/$DOTFILES}"
  raw="${raw//\$DOTFILES/$DOTFILES}"

  case "$PLATFORM" in
  macos)
    printf '%s\n' "$raw"
    ;;
  arch)
    case "$raw" in
    pacman\ * | sudo\ pacman\ *)
      pkgs="$(strip_pkg_args "$raw" pacman)"
      printf 'sudo pacman -S --needed --noconfirm %s\n' "$pkgs"
      ;;
    yay\ *)
      pkgs="$(strip_pkg_args "$raw" pacman)"
      printf 'yay -S --needed --noconfirm %s\n' "$pkgs"
      ;;
    *) printf '%s\n' "$raw" ;;
    esac
    ;;
  debian)
    case "$raw" in
    apt\ * | apt-get\ * | sudo\ apt\ * | sudo\ apt-get\ *)
      pkgs="$(strip_pkg_args "$raw" apt)"
      printf 'sudo apt update && sudo apt install -y %s\n' "$pkgs"
      ;;
    *) printf '%s\n' "$raw" ;;
    esac
    ;;
  *)
    printf '%s\n' "$raw"
    ;;
  esac
}

# ─── Installed-state checks ──────────────────────────────────────────────────
# Works out the real package name from the install command (e.g. `fd` is
# `fd-find` on Debian, `node` is `nodejs` on Arch) and checks actual system
# state instead of trusting a log file that can go stale.

pkg_for_check() {
  local app="$1" raw="${2:-}" pkg="" tok

  case "$PLATFORM" in
  macos)
    if [[ "$raw" =~ brew[[:space:]]+install[[:space:]]+(--cask[[:space:]]+)?([^[:space:]\&\;]+) ]]; then
      pkg="${BASH_REMATCH[2]}"
      pkg="${pkg##*/}"
      printf '%s' "$pkg"
      return 0
    fi
    ;;
  arch)
    if [[ "$raw" =~ (pacman|yay)[[:space:]]+-S[^[:space:]]*[[:space:]]+(.*)$ ]]; then
      for tok in ${BASH_REMATCH[2]}; do
        [[ "$tok" == -* ]] && continue
        printf '%s' "$tok"
        return 0
      done
    fi
    ;;
  debian)
    if [[ "$raw" =~ apt(-get)?[[:space:]]+install[[:space:]]+(.*)$ ]]; then
      for tok in ${BASH_REMATCH[2]}; do
        [[ "$tok" == -* ]] && continue
        printf '%s' "$tok"
        return 0
      done
    fi
    ;;
  esac

  printf '%s' "$app"
}

is_installed() {
  local app="$1"
  local raw="${2:-}"
  local pkg
  pkg="$(pkg_for_check "$app" "$raw")"

  case "$PLATFORM" in
  macos)
    command -v brew >/dev/null 2>&1 || return 1
    brew list --formula "$pkg" >/dev/null 2>&1 && return 0
    brew list --cask "$pkg" >/dev/null 2>&1 && return 0
    ;;
  arch)
    command -v pacman >/dev/null 2>&1 || return 1
    pacman -Qi "$pkg" >/dev/null 2>&1 && return 0
    ;;
  debian)
    command -v dpkg >/dev/null 2>&1 || return 1
    dpkg -s "$pkg" >/dev/null 2>&1 && return 0
    ;;
  esac

  return 1
}

ensure_log() {
  [[ "$DRY_RUN" == true ]] && return 0
  [[ -f "$LOG" ]] || : >>"$LOG"
}

remove_log_entry() {
  local app="$1" tmp
  [[ -f "$LOG" ]] || return 0
  tmp="$(mktemp "${TMPDIR:-/tmp}/dotfiles-log.XXXXXX")"
  grep -Fxv "$app" "$LOG" >"$tmp" || true
  mv "$tmp" "$LOG"
}

# ─── Install dispatcher ──────────────────────────────────────────────────────

install_app() {
  local app="$1"
  local raw="$2"
  local cmd rc=0

  # Categories such as system.txt and core.txt overlap; process each app once.
  if [[ -n "${SEEN_APPS[$app]:-}" ]]; then
    return 0
  fi
  SEEN_APPS["$app"]=1

  if [[ "$raw" == "N/A" || -z "$raw" ]]; then
    skip "$app (not available on ${PLATFORM})"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    return 0
  fi

  cmd="$(build_command "$raw")"

  # Dry-run stops here: do not query package managers (which may write caches)
  # or touch the log. Just show the exact command that would run.
  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] would install $app: $cmd"
    DRY_ACTIONS=$((DRY_ACTIONS + 1))
    return 0
  fi

  if is_installed "$app" "$raw"; then
    skip "$app (already installed)"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    ensure_log
    grep -Fxq "$app" "$LOG" || echo "$app" >>"$LOG"
    return 0
  fi

  # The log claimed success but the system disagrees; drop the stale entry.
  if [[ -f "$LOG" ]] && grep -Fxq "$app" "$LOG"; then
    warn "$app was marked installed in the log but is not on the system — removing stale entry"
    remove_log_entry "$app"
  fi

  info "Installing $app..."
  echo "  → $cmd"

  bash -c "$cmd" || rc=$?

  if ((rc == 0)); then
    ensure_log
    echo "$app" >>"$LOG"
    success "$app installed"
    INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
  else
    warn "$app install failed (exit code $rc) — not logged as installed"
    record_failure "package: $app"
  fi
}

# ─── Category runner ─────────────────────────────────────────────────────────

commands_for_app() {
  local app="$1"

  case "$PLATFORM" in
  macos) printf '%s' "${MACOS_CMDS[$app]:-}" ;;
  arch) printf '%s' "${ARCH_CMDS[$app]:-}" ;;
  debian) printf '%s' "${UBUNTU_CMDS[$app]:-}" ;;
  *) printf '' ;;
  esac
}

install_category() {
  local category_file="$1"
  local category_name app raw

  # Unsupported distributions are warned about once in init_platform; do not
  # repeat the warning for every category or package.
  if [[ "$PACKAGE_SUPPORT" != true ]]; then
    return 0
  fi

  category_name="$(basename "$category_file" .txt)"

  if [[ ! -f "$category_file" ]]; then
    warn "Category file not found: $category_file"
    record_failure "category: $category_name (missing)"
    return 0
  fi

  echo ""
  echo "▶ Category: $category_name"

  while IFS= read -r app || [[ -n "$app" ]]; do
    # Skip comments and blank lines
    [[ "$app" =~ ^[[:space:]]*# || -z "${app//[[:space:]]/}" ]] && continue
    app="$(trim "$app")"

    raw="$(commands_for_app "$app")"

    if [[ -z "$raw" ]]; then
      warn "No install entry found for '$app' in resources.toml — skipping"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      continue
    fi

    install_app "$app" "$raw"
  done <"$category_file"
}

# ─── Bootstrap ───────────────────────────────────────────────────────────────

run_bootstrap() {
  echo ""
  echo "▶ Bootstrap"

  if [[ "$PACKAGE_SUPPORT" != true ]]; then
    info "Skipping bootstrap (unsupported distribution)"
    return 0
  fi

  local script=""
  case "$PLATFORM" in
  macos) script="$DOTFILES/bootstrap/macos.sh" ;;
  arch) script="$DOTFILES/bootstrap/arch.sh" ;;
  debian) script="$DOTFILES/bootstrap/ubuntu.sh" ;;
  esac

  if [[ -z "$script" || ! -f "$script" ]]; then
    warn "Bootstrap script not found for ${DISTRO:-$OS}: ${script:-<none>}"
    record_failure "bootstrap: missing script"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] would run: bash $script"
    DRY_ACTIONS=$((DRY_ACTIONS + 1))
    return 0
  fi

  local rc=0
  bash "$script" || rc=$?

  if ((rc == 0)); then
    success "Bootstrap complete"
  else
    warn "Bootstrap failed (exit code $rc)"
    record_failure "bootstrap: failed"
  fi
}

# ─── Stow ────────────────────────────────────────────────────────────────────

has_dot_entries() {
  local dir="$1"
  local -a entries=()
  local nullglob_state
  nullglob_state="$(shopt -p nullglob)"
  shopt -s nullglob
  entries=("$dir"/.[!.]* "$dir"/..?*)
  eval "$nullglob_state"
  ((${#entries[@]} > 0))
}

is_shell_package() {
  local name="$1" candidate
  for candidate in "${SHELL_PACKAGES[@]}"; do
    [[ "$name" == "$candidate" ]] && return 0
  done
  return 1
}

should_stow_package() {
  local name="$1"
  case "$name" in
  bash | zsh | fish) [[ "$name" == "$SHELL_CHOICE" ]] ;;
  yabai) [[ "$PLATFORM" == "macos" ]] ;;
  *) return 0 ;;
  esac
}

# Turn a symlink into an absolute, symlink-resolved path.
resolve_link_target() {
  local link="$1" target dir
  target="$(readlink "$link")" || return 1
  if [[ "$target" != /* ]]; then
    dir="$(cd "$(dirname "$link")" && pwd -P)" || return 1
    target="$dir/$target"
  fi
  dir="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    printf '%s' "$target"
    return 0
  }
  printf '%s/%s' "$dir" "$(basename "$target")"
}

# Resolve a path through symlinked parent directories (e.g. a folded Stow dir).
resolve_target_path() {
  local target="$1" parent
  parent="$(cd "$(dirname "$target")" 2>/dev/null && pwd -P)" || {
    printf '%s' "$target"
    return 0
  }
  printf '%s/%s' "$parent" "$(basename "$target")"
}

# Existing files that Stow would refuse to replace.
collect_conflicts() {
  local package="$1" src rel target src_real
  while IFS= read -r -d '' src; do
    rel="${src#"$DOTFILES/$package"/}"
    [[ "$rel" == ".stow-target" ]] && continue
    target="$HOME/$rel"
    src_real="$(resolve_target_path "$src")"

    if [[ -L "$target" ]]; then
      [[ "$(resolve_link_target "$target")" == "$src_real" ]] && continue
      printf '%s\n' "$target"
    elif [[ -e "$target" ]]; then
      [[ "$(resolve_target_path "$target")" == "$src_real" ]] && continue
      printf '%s\n' "$target"
    fi
  done < <(find "$DOTFILES/$package" -type f -print0)
}

# Move conflicting targets into ~/.dotfiles-backup without overwriting anything.
backup_conflicts() {
  local target rel backup_dir
  mkdir -p "$HOME/.dotfiles-backup" || return 1
  backup_dir="$(mktemp -d "$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S).XXXXXX")" || return 1

  for target in "$@"; do
    rel="${target#"$HOME"/}"
    if [[ "$rel" == "$target" ]]; then
      warn "Refusing to back up a path outside HOME: $target"
      return 1
    fi
    mkdir -p "$backup_dir/$(dirname "$rel")" || return 1
    if ! mv "$target" "$backup_dir/$rel"; then
      warn "Could not move $target to $backup_dir/$rel"
      return 1
    fi
  done

  BACKUP_ROOT="$backup_dir"
}

stow_package() {
  local name="$1"
  local -a conflicts=()
  local target reply="" rc=0

  while IFS= read -r target; do
    [[ -n "$target" ]] && conflicts+=("$target")
  done < <(collect_conflicts "$name")

  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] would run: stow -d $DOTFILES -t $HOME --ignore='.stow-target' $name"
    if ((${#conflicts[@]} > 0)); then
      warn "[DRY RUN] these existing files would need a backup first:"
      for target in "${conflicts[@]}"; do
        info "  ${target#"$HOME"/}"
      done
    fi
    DRY_ACTIONS=$((DRY_ACTIONS + 1))
    return 0
  fi

  if ((${#conflicts[@]} > 0)); then
    warn "$name has existing files that Stow will not overwrite:"
    for target in "${conflicts[@]}"; do
      info "  ${target#"$HOME"/}"
    done

    if [[ "$BACKUP_EXISTING" == true ]]; then
      reply="y"
    elif [[ -t 0 ]]; then
      if ! IFS= read -rp "  Back them up to ~/.dotfiles-backup and link the dotfiles? [y/N]: " reply; then
        reply=""
      fi
    fi

    if [[ ! "$reply" =~ ^[Yy] ]]; then
      skip "$name (existing files kept; not stowed)"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      return 0
    fi

    if ! backup_conflicts "${conflicts[@]}"; then
      warn "Could not back up conflicting files for $name — not stowed"
      record_failure "stow: $name (backup failed)"
      return 0
    fi
    success "Backed up existing files to $BACKUP_ROOT"
  fi

  info "Stowing $name..."
  stow -d "$DOTFILES" -t "$HOME" --ignore='.stow-target' "$name" || rc=$?

  if ((rc == 0)); then
    success "Stowed $name"
  else
    warn "stow failed for $name (exit code $rc)"
    [[ -n "$BACKUP_ROOT" ]] && info "Your previous files are in $BACKUP_ROOT"
    record_failure "stow: $name"
  fi
}

apply_dotfiles() {
  echo ""
  echo "━━━ Applying dotfiles (stow) ━━━━━━━━━━━━"

  local -a packages=()
  local -a missing_markers=()
  local dir name other

  for dir in "$DOTFILES"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"

    # These are installer internals, not stow packages. `git` is deliberately
    # excluded: gitsetup.sh owns ~/.gitconfig and ~/.ssh.
    case "$name" in
    bootstrap | categories | pkg | scripts | tests | git) continue ;;
    esac

    if [[ -f "$dir/.stow-target" ]]; then
      if should_stow_package "$name"; then
        packages+=("$name")
      elif is_shell_package "$name"; then
        skip "$name (shell not selected; using $SHELL_CHOICE)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      else
        skip "$name (not available on $PLATFORM)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      fi
    elif has_dot_entries "$dir"; then
      missing_markers+=("$name")
    fi
  done

  if ((${#missing_markers[@]} > 0)); then
    for name in "${missing_markers[@]}"; do
      skip "$name (no .stow-target marker — not stowed; add $DOTFILES/$name/.stow-target to opt in)"
    done
  fi

  if ((${#packages[@]} == 0)); then
    info "No selected directories opted in with a .stow-target marker; nothing to stow."
    return 0
  fi

  if ! command -v stow >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == true ]]; then
      info "[DRY RUN] GNU Stow is not installed yet; core packages would install it."
    else
      warn "GNU Stow is not installed — cannot apply dotfiles."
      warn "Install it (or re-run the installer) and try again."
      record_failure "stow: not installed"
      return 0
    fi
  fi

  # Only one shell's config should be active. Remove links for the other
  # shells when Stow owns them; unrelated user files are never touched.
  for other in "${SHELL_PACKAGES[@]}"; do
    [[ "$other" == "$SHELL_CHOICE" ]] && continue
    [[ -d "$DOTFILES/$other" ]] || continue
    if [[ "$DRY_RUN" == true ]]; then
      info "[DRY RUN] would remove old $other shell links (if Stow owns them)"
    elif command -v stow >/dev/null 2>&1; then
      stow -D -d "$DOTFILES" -t "$HOME" --ignore='.stow-target' "$other" >/dev/null 2>&1 || true
    fi
  done

  for name in "${packages[@]}"; do
    stow_package "$name"
  done
}

# ─── Git + SSH (optional) ────────────────────────────────────────────────────

run_git_setup() {
  echo ""
  echo "━━━ Git + SSH setup (optional) ━━━━━━━━━"

  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] would ask: Set up Git and SSH? [y/N]"
    info "[DRY RUN] would run: bash $DOTFILES/git/gitsetup.sh (only if accepted)"
    DRY_ACTIONS=$((DRY_ACTIONS + 1))
    return 0
  fi

  local reply=""
  if ! IFS= read -rp "  Set up Git and SSH? [y/N]: " reply; then
    reply=""
  fi

  if [[ ! "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    info "Skipped Git and SSH setup (default: no)"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    return 0
  fi

  if [[ ! -f "$DOTFILES/git/gitsetup.sh" ]]; then
    warn "git/gitsetup.sh not found — skipping Git and SSH setup"
    record_failure "git: missing gitsetup.sh"
    return 0
  fi

  local rc=0
  bash "$DOTFILES/git/gitsetup.sh" || rc=$?

  if ((rc == 0)); then
    success "Git and SSH setup complete"
  else
    warn "Git and SSH setup did not complete (exit code $rc)"
    record_failure "git: setup incomplete"
  fi
}

# ─── Summary ─────────────────────────────────────────────────────────────────

print_summary() {
  echo ""

  if [[ "$DRY_RUN" == true ]]; then
    echo "━━━ Dry run summary ━━━━━━━━━━━━━━━━━━━━"
    info "Shell configuration that would be applied: $SHELL_CHOICE"
    info "$DRY_ACTIONS action(s) would have been performed."
    info "No packages installed, no bootstrap run, no Git/SSH changes, no symlinks touched."
    return 0
  fi

  if ((FAILED_COUNT > 0)); then
    echo "❌ Setup completed with $FAILED_COUNT issue(s):"
    local step
    for step in "${FAILED_STEPS[@]}"; do
      echo "   • $step"
    done
    echo "   Successfully installed: $INSTALLED_COUNT package(s)."
    return 1
  fi

  echo "╔══════════════════════════════════════╗"
  echo "║  ✔  Setup complete!                  ║"
  echo "╚══════════════════════════════════════╝"
  info "Installed: $INSTALLED_COUNT package(s); skipped: $SKIPPED_COUNT step(s)."
  info "Shell configuration: $SHELL_CHOICE"
  [[ -n "$BACKUP_ROOT" ]] && info "Existing files backed up to: $BACKUP_ROOT"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"

  trap 'rc=$?; echo ""; echo "❌ Installer failed at line $LINENO (exit code $rc)"; echo "   Command: $BASH_COMMAND"; exit "$rc"' ERR

  init_platform
  resolve_shell_choice

  local login_shell
  login_shell="$(basename "${SHELL:-}")"
  if [[ "$login_shell" != "$SHELL_CHOICE" ]]; then
    info "Your login shell is '$login_shell'. New terminals keep using it until you run: chsh -s $(command -v "$SHELL_CHOICE" 2>/dev/null || printf '%s' "$SHELL_CHOICE")"
  fi

  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║       Dotfiles Installer             ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "  OS:       $OS"
  echo "  Distro:   ${DISTRO:-N/A}"
  echo "  Platform: $PLATFORM"
  echo "  Shell:    $SHELL_CHOICE"
  echo "  Dotfiles: $DOTFILES"
  echo "  Log:      $LOG"
  [[ "$DRY_RUN" == true ]] && echo "  Mode:     DRY RUN (no changes will be made)"
  echo ""

  if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
    echo "❌ Unsupported OS: $OS. Only macOS and Linux are supported." >&2
    exit 1
  fi

  if [[ ! -f "$RESOURCES" ]]; then
    echo "❌ resources.toml not found at: $RESOURCES" >&2
    exit 1
  fi

  # 1. Parse resources.toml
  parse_resources
  info "Loaded ${#MACOS_CMDS[@]} macOS, ${#ARCH_CMDS[@]} Arch, ${#UBUNTU_CMDS[@]} APT entries"

  # 2. Bootstrap package manager
  run_bootstrap

  # 3. Install the selected shell itself before its optional extras.
  install_selected_shell

  # 4. Auto-install essential categories
  if [[ "$PACKAGE_SUPPORT" == true ]]; then
    echo ""
    echo "━━━ Essential packages ━━━━━━━━━━━━━━━━━━"
    install_category "$DOTFILES/categories/system.txt"
    install_category "$DOTFILES/categories/core.txt"

    # 5. Platform-specific category
    echo ""
    echo "━━━ Platform packages ━━━━━━━━━━━━━━━━━━━"
    case "$PLATFORM" in
    macos) install_category "$DOTFILES/categories/macOS.txt" ;;
    arch) install_category "$DOTFILES/categories/arch.txt" ;;
    debian) : ;; # no Debian-specific category yet; APT entries come from resources.toml
    esac
  else
    info "Skipping package categories (unsupported distribution)"
  fi

  # 6. Optional categories — prompt user (skipped entirely in dry-run)
  echo ""
  echo "━━━ Optional categories ━━━━━━━━━━━━━━━━━"

  if [[ "$PACKAGE_SUPPORT" != true ]]; then
    info "Skipping optional categories (unsupported distribution)"
  elif [[ "$DRY_RUN" == true ]]; then
    info "[DRY RUN] would prompt for optional categories (none installed in dry-run)"
  else
    local -a SKIP_CATEGORIES=("core" "macOS" "arch" "system")
    local category_file category_name response s should_skip

    for category_file in "$DOTFILES"/categories/*.txt; do
      [[ -f "$category_file" ]] || continue
      category_name="$(basename "$category_file" .txt)"

      # zsh plugins only matter when zsh is the selected shell.
      if [[ "$category_name" == "zsh" && "$SHELL_CHOICE" != "zsh" ]]; then
        info "Skipped 'zsh' (selected shell: $SHELL_CHOICE)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
      fi

      should_skip=false
      for s in "${SKIP_CATEGORIES[@]}"; do
        [[ "$category_name" == "$s" ]] && should_skip=true && break
      done
      $should_skip && continue

      response=""
      if ! IFS= read -rp "  Install '$category_name'? [y/N]: " response; then
        response=""
      fi

      if [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        install_category "$category_file"
      else
        info "Skipped '$category_name'"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      fi
    done
  fi

  # 7. Apply dotfiles via stow
  apply_dotfiles

  # 8. Optional Git + SSH setup
  run_git_setup

  # 9. Accurate summary + exit code. `|| exit` keeps the ERR trap from
  # printing a second, misleading "installer failed" message for a
  # non-zero summary.
  print_summary || exit $?
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
