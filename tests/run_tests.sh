#!/usr/bin/env bash
# tests/run_tests.sh — lightweight regression tests for the dotfiles installer.
# Run with: bash tests/run_tests.sh
# These tests use temporary HOME directories and stub binaries; they do not
# install packages, touch the real Git config, or create real SSH keys.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tests.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

PASS=0
FAIL=0

ok() {
  PASS=$((PASS + 1))
  printf '  ✔ %s\n' "$1"
}

not_ok() {
  FAIL=$((FAIL + 1))
  printf '  ✘ %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" | sed 's/^/      /'
  fi
}

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    ok "$msg"
  else
    not_ok "$msg" "expected: [$expected] actual: [$actual]"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    ok "$msg"
  else
    not_ok "$msg" "output did not contain: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    ok "$msg"
  else
    not_ok "$msg" "output unexpectedly contained: $needle"
  fi
}

assert_file_absent() {
  if [[ ! -e "$1" ]]; then
    ok "$2"
  else
    not_ok "$2" "unexpected file: $1"
  fi
}

assert_file_content() {
  local file="$1" expected="$2" msg="$3"
  if [[ -f "$file" && "$(cat "$file")" == "$expected" ]]; then
    ok "$msg"
  else
    not_ok "$msg" "file $file missing or content differs"
  fi
}

# Shared fake OS release and PATH stubs.
FAKE_ETC="$TMPROOT/etc"
mkdir -p "$FAKE_ETC"
printf 'ID=kali\nID_LIKE=debian\n' >"$FAKE_ETC/kali"
printf 'ID=ubuntu\nID_LIKE=debian\n' >"$FAKE_ETC/ubuntu"
printf 'ID=debian\n' >"$FAKE_ETC/debian"
printf 'ID=arch\n' >"$FAKE_ETC/arch"
printf 'ID=gentoo\n' >"$FAKE_ETC/gentoo"

# ─── 1. Syntax checks ────────────────────────────────────────────────────────

echo ""
echo "▶ Syntax checks (bash -n)"

while IFS= read -r script; do
  if bash -n "$script" 2>"$TMPROOT/syntax.err"; then
    ok "bash -n ${script#"$REPO"/}"
  else
    not_ok "bash -n ${script#"$REPO"/}" "$(cat "$TMPROOT/syntax.err")"
  fi
done < <(find "$REPO" -name '*.sh' -not -path '*/.git/*' | sort)

echo ""
echo "▶ Shell config syntax"

for shell_file in "$REPO/bash/.bashrc" "$REPO/bash/.bash_profile"; do
  if bash -n "$shell_file" 2>"$TMPROOT/syntax.err"; then
    ok "bash -n ${shell_file#"$REPO"/}"
  else
    not_ok "bash -n ${shell_file#"$REPO"/}" "$(cat "$TMPROOT/syntax.err")"
  fi
done

if command -v zsh >/dev/null 2>&1; then
  for shell_file in "$REPO/zsh/.zshrc" "$REPO/zsh/.zprofile"; do
    if zsh -n "$shell_file" 2>"$TMPROOT/syntax.err"; then
      ok "zsh -n ${shell_file#"$REPO"/}"
    else
      not_ok "zsh -n ${shell_file#"$REPO"/}" "$(cat "$TMPROOT/syntax.err")"
    fi
  done
else
  ok "zsh not installed; zsh syntax checks skipped"
fi

if command -v fish >/dev/null 2>&1; then
  if fish -n "$REPO/fish/.config/fish/config.fish" 2>"$TMPROOT/syntax.err"; then
    ok "fish -n fish/.config/fish/config.fish"
  else
    not_ok "fish -n fish/.config/fish/config.fish" "$(cat "$TMPROOT/syntax.err")"
  fi
else
  ok "fish not installed; fish syntax check skipped"
fi

# ─── 1b. Shell selection and required prompt ────────────────────────────────

echo ""
echo "▶ Shell selection"

shell_default=$(
  export SHELL=/bin/fish DRY_RUN=false
  source "$REPO/install.sh"
  SHELL_CHOICE=""
  resolve_shell_choice </dev/null >/dev/null 2>&1
  printf '%s' "$SHELL_CHOICE"
)
assert_eq "fish" "$shell_default" "non-interactive default uses the login shell"

