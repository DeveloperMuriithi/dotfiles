# dotfiles

Cross-platform dotfiles bootstrapper with package installation, GNU Stow
linking, shell selection, and optional Git/SSH setup.

## Supported systems

| Platform | Package manager | Bootstrap |
| --- | --- | --- |
| macOS | Homebrew | `bootstrap/macos.sh` |
| Arch Linux (and Arch-based) | pacman + yay | `bootstrap/arch.sh` |
| Ubuntu / Debian / Kali Linux | APT | `bootstrap/ubuntu.sh` |

Debian-family distributions share the `ubuntu` entries in `resources.toml`.
Unknown Linux distributions are reported once; package installation and
bootstrap are skipped, while Stow and Git setup still run.

## Usage

```sh
./install.sh                 # normal install; prompts for a shell
./install.sh --shell fish    # choose bash, zsh, or fish up front
./install.sh --dry-run       # preview only, no changes
```

`install.sh` applies only the selected shell's configuration and removes
links for the other shell packages when Stow owns them. It installs the chosen
shell (and Starship, which is required on every terminal).

Dry-run mode does not install packages, run bootstrap scripts, query package
managers, write the install log, change Git configuration, create SSH keys,
move existing files, or touch symlinks.

## Shell configuration

| Shell | Files | Prompt |
| --- | --- | --- |
| bash | `bash/.bashrc`, `bash/.bash_profile` | Starship |
| zsh | `zsh/.zshrc`, `zsh/.zprofile` | Starship |
| fish | `fish/.config/fish/config.fish` | Starship |

All three share the same aliases (`ls`, `ll`, `la`, `tree`, `gs`, `..`), use
`eza` when available, and fall back to the platform's native `ls` when it is
not. Path setup is conditional: Homebrew, MacPorts, Docker, DevRelay, pyenv,
rbenv, and zoxide are only wired in when present.

The Starship configuration lives in `starship/.config/starship.toml` and uses
the shared "hacker" palette. Kitty and WezTerm themes are aligned with it.

### Neovim / LazyVim

Only the portable Neovim configuration is tracked under
`nvim/.config/nvim/` (about 72 KB). The `lazy-lock.json` file pins plugin
versions, so LazyVim can reinstall plugins after cloning this repo. Plugin
checkouts, caches, and state are deliberately not tracked:

- `~/.local/share/nvim` — plugin installs and LazyVim data
- `~/.local/state/nvim` — runtime state
- `~/.cache/nvim` — caches

## Optional Git + SSH setup

`install.sh` asks `Set up Git and SSH? [y/N]` (default: no). Choosing yes runs
`git/gitsetup.sh`, which:

- rejects empty usernames and empty/invalid emails before writing any config;
- reuses an existing SSH key by default and never overwrites one without an
  explicit new, unused path;
- reports failures with a non-zero exit code.

`GIT_NAME`, `GIT_EMAIL`, and `SSH_KEY` can be supplied via the environment or a
git-ignored `git/.env` file.

## Stow packages

Directories are only stowed when they contain a `.stow-target` marker. The
installer-owned packages (`bash`, `fish`, `zsh`, `kitty`, `starship`, `wezterm`,
`nvim`, and `yabai` on macOS) already include one:

```sh
touch mypackage/.stow-target   # opt a new package in
```

Directories that contain dotfiles but no marker are listed as skipped. The
marker file itself is ignored by Stow. `scripts/link.sh` is the manual wrapper;
it also supports `--shell` and `--dry-run`.

If a target file already exists, Stow will not overwrite it. The installer
lists the conflicts and asks before moving them to
`~/.dotfiles-backup/<timestamp>/`. Use `--backup-existing` to give that consent
non-interactively. Declining leaves the existing file untouched and skips that
package; it is not treated as a failure.

## Tests

```sh
bash tests/run_tests.sh
```

The suite checks shell syntax, shell selection, distro dispatch and command
translation, package failure logging, dry-run safety, Stow conflicts and backup
handling, Git/SSH validation and key handling, and failure summaries. It uses
temporary HOME directories and stub binaries only.
