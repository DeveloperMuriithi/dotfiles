# ~/.zshrc — interactive zsh configuration
#
# Starship is the required prompt; the dotfiles installer installs it. The
# guard below keeps a missing binary from breaking an otherwise usable shell.

# ── History ─────────────────────────────────────────────────────────────────
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt append_history extended_history hist_expire_dups_first
setopt hist_ignore_dups hist_ignore_space share_history inc_append_history

# ── Completion ──────────────────────────────────────────────────────────────
autoload -Uz compinit
compinit -i
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# ── Editing ─────────────────────────────────────────────────────────────────
bindkey -v
export KEYTIMEOUT=1
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"

# ── Starship prompt (required) ──────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
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

# ── Optional tool integrations ──────────────────────────────────────────────
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
fi

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# ── Plugins (loaded last) ───────────────────────────────────────────────────
for _zsh_plugin in \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [[ -r "$_zsh_plugin" ]]; then
    source "$_zsh_plugin"
    break
  fi
done
unset _zsh_plugin

for _zsh_highlight in \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [[ -r "$_zsh_highlight" ]]; then
    source "$_zsh_highlight"
    break
  fi
done
unset _zsh_highlight