shell_unknown=$(
  export SHELL=/bin/tcsh DRY_RUN=false
  source "$REPO/install.sh"
  SHELL_CHOICE=""
  resolve_shell_choice </dev/null >/dev/null 2>&1
  printf '%s' "$SHELL_CHOICE"
)
assert_eq "zsh" "$shell_unknown" "unknown login shell falls back to zsh"

shell_flag=$(
  source "$REPO/install.sh"
  parse_args --shell bash
  printf '%s' "$SHELL_CHOICE"
)
assert_eq "bash" "$shell_flag" "--shell selects the shell non-interactively"

shell_invalid_rc=0
bash -c 'source "$0/install.sh"; SHELL_CHOICE=tcsh; resolve_shell_choice' "$REPO" >/dev/null 2>&1 || shell_invalid_rc=$?
assert_eq "2" "$shell_invalid_rc" "invalid --shell exits with code 2"

shell_gate=$(
  source "$REPO/install.sh"
  SHELL_CHOICE=fish
  PLATFORM=macos
  should_stow_package fish && printf 'fish:yes;'
  should_stow_package zsh || printf 'zsh:no;'
  PLATFORM=debian
  should_stow_package yabai || printf 'yabai:no;'
)
assert_eq "fish:yes;zsh:no;yabai:no;" "$shell_gate" "only the selected shell and platform packages are stowed"

for pkg in bash fish zsh kitty starship wezterm nvim yabai; do
  if [[ -f "$REPO/$pkg/.stow-target" ]]; then
    ok "$pkg has a .stow-target marker"
  else
    not_ok "$pkg has a .stow-target marker"
  fi
done

assert_contains "$(cat "$REPO/nvim/.config/nvim/lazy-lock.json")" '"LazyVim"' "Neovim lockfile is backed up"
assert_file_absent "$REPO/nvim/.config/nvim/lazy" "Neovim plugin data is not backed up"
assert_file_absent "$REPO/nvim/.config/nvim/pack" "Neovim package data is not backed up"

assert_contains "$(cat "$REPO/categories/core.txt")" "starship" "Starship is an essential package"
assert_contains "$(cat "$REPO/fish/.config/fish/config.fish")" "starship init fish" "fish initialises Starship"
assert_contains "$(cat "$REPO/bash/.bashrc")" "starship init bash" "bash initialises Starship"
assert_contains "$(cat "$REPO/zsh/.zshrc")" "starship init zsh" "zsh initialises Starship"

# ─── 2. Distribution dispatch ────────────────────────────────────────────────

echo ""
echo "▶ Distribution dispatch"

dispatch_platform() {
  local distro_file="$1"
  (
    DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$distro_file" source "$REPO/install.sh"
    init_platform >/dev/null 2>&1
    printf '%s' "$PLATFORM"
  )
}

for pair in "kali:debian" "ubuntu:debian" "debian:debian" "arch:arch"; do
  distro="${pair%%:*}"
  expected="${pair##*:}"
  assert_eq "$expected" "$(dispatch_platform "$FAKE_ETC/$distro")" "$distro maps to $expected"
done

assert_eq "macos" "$(DOTFILES_OS=Darwin source "$REPO/install.sh" 2>/dev/null; init_platform; printf '%s' "$PLATFORM")" "Darwin maps to macos"

