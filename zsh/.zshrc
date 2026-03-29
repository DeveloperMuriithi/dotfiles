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
export TERM="xterm-256color"
export ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
typeset -A ZSH_HIGHLIGHT_STYLES  # ensure it’s an associative array
ZSH_HIGHLIGHT_STYLES[command]='fg=#00ff00'
export ZSH_HIGHLIGHT_STYLES[command]='fg=#00ff00'
export ZSH_HIGHLIGHT_STYLES[unknown-command]='fg=#ff5555,bold'

# ZSH_THEME="powerlevel10k/powerlevel10k"   # ignored, using Starship + P10k
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)

#zsh_syntax_highlighting
# Use a shades-of-green palette
typeset -A ZSH_HIGHLIGHT_STYLES

# Commands
ZSH_HIGHLIGHT_STYLES[command]='fg=#00ff00'          # bright neon green
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#00cc00'          # darker green for builtins (cd, pwd)
ZSH_HIGHLIGHT_STYLES[alias]='fg=#00aa00'            # dark green for aliases
ZSH_HIGHLIGHT_STYLES[function]='fg=#33ff33'         # bright green for functions
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#22cc22,bold' # medium green for keywords (if, then)
ZSH_HIGHLIGHT_STYLES[option]='fg=#66ff66'           # lime/bright green for flags/options
ZSH_HIGHLIGHT_STYLES[unknown-command]='fg=#ff5555,bold' # red for invalid commands

# Files & directories
ZSH_HIGHLIGHT_STYLES[dir]='fg=#33ffff,bold'         # cyan bold for directories
ZSH_HIGHLIGHT_STYLES[path]='fg=#33ffff'             # cyan for normal files
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#ff55ff'      # magenta for hidden files
ZSH_HIGHLIGHT_STYLES[number]='fg=#aaff00'          # yellow-green for numbers
ZSH_HIGHLIGHT_STYLES[string]='fg=#00ffff'          # cyan-blue for strings
ZSH_HIGHLIGHT_STYLES[comment]='fg=#888888'         # gray for comments

# Cursor feedback on invalid input
ZSH_HIGHLIGHT_STYLES[default]='fg=#00ff00'         # fallback: bright green

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

# piknik

source /usr/local/etc/profile.d/piknik.sh
