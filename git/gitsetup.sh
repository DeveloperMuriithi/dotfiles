#!/usr/bin/env bash
# gitsetup.sh — Safe Git identity + SSH key setup
#
# Usage:
#   ./git/gitsetup.sh            — configure Git and SSH interactively
#   ./git/gitsetup.sh --dry-run  — show planned actions without changing anything
#
# Environment overrides (useful for automation):
#   GIT_NAME, GIT_EMAIL, SSH_KEY
#   A local git/.env file with these variables is loaded automatically.

set -euo pipefail

DRY_RUN=false

while (($# > 0)); do
  case "$1" in
  --dry-run) DRY_RUN=true ;;
  -h | --help)
    cat <<'EOF'
Usage: ./git/gitsetup.sh [--dry-run]

  --dry-run   Show what would be configured without writing Git config,
              creating SSH keys, or starting an SSH agent.
EOF
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 2
    ;;
  esac
  shift
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

info() { echo "  ℹ $*"; }
success() { echo "  ✔ $*"; }
warn() { echo "  ⚠ $*" >&2; }
skip() { echo "  ↩ $*"; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

valid_email() {
  [[ "$1" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"

if [[ -f "$ENV_FILE" ]]; then
  info "Loading environment variables from .env"
  # Do not let an incomplete .env abort the script via `set -u`.
  set +u
  # shellcheck disable=SC1090
  if ! source "$ENV_FILE"; then
    set -u
    warn "Failed to load $ENV_FILE — fix or remove it and re-run."
    exit 1
  fi
  set -u
  GIT_NAME="${GIT_NAME:-}"
  GIT_EMAIL="${GIT_EMAIL:-}"
fi

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_KEY="$(trim "$SSH_KEY")"
[[ -z "$SSH_KEY" ]] && SSH_KEY="$HOME/.ssh/id_ed25519"

echo "=== Dotfiles-safe Git + SSH Setup ==="

# ─── Prompt helpers ──────────────────────────────────────────────────────────

prompt_username() {
  local input
  while :; do
    if ! IFS= read -rp "Enter your Git username: " input; then
      warn "No input received — Git setup cancelled. No Git configuration was changed."
      return 1
    fi
    input="$(trim "$input")"
    if [[ -z "$input" ]]; then
      warn "Git username cannot be empty. Please try again."
      continue
    fi
    GIT_NAME="$input"
    return 0
  done
}

prompt_email() {
  local input
  while :; do
    if ! IFS= read -rp "Enter your Git email: " input; then
      warn "No input received — Git setup cancelled. No Git configuration was changed."
      return 1
    fi
    input="$(trim "$input")"
    if [[ -z "$input" ]]; then
      warn "Git email cannot be empty. Please try again."
      continue
    fi
    if ! valid_email "$input"; then
      warn "Invalid email address: '$input'. Expected something like name@example.com."
      continue
    fi
    GIT_EMAIL="$input"
    return 0
  done
}

# ─── Dry run ─────────────────────────────────────────────────────────────────

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  info "[DRY RUN] would validate and prompt for a non-empty Git username/email"
  info "[DRY RUN] would run: git config --global user.name ${GIT_NAME:-<prompted username>}"
  info "[DRY RUN] would run: git config --global user.email ${GIT_EMAIL:-<prompted email>}"

  if [[ -f "$SSH_KEY" ]]; then
    info "[DRY RUN] would reuse the existing SSH key at $SSH_KEY"
  else
    info "[DRY RUN] would generate a new SSH key at $SSH_KEY"
  fi

  info "[DRY RUN] would add the key to ssh-agent and set core.sshCommand"
  info "[DRY RUN] no Git configuration, SSH keys, or agent state were changed."
  exit 0
fi

# ─── Sanity checks ───────────────────────────────────────────────────────────

if ! command -v git >/dev/null 2>&1; then
  warn "git is not installed — cannot configure Git or SSH."
  exit 1
fi

FAILED=0

# ─── Validate identity (before any Git configuration) ────────────────────────

GIT_NAME="$(trim "$GIT_NAME")"
GIT_EMAIL="$(trim "$GIT_EMAIL")"

if [[ -z "$GIT_NAME" ]]; then
  prompt_username || exit 1
fi

if [[ -z "$GIT_EMAIL" ]]; then
  prompt_email || exit 1
elif ! valid_email "$GIT_EMAIL"; then
  warn "Invalid email address in GIT_EMAIL: '$GIT_EMAIL'"
  GIT_EMAIL=""
  prompt_email || exit 1
fi

# Final guard: never write empty values.
if [[ -z "$GIT_NAME" || -z "$GIT_EMAIL" ]]; then
  warn "Git username and email are required — no changes were made."
  exit 1
fi

# ─── Resolve SSH key (consent before generating) ─────────────────────────────

KEY_EXISTS=false
GENERATE_KEY=false

if [[ -f "$SSH_KEY" ]]; then
  KEY_EXISTS=true
  success "Existing SSH key found at $SSH_KEY"

  reuse="y"
  if ! IFS= read -rp "  Reuse this key? [Y/n]: " reuse; then
    reuse="y"
  fi

  case "$reuse" in
  [Nn]*)
    new_key=""
    if ! IFS= read -rp "  Path for new key [$HOME/.ssh/id_ed25519_new]: " new_key; then
      new_key=""
    fi
    new_key="$(trim "$new_key")"
    [[ -z "$new_key" ]] && new_key="$HOME/.ssh/id_ed25519_new"

    if [[ -e "$new_key" || -e "${new_key}.pub" ]]; then
      warn "Refusing to overwrite existing key at $new_key."
      warn "Choose a different path (or remove the old key yourself) and re-run."
      exit 1
    fi

    SSH_KEY="$new_key"
    KEY_EXISTS=false
    GENERATE_KEY=true
    ;;
  *)
    info "Reusing existing SSH key."
    ;;
  esac
else
  GENERATE_KEY=true
fi

# ─── Configure Git identity ──────────────────────────────────────────────────

set_git_config() {
  local key="$1"
  local value="$2"
  if git config --global "$key" "$value"; then
    success "$key = $value"
  else
    warn "Failed to set Git config: $key"
    FAILED=1
  fi
}

set_git_config "user.name" "$GIT_NAME"
set_git_config "user.email" "$GIT_EMAIL"

# ─── Create SSH key only when needed ─────────────────────────────────────────

if [[ "$GENERATE_KEY" == true ]]; then
  if [[ -e "$SSH_KEY" || -e "${SSH_KEY}.pub" ]]; then
    warn "Refusing to overwrite existing key at $SSH_KEY."
    FAILED=1
  elif ! command -v ssh-keygen >/dev/null 2>&1; then
    warn "ssh-keygen is not available — cannot generate an SSH key."
    FAILED=1
  else
    mkdir -p "$(dirname "$SSH_KEY")"
    echo "  → Generating new SSH key at $SSH_KEY..."
    if ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""; then
      success "Generated SSH key: $SSH_KEY"
      KEY_EXISTS=true
    else
      warn "SSH key generation failed."
      FAILED=1
    fi
  fi
fi

# ─── SSH agent (optional convenience) ────────────────────────────────────────

if [[ "$KEY_EXISTS" == true ]]; then
  if ! command -v ssh-add >/dev/null 2>&1; then
    skip "ssh-add is not available — skipping SSH agent setup"
  elif ssh-add -l 2>/dev/null | grep -Fq "$SSH_KEY"; then
    skip "SSH key already loaded in ssh-agent"
  else
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
      eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    fi

    if ssh-add "$SSH_KEY"; then
      success "Added SSH key to ssh-agent"
    else
      warn "Could not add the key to ssh-agent (optional — start an agent and run ssh-add manually)."
    fi
  fi

  set_git_config "core.sshCommand" "ssh -i $SSH_KEY"
fi

# ─── Recommended Git settings ────────────────────────────────────────────────

set_git_config "init.defaultBranch" "main"
set_git_config "pull.rebase" "false"
set_git_config "core.editor" "nvim"

# Keep large clones from aborting on slow or flaky connections (matches the
# settings already used on this machine).
set_git_config "http.lowSpeedLimit" "0"
set_git_config "http.lowSpeedTime" "999999"

# ─── Next steps ──────────────────────────────────────────────────────────────

if [[ "$KEY_EXISTS" == true && -f "${SSH_KEY}.pub" ]]; then
  echo ""
  echo "Your public SSH key (copy this to GitHub/GitLab):"
  cat "${SSH_KEY}.pub"
  echo ""
  echo "Add it to GitHub: https://github.com/settings/keys"
  echo "Add it to GitLab: https://gitlab.com/-/profile/keys"
fi

echo ""
if ((FAILED > 0)); then
  warn "Git + SSH setup finished with issues. Review the messages above."
  exit 1
fi

echo "✅ Git + SSH setup complete!"
git config --list --global
