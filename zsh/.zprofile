# ~/.zprofile — login shell environment
#
# Keep PATH setup here; interactive settings live in ~/.zshrc. De-duplicate
# path entries so re-sourcing or nested login shells stay clean.

typeset -U path
path=("$HOME/bin" "$HOME/.local/bin" $path)

# Homebrew (Apple Silicon first, then Intel).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# MacPorts is appended so Homebrew keeps winning name lookups.
if [[ -d /opt/local/bin ]]; then
  path+=(/opt/local/bin /opt/local/sbin)
fi

# Docker Desktop CLI.
if [[ -d "$HOME/.docker/bin" ]]; then
  path+=("$HOME/.docker/bin")
fi

# DevRelay CLI (its own installer owns this directory).
if [[ -d "$HOME/.devrelay/bin" ]]; then
  path=("$HOME/.devrelay/bin" $path)
fi

# pyenv's shims, when pyenv is installed.
if [[ -d "$HOME/.pyenv/bin" ]]; then
  path=("$HOME/.pyenv/bin" $path)
fi

export PATH
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
