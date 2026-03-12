# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -------------------------
# ~/.zshrc – interactive shell
# -------------------------

# Load login shell environment
[[ -f ~/.zprofile ]] && source ~/.zprofile

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME="powerlevel10k/powerlevel10k"   # ignored, using Starship + P10k
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

# Portable Powerlevel10k loader
for p10k in \
  /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme \
  /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme \
  /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme
do
  [[ -f $p10k ]] && source $p10k && break
done