# Command translation per platform.
debian_cmd=$(DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$FAKE_ETC/kali" bash -c '
  source "$0/install.sh"; init_platform >/dev/null 2>&1
  build_command "apt install -y --no-install-recommends nmap"' "$REPO")
assert_eq "sudo apt update && sudo apt install -y nmap" "$debian_cmd" "Kali apt command is normalised"

arch_cmd=$(DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$FAKE_ETC/arch" bash -c '
  source "$0/install.sh"; init_platform >/dev/null 2>&1
  build_command "pacman -S git"' "$REPO")
assert_eq "sudo pacman -S --needed --noconfirm git" "$arch_cmd" "Arch pacman command is normalised"

yay_cmd=$(DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$FAKE_ETC/arch" bash -c '
  source "$0/install.sh"; init_platform >/dev/null 2>&1
  build_command "yay -S --needed localsend-bin"' "$REPO")
assert_eq "yay -S --needed --noconfirm localsend-bin" "$yay_cmd" "Arch yay command is normalised"

mac_cmd=$(DOTFILES_OS=Darwin bash -c '
  source "$0/install.sh"; init_platform >/dev/null 2>&1
  build_command "brew install --cask raycast"' "$REPO")
assert_eq "brew install --cask raycast" "$mac_cmd" "macOS brew command passes through"

expanded_cmd=$(DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$FAKE_ETC/arch" bash -c '
  source "$0/install.sh"; init_platform >/dev/null 2>&1
  build_command "bash $DOTFILES/scripts/install_caido.sh"' "$REPO")
assert_eq "bash $REPO/scripts/install_caido.sh" "$expanded_cmd" "\$DOTFILES is expanded in commands"

# Unsupported distro should warn once, not once per package/category.
unsupported_out=$(
  DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$FAKE_ETC/gentoo" bash -c '
    source "$0/install.sh"
    init_platform
    install_category "$0/categories/system.txt"
    install_category "$0/categories/core.txt"
    install_category "$0/categories/security.txt"' "$REPO" 2>&1
)
assert_eq "1" "$(printf '%s\n' "$unsupported_out" | grep -c "Unsupported Linux distribution")" "unsupported distro warns exactly once"

# ─── 3. Package install handling ─────────────────────────────────────────────

echo ""
echo "▶ Package install handling"

STUBS="$TMPROOT/stubs"
mkdir -p "$STUBS"

cat >"$STUBS/sudo" <<'EOF'
#!/usr/bin/env bash
exit "${STUB_SUDO_RC:-0}"
EOF
cat >"$STUBS/dpkg" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$STUBS/sudo" "$STUBS/dpkg"

install_case() {
  # $1 = dry run true/false, $2 = stub sudo rc, $3 = temp dir
  local dry="$1" sudo_rc="$2" dir="$3"
  (
    DOTFILES_OS=Linux DOTFILES_OS_RELEASE="$FAKE_ETC/kali" source "$REPO/install.sh"
    PLATFORM=debian
    PACKAGE_SUPPORT=true
    DRY_RUN="$dry"
    LOG="$dir/installed.log"
    RESOURCES="$REPO/resources.toml"
    PATH="$STUBS:$PATH"
    export STUB_SUDO_RC="$sudo_rc"
    install_app "nmap" "apt install nmap" >"$dir/out" 2>&1
    printf '%s|%s' "$INSTALLED_COUNT" "$FAILED_COUNT" >"$dir/counts"
  )
}

case_dir="$TMPROOT/case-fail"
mkdir -p "$case_dir"
install_case false 1 "$case_dir"
assert_eq "0|1" "$(cat "$case_dir/counts")" "failed install is counted as a failure"
assert_file_absent "$case_dir/installed.log" "failed package is not written to the install log"
assert_contains "$(cat "$case_dir/out")" "install failed" "failed package reports the failure"

case_dir="$TMPROOT/case-ok"
mkdir -p "$case_dir"
install_case false 0 "$case_dir"
assert_eq "1|0" "$(cat "$case_dir/counts")" "successful install is counted"
assert_contains "$(cat "$case_dir/installed.log")" "nmap" "successful package is logged"

case_dir="$TMPROOT/case-dry"
mkdir -p "$case_dir"
install_case true 0 "$case_dir"
assert_file_absent "$case_dir/installed.log" "dry-run does not create the install log"
assert_contains "$(cat "$case_dir/out")" "DRY RUN" "dry-run displays the package command"
assert_eq "0|0" "$(cat "$case_dir/counts")" "dry-run does not count installs"

# ─── 4. Stow handling ────────────────────────────────────────────────────────

echo ""
echo "▶ Stow handling"

make_stow_stub() {
  local path="$1" rc="$2"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_LOG"
exit "${STUB_STOW_RC:-0}"
EOF
  chmod +x "$path"
  export STUB_STOW_RC="$rc"
}

fake_dotfiles="$TMPROOT/dotfiles"
mkdir -p "$fake_dotfiles/zsh" "$fake_dotfiles/kitty/.config"
echo "zshrc" >"$fake_dotfiles/zsh/.zshrc"
echo "kitty" >"$fake_dotfiles/kitty/.config/kitty.conf"
touch "$fake_dotfiles/zsh/.stow-target"

stow_ok_dir="$TMPROOT/stow-ok"
mkdir -p "$stow_ok_dir/bin"
make_stow_stub "$stow_ok_dir/bin/stow" 0

stow_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  DOTFILES="$fake_dotfiles"
  HOME="$TMPROOT/home-ok"
  PLATFORM=macos
  SHELL_CHOICE=zsh
  DRY_RUN=false
  PATH="$stow_ok_dir/bin:$PATH"
  export STUB_LOG="$stow_ok_dir/calls"
  apply_dotfiles 2>&1
)
assert_contains "$stow_out" "Stowed zsh" "marked directory is stowed"
assert_contains "$(cat "$stow_ok_dir/calls")" "--ignore=.stow-target" "stow ignores the marker file"
assert_contains "$(cat "$stow_ok_dir/calls")" "-t $TMPROOT/home-ok" "stow targets HOME"
assert_contains "$stow_out" "kitty (no .stow-target marker" "missing marker is explained"
assert_not_contains "$(cat "$stow_ok_dir/calls")" "kitty" "unmarked directory is not stowed"

stow_bad_dir="$TMPROOT/stow-bad"
mkdir -p "$stow_bad_dir/bin"
make_stow_stub "$stow_bad_dir/bin/stow" 1

stow_bad_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  DOTFILES="$fake_dotfiles"
  HOME="$TMPROOT/home-bad"
  PLATFORM=macos
  SHELL_CHOICE=zsh
  DRY_RUN=false
  PATH="$stow_bad_dir/bin:$PATH"
  export STUB_LOG="$stow_bad_dir/calls"
  apply_dotfiles 2>&1
  printf 'FAILED=%s' "$FAILED_COUNT"
)
assert_contains "$stow_bad_out" "stow failed for zsh" "stow conflict is reported"
assert_contains "$stow_bad_out" "FAILED=1" "stow conflict is counted as a failure"

# Missing stow (only run if the host genuinely lacks it).
stow_missing_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  DOTFILES="$fake_dotfiles"
  HOME="$TMPROOT/home-missing"
  PLATFORM=macos
  SHELL_CHOICE=zsh
  DRY_RUN=false
  PATH="/usr/bin:/bin:/usr/sbin:/sbin"
  apply_dotfiles 2>&1
)
if command -v stow >/dev/null 2>&1; then
  ok "host has stow installed; missing-stow case skipped"
else
  assert_contains "$stow_missing_out" "GNU Stow is not installed" "missing stow is reported"
fi

# Dry-run must not call stow.
stow_dry_dir="$TMPROOT/stow-dry"
mkdir -p "$stow_dry_dir/bin"
make_stow_stub "$stow_dry_dir/bin/stow" 0
stow_dry_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  DOTFILES="$fake_dotfiles"
  HOME="$TMPROOT/home-dry"
  PLATFORM=macos
  SHELL_CHOICE=zsh
  DRY_RUN=true
  PATH="$stow_dry_dir/bin:$PATH"
  export STUB_LOG="$stow_dry_dir/calls"
  apply_dotfiles 2>&1
)
assert_contains "$stow_dry_out" "DRY RUN" "dry-run displays the stow command"
assert_file_absent "$stow_dry_dir/calls" "dry-run does not invoke stow"

# Existing files are backed up only after explicit consent.
backup_repo="$TMPROOT/backup-dotfiles"
mkdir -p "$backup_repo/zsh"
echo "new-zshrc" >"$backup_repo/zsh/.zshrc"
touch "$backup_repo/zsh/.stow-target"
backup_home="$TMPROOT/home-backup"
mkdir -p "$backup_home"
echo "old-zshrc" >"$backup_home/.zshrc"
backup_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  DOTFILES="$backup_repo"
  HOME="$backup_home"
  PLATFORM=macos
  SHELL_CHOICE=zsh
  DRY_RUN=false
  BACKUP_EXISTING=true
  PATH="$stow_ok_dir/bin:$PATH"
  export STUB_LOG="$stow_ok_dir/backup-calls"
  apply_dotfiles </dev/null 2>&1
  printf 'BACKUP=%s' "$BACKUP_ROOT"
)
assert_contains "$backup_out" "Backed up existing files" "conflicting files are backed up with consent"
assert_contains "$(cat "$stow_ok_dir/backup-calls")" "zsh" "stow runs after the backup"
backed_up_file="$(find "$backup_home/.dotfiles-backup" -type f -name .zshrc -print -quit 2>/dev/null)"
assert_file_content "$backed_up_file" "old-zshrc" "the original file is preserved in the backup"
assert_file_absent "$backup_home/.zshrc" "the conflicting file is moved out of the way"

