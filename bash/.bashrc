# ~/.bashrc — interactive bash configuration
#
# Starship is the required prompt; the dotfiles installer installs it. The
# command checks keep a missing binary from breaking an otherwise usable shell.

# Only run for interactive shells.
case $- in
*i*) ;;
*) return 0 ;;
esac

# ── History ─────────────────────────────────────────────────────────────────
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=50000
HISTFILESIZE=50000
shopt -s histappend checkwinsize cmdhist

# ── Editing ─────────────────────────────────────────────────────────────────
set -o vi
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

# ── Starship prompt (required) ──────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

# ── Aliases ─────────────────────────────────────────────────────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons'
  alias ll='eza -lah --icons'
  alias la='eza -a --icons'
  alias tree='eza --tree --icons'
elif [[ "$(uname -s)" == "Darwin" ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi

alias gs='git status'
alias ..='cd ..'

# ── Completions ─────────────────────────────────────────────────────────────
if [[ -r /usr/local/etc/profile.d/bash_completion.sh ]]; then
  . /usr/local/etc/profile.d/bash_completion.sh
elif [[ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]]; then
  . /opt/homebrew/etc/profile.d/bash_completion.sh
elif [[ -r /usr/share/bash-completion/bash_completion ]]; then
  . /usr/share/bash-completion/bash_completion
fi

# Local overrides, if any.
[[ -r "$HOME/.bash_aliases" ]] && . "$HOME/.bash_aliases"
