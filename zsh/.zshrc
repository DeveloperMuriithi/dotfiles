# -------------------------
# ~/.zshrc – interactive shell
# -------------------------

# Load login shell environment
[[ -f ~/.zprofile ]] && source ~/.zprofile

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""   # ignored, using Starship + P10k
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# Starship prompt
eval "$(starship init zsh)"

# Powerlevel10k (optional)
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Aliases
alias ll='ls -lah --color=auto'
alias gs='git status'
alias ..='cd ..'

# macOS vs Linux tweaks
if [[ "$(uname -s)" == "Darwin" ]]; then
    alias ls='ls -G'
    # iTerm2 integration
    test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
else
    alias ls='ls --color=auto'
fi

# pyenv interactive shell init
eval "$(pyenv init -)"