# Without consent the existing file is left alone and the package is skipped.
decline_home="$TMPROOT/home-decline"
mkdir -p "$decline_home"
echo "keep-me" >"$decline_home/.zshrc"
decline_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  DOTFILES="$backup_repo"
  HOME="$decline_home"
  PLATFORM=macos
  SHELL_CHOICE=zsh
  DRY_RUN=false
  BACKUP_EXISTING=false
  PATH="$stow_ok_dir/bin:$PATH"
  export STUB_LOG="$stow_ok_dir/decline-calls"
  apply_dotfiles </dev/null 2>&1
)
assert_contains "$decline_out" "existing files kept" "declining a backup skips the package"
assert_file_content "$decline_home/.zshrc" "keep-me" "declining leaves the existing file untouched"
assert_file_absent "$stow_ok_dir/decline-calls" "declining does not invoke stow"

# A target already linked to the package is not a conflict.
stowed_home="$TMPROOT/home-already-stowed"
mkdir -p "$stowed_home"
ln -s "$backup_repo/zsh/.zshrc" "$stowed_home/.zshrc"
stowed_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  DOTFILES="$backup_repo"
  HOME="$stowed_home"
  PLATFORM=macos
  SHELL_CHOICE=zsh
  DRY_RUN=false
  BACKUP_EXISTING=false
  PATH="$stow_ok_dir/bin:$PATH"
  export STUB_LOG="$stow_ok_dir/stowed-calls"
  apply_dotfiles </dev/null 2>&1
)
assert_contains "$stowed_out" "Stowed zsh" "an existing Stow link is not treated as a conflict"
assert_file_absent "$stowed_home/.dotfiles-backup" "an existing Stow link is not backed up"

