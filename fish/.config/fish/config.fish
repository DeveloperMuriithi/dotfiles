# ~/.config/fish/config.fish — interactive and login configuration
#
# Starship is the required prompt. The dotfiles installer makes sure it is
# installed, and this file only initialises it when the binary is available so
# a broken PATH never prevents a shell from starting.

# ── Paths ────────────────────────────────────────────────────────────────────

# User-local binaries (Claude Code, pipx, cargo shims, etc.).
if test -d "$HOME/.local/bin"
    fish_add_path --prepend "$HOME/.local/bin"
end

# Homebrew's superuser-only tools (openvpn on Intel macOS).
if test -d /usr/local/sbin
    fish_add_path --prepend /usr/local/sbin
end

# Docker Desktop CLI, when installed.
if test -d "$HOME/.docker/bin"
    fish_add_path --append "$HOME/.docker/bin"
end

# MacPorts: appended, never prepended, so Homebrew keeps precedence.
# Directories only, so new ports are picked up without re-sourcing.
if test -d /opt/local/bin
    fish_add_path --path --append /opt/local/bin /opt/local/sbin
end

# MacPorts ships fish completions outside Homebrew fish's complete path.
if test -d /opt/local/share/fish/vendor_completions.d
    set -gx fish_complete_path /opt/local/share/fish/vendor_completions.d $fish_complete_path
end

# DevRelay CLI (installed by its own installer, not by these dotfiles).
if test -d "$HOME/.devrelay/bin"
    fish_add_path --prepend "$HOME/.devrelay/bin"
end

# Spicetify, when present.
if test -d "$HOME/.spicetify"
    fish_add_path "$HOME/.spicetify"
end

set -gx EDITOR nvim
set -gx VISUAL nvim

# ── Interactive shell ────────────────────────────────────────────────────────

if status is-interactive
    # Vi-style editing and cursor shapes.
    fish_vi_key_bindings
    set fish_cursor_default block blink
    set fish_cursor_insert line blink
    set fish_cursor_replace_one underscore blink
    set fish_cursor_visual block

    # ── n1ghtw1ng fish colors ────────────────────────────────────────────
    set -g fish_color_normal E6EDF3
    set -g fish_color_command 00FF87 --bold
    set -g fish_color_param E6EDF3
    set -g fish_color_valid_path 00D9FF --bold
    set -g fish_color_error FF5F56 --bold
    set -g fish_color_option FFD75F --bold
    set -g fish_color_quote FF86C8
    set -g fish_color_redirection 00D9FF --bold
    set -g fish_color_operator D787FF --bold
    set -g fish_color_comment 7F8C8D --italics
    set -g fish_color_escape D787FF --bold
    set -g fish_color_end 7F8C8D
    set -g fish_color_autosuggestion 7F8C8D
    set -g fish_color_selection --background=1F2933
    set -g fish_color_search_match --background=1F2933
    set -g fish_color_cwd 00FF87 --bold
    set -g fish_color_cwd_root FF5F56 --bold
    set -g fish_pager_color_prefix 00FF87 --bold
    set -g fish_pager_color_completion E6EDF3
    set -g fish_pager_color_description 7F8C8D
    set -g fish_pager_color_progress 00D9FF
    set -g fish_pager_color_secondary_completion 7F8C8D

    # ── Aliases ──────────────────────────────────────────────────────────
    if command -q eza
        alias ls='eza --icons'
        alias ll='eza -lah --icons'
        alias la='eza -a --icons'
        alias tree='eza --tree --icons'
    else if test (uname) = Darwin
        alias ls='ls -G'
    else
        alias ls='ls --color=auto'
    end

    alias gs='git status'
    alias ..='cd ..'

    # ── Starship prompt (required) ───────────────────────────────────────
    if command -q starship
        starship init fish | source
    end

    # ── Optional tool integrations ───────────────────────────────────────
    if command -q rbenv
        rbenv init - --no-rehash fish | source
    end

    if command -q zoxide
        zoxide init fish | source
    end
end
