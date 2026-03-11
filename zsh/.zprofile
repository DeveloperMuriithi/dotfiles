# -------------------------
# ~/.zprofile – login shell
# -------------------------

# Paths
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# macOS specific
if [[ "$(uname -s)" == "Darwin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# direnv hook
eval "$(direnv hook zsh)"

# Default python
alias python=python3