# ─── 5. Git stage in install.sh ──────────────────────────────────────────────

echo ""
echo "▶ Git stage prompt"

fake_repo="$TMPROOT/fake-repo"
mkdir -p "$fake_repo/git"
cat >"$fake_repo/git/gitsetup.sh" <<'EOF'
#!/usr/bin/env bash
touch "$HOME/git-setup-ran"
EOF
chmod +x "$fake_repo/git/gitsetup.sh"

git_declined_home="$TMPROOT/home-git-declined"
mkdir -p "$git_declined_home"
git_declined_out=$(
  printf 'n\n' | (
    DOTFILES_OS=Darwin source "$REPO/install.sh"
    DOTFILES="$fake_repo"
    HOME="$git_declined_home"
    PLATFORM=macos
    DRY_RUN=false
    run_git_setup
  ) 2>&1
)
assert_contains "$git_declined_out" "Skipped Git and SSH setup" "declining the prompt skips Git setup"
assert_file_absent "$git_declined_home/git-setup-ran" "declining does not run gitsetup.sh"

git_accepted_home="$TMPROOT/home-git-accepted"
mkdir -p "$git_accepted_home"
git_accepted_out=$(
  printf 'y\n' | (
    DOTFILES_OS=Darwin source "$REPO/install.sh"
    DOTFILES="$fake_repo"
    HOME="$git_accepted_home"
    PLATFORM=macos
    DRY_RUN=false
    run_git_setup
  ) 2>&1
)
assert_contains "$git_accepted_out" "Git and SSH setup complete" "accepting the prompt runs Git setup"
if [[ -f "$git_accepted_home/git-setup-ran" ]]; then
  ok "accepted prompt invokes gitsetup.sh"
else
  not_ok "accepted prompt invokes gitsetup.sh"
fi

git_dry_home="$TMPROOT/home-git-dry"
mkdir -p "$git_dry_home"
git_dry_out=$(
  (
    DOTFILES_OS=Darwin source "$REPO/install.sh"
    DOTFILES="$fake_repo"
    HOME="$git_dry_home"
    PLATFORM=macos
    DRY_RUN=true
    run_git_setup
  ) 2>&1
)
assert_contains "$git_dry_out" "DRY RUN" "dry-run prints the Git prompt plan"
assert_file_absent "$git_dry_home/git-setup-ran" "dry-run does not run gitsetup.sh"

