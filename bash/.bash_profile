# ~/.bash_profile — login shell environment
#
# Bash on macOS reads this for login shells; on Linux it takes precedence over
# ~/.profile when present. Keep PATH setup here and interactive settings in
# ~/.bashrc.

# Prepend a directory only when it exists and is not already in PATH.
path_prepend() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
  *":$1:"*) ;;
  *) PATH="$1:$PATH" ;;
  esac
}

path_append() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
  *":$1:"*) ;;
  *) PATH="$PATH:$1" ;;
  esac
}

# Homebrew (Apple Silicon first, then Intel).
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.devrelay/bin"
path_append "$HOME/.docker/bin"
path_append /opt/local/bin
path_append /opt/local/sbin

export PATH
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

# Interactive configuration.
[[ -r "$HOME/.bashrc" ]] && . "$HOME/.bashrc"
