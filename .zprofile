
# Created by `pipx` on 2025-10-07 07:00:01
export PATH="$PATH:/Users/n1ghtw1ng/.local/bin"
alias python=python3


# Load pyenv automatically by appending
# the following to 
# ~/.zprofile (for login shells)
# and ~/.zshrc (for interactive shells) :

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