# ─── 6. gitsetup.sh ─────────────────────────────────────────────────────────

echo ""
echo "▶ Git + SSH setup"

GIT_STUBS="$TMPROOT/git-stubs"
mkdir -p "$GIT_STUBS"
cat >"$GIT_STUBS/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
key=""
while (($# > 0)); do
  if [[ "$1" == "-f" ]]; then
    shift
    key="$1"
  fi
  shift
done
if [[ "${STUB_KEYGEN_RC:-0}" != "0" ]]; then
  exit "${STUB_KEYGEN_RC:-1}"
fi
printf 'STUB-PRIVATE\n' >"$key"
printf 'STUB-PUBLIC\n' >"$key.pub"
exit 0
EOF
cat >"$GIT_STUBS/ssh-add" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-l" ]]; then
  exit 1
fi
exit 0
EOF
cat >"$GIT_STUBS/ssh-agent" <<'EOF'
#!/usr/bin/env bash
echo "SSH_AUTH_SOCK=/tmp/stub-agent.sock; export SSH_AUTH_SOCK;"
EOF
chmod +x "$GIT_STUBS/ssh-keygen" "$GIT_STUBS/ssh-add" "$GIT_STUBS/ssh-agent"

run_gitsetup() {
  local home="$1" stdin="$2"
  shift 2
  printf '%s' "$stdin" | env -u GIT_NAME -u GIT_EMAIL -u SSH_KEY \
    HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" \
    PATH="$GIT_STUBS:$PATH" \
    bash "$REPO/git/gitsetup.sh"
}

# Dry run: no files at all.
home="$TMPROOT/git-dry"
mkdir -p "$home"
out=$(HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" GIT_NAME="Test User" GIT_EMAIL="test@example.com" \
  PATH="$GIT_STUBS:$PATH" bash "$REPO/git/gitsetup.sh" --dry-run 2>&1)
assert_contains "$out" "DRY RUN" "gitsetup dry-run prints a plan"
assert_file_absent "$home/.gitconfig" "gitsetup dry-run writes no Git config"
assert_file_absent "$home/.ssh" "gitsetup dry-run creates no SSH directory"

# No input at all: must cancel cleanly and change nothing.
home="$TMPROOT/git-cancel"
mkdir -p "$home"
run_gitsetup "$home" "" >"$TMPROOT/git-cancel.out" 2>&1
assert_eq "1" "$?" "gitsetup exits non-zero when cancelled"
assert_contains "$(cat "$TMPROOT/git-cancel.out")" "cancelled" "gitsetup reports cancellation"
assert_file_absent "$home/.gitconfig" "cancelled setup writes no Git config"

# Blank username is rejected, then valid input is accepted.
home="$TMPROOT/git-blank"
mkdir -p "$home"
run_gitsetup "$home" $'\nTest User\ntest@example.com\n' >"$TMPROOT/git-blank.out" 2>&1
assert_eq "0" "$?" "blank username is retried"
assert_contains "$(cat "$TMPROOT/git-blank.out")" "cannot be empty" "blank username is rejected"
assert_eq "Test User" "$(git config --file "$home/.gitconfig" user.name)" "valid username is configured"
assert_eq "test@example.com" "$(git config --file "$home/.gitconfig" user.email)" "valid email is configured"

# Invalid email is rejected before configuration, then retried.
home="$TMPROOT/git-bad-email"
mkdir -p "$home"
run_gitsetup "$home" $'Test User\nnot-an-email\ntest@example.com\n' >"$TMPROOT/git-bad-email.out" 2>&1
assert_eq "0" "$?" "invalid email is retried"
assert_contains "$(cat "$TMPROOT/git-bad-email.out")" "Invalid email address" "invalid email is reported"
assert_eq "test@example.com" "$(git config --file "$home/.gitconfig" user.email)" "only valid email is configured"

# Invalid GIT_EMAIL from the environment is rejected (non-interactive).
home="$TMPROOT/git-bad-env"
mkdir -p "$home"
printf '' | env GIT_NAME="Test User" GIT_EMAIL="not-an-email" SSH_KEY="$home/.ssh/id_ed25519" \
  HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" PATH="$GIT_STUBS:$PATH" \
  bash "$REPO/git/gitsetup.sh" >"$TMPROOT/git-bad-env.out" 2>&1
assert_eq "1" "$?" "invalid GIT_EMAIL exits non-zero"
assert_contains "$(cat "$TMPROOT/git-bad-env.out")" "Invalid email address" "invalid GIT_EMAIL is reported"
assert_file_absent "$home/.gitconfig" "invalid GIT_EMAIL writes no Git config"

# Existing key is reused by default (EOF = default yes) and never overwritten.
home="$TMPROOT/git-existing"
mkdir -p "$home/.ssh"
printf 'ORIGINAL-KEY\n' >"$home/.ssh/id_ed25519"
home_before=$(cat "$home/.ssh/id_ed25519")
run_gitsetup "$home" $'Test User\ntest@example.com\n' >"$TMPROOT/git-existing.out" 2>&1
assert_eq "0" "$?" "existing key setup succeeds"
assert_eq "$home_before" "$(cat "$home/.ssh/id_ed25519")" "existing SSH key is not overwritten"
assert_eq "ssh -i $home/.ssh/id_ed25519" "$(git config --file "$home/.gitconfig" core.sshCommand)" "existing key is used in core.sshCommand"

# Declining reuse and choosing an existing path must refuse to overwrite it.
home="$TMPROOT/git-refuse"
mkdir -p "$home/.ssh"
printf 'ORIGINAL-KEY\n' >"$home/.ssh/id_ed25519"
printf 'OTHER-KEY\n' >"$home/.ssh/other"
run_gitsetup "$home" $'Test User\ntest@example.com\nn\n'"$home/.ssh/other"$'\n' >"$TMPROOT/git-refuse.out" 2>&1
assert_eq "1" "$?" "refusing overwrite exits non-zero"
assert_contains "$(cat "$TMPROOT/git-refuse.out")" "Refusing to overwrite" "overwrite refusal is reported"
assert_eq "OTHER-KEY" "$(cat "$home/.ssh/other")" "existing alternate key is untouched"

# New key generation when none exists.
home="$TMPROOT/git-generate"
mkdir -p "$home"
run_gitsetup "$home" $'Test User\ntest@example.com\n' >"$TMPROOT/git-generate.out" 2>&1
assert_eq "0" "$?" "key generation setup succeeds"
if [[ -f "$home/.ssh/id_ed25519" && -f "$home/.ssh/id_ed25519.pub" ]]; then
  ok "new SSH key and public key are created"
else
  not_ok "new SSH key and public key are created"
fi
assert_contains "$(cat "$TMPROOT/git-generate.out")" "Git + SSH setup complete" "successful setup reports completion"

# Key generation failure is reported and produces a non-zero exit.
home="$TMPROOT/git-keygen-fail"
mkdir -p "$home"
printf '' | env STUB_KEYGEN_RC=1 HOME="$home" GIT_CONFIG_GLOBAL="$home/.gitconfig" \
  GIT_NAME="Test User" GIT_EMAIL="test@example.com" SSH_KEY="$home/.ssh/id_ed25519" \
  PATH="$GIT_STUBS:$PATH" bash "$REPO/git/gitsetup.sh" >"$TMPROOT/git-keygen-fail.out" 2>&1
assert_eq "1" "$?" "failed key generation exits non-zero"
assert_contains "$(cat "$TMPROOT/git-keygen-fail.out")" "SSH key generation failed" "failed key generation is reported"
assert_file_absent "$home/.ssh/id_ed25519" "failed key generation leaves no key"

# ─── 7. Full dry-run safety ──────────────────────────────────────────────────

echo ""
echo "▶ Full dry-run safety"

dry_repo="$TMPROOT/dry-repo"
mkdir -p "$dry_repo"
cp "$REPO/install.sh" "$REPO/resources.toml" "$dry_repo/"
cp -R "$REPO/bootstrap" "$REPO/categories" "$REPO/git" "$REPO/scripts" "$dry_repo/"
mkdir -p "$dry_repo/zsh"
cp "$REPO/zsh/.zshrc" "$dry_repo/zsh/.zshrc"
touch "$dry_repo/zsh/.stow-target"

dry_home="$TMPROOT/dry-home"
mkdir -p "$dry_home"

dry_out=$(HOME="$dry_home" DOTFILES_OS=Darwin bash "$dry_repo/install.sh" --dry-run --shell zsh </dev/null 2>&1)
dry_rc=$?
assert_eq "0" "$dry_rc" "full dry-run exits successfully"
assert_contains "$dry_out" "DRY RUN" "full dry-run prints the mode"
assert_contains "$dry_out" "would install" "full dry-run lists package actions"
assert_contains "$dry_out" "would run: bash" "full dry-run lists bootstrap action"
assert_contains "$dry_out" "would run: stow" "full dry-run lists stow action"
assert_file_absent "$dry_repo/.installed.log" "full dry-run creates no install log"
assert_file_absent "$dry_home/.gitconfig" "full dry-run writes no Git config"
assert_file_absent "$dry_home/.ssh" "full dry-run creates no SSH files"
if [[ -z "$(ls -A "$dry_home")" ]]; then
  ok "full dry-run leaves HOME empty"
else
  not_ok "full dry-run leaves HOME empty" "$(ls -A "$dry_home")"
fi

# ─── 8. Missing files and end-to-end failure reporting ──────────────────────

echo ""
echo "▶ Failure reporting"

# Missing resources.toml aborts with a clear message and non-zero exit.
missing_repo="$TMPROOT/missing-repo"
mkdir -p "$missing_repo"
cp "$REPO/install.sh" "$missing_repo/"
missing_out=$(HOME="$TMPROOT/missing-home" DOTFILES_OS=Darwin bash "$missing_repo/install.sh" --dry-run </dev/null 2>&1)
missing_rc=$?
assert_eq "1" "$missing_rc" "missing resources.toml exits non-zero"
assert_contains "$missing_out" "resources.toml not found" "missing resources.toml is reported"

# A missing category file is reported as a failure, not silently ignored.
missing_cat_out=$(
  DOTFILES_OS=Darwin source "$REPO/install.sh"
  PACKAGE_SUPPORT=true
  install_category "$TMPROOT/does-not-exist.txt" 2>&1
  printf 'FAILED=%s' "$FAILED_COUNT"
)
assert_contains "$missing_cat_out" "Category file not found" "missing category is reported"
assert_contains "$missing_cat_out" "FAILED=1" "missing category is counted as a failure"

# End-to-end failing install: exit 1, accurate summary, no false success and
# no misleading ERR-trap message.
fail_repo="$TMPROOT/fail-repo"
mkdir -p "$fail_repo/categories" "$fail_repo/bootstrap" "$fail_repo/git" "$fail_repo/stubs"
cp "$REPO/install.sh" "$fail_repo/"
cat >"$fail_repo/resources.toml" <<'EOF'
[nmap]
macos = "brew install nmap"
arch = "pacman -S nmap"
ubuntu = "apt install nmap"
EOF
printf 'nmap\n' >"$fail_repo/categories/system.txt"
printf '' >"$fail_repo/categories/core.txt"
printf '#!/usr/bin/env bash\nexit 0\n' >"$fail_repo/bootstrap/macos.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$fail_repo/git/gitsetup.sh"
cat >"$fail_repo/stubs/brew" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$fail_repo/bootstrap/macos.sh" "$fail_repo/git/gitsetup.sh" "$fail_repo/stubs/brew"

fail_home="$TMPROOT/fail-home"
mkdir -p "$fail_home"
fail_out=$(HOME="$fail_home" DOTFILES_OS=Darwin PATH="$fail_repo/stubs:$PATH" \
  bash "$fail_repo/install.sh" </dev/null 2>&1)
fail_rc=$?
assert_eq "1" "$fail_rc" "failed installation exits non-zero"
assert_contains "$fail_out" "Setup completed with" "failure summary is printed"
assert_contains "$fail_out" "package: nmap" "failure summary names the failed package"
assert_not_contains "$fail_out" "Setup complete!" "failed installation does not claim success"
assert_not_contains "$fail_out" "Installer failed at line" "summary failure does not duplicate the ERR-trap message"

# ─── Summary ────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
echo "Passed: $PASS   Failed: $FAIL"
echo "────────────────────────────────────────"

((FAIL == 0))
