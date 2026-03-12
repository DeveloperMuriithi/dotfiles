#!/usr/bin/env bash
set -e

echo "=== Dotfiles-safe Git + SSH Setup ==="

# Automatically load .env from the same directory
ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading environment variables from .env"
    source "$ENV_FILE"
fi

# Prompt for Git username/email if not set
GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"

if [ -z "$GIT_NAME" ]; then
    read -p "Enter your Git username: " GIT_NAME
fi

if [ -z "$GIT_EMAIL" ]; then
    read -p "Enter your Git email: " GIT_EMAIL
fi

# Configure Git globally
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
echo "Git identity set:"
git config --list --global | grep "user"

# SSH key setup
SSH_KEY="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY" ]; then
    echo "SSH key already exists at $SSH_KEY"
else
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
fi

# Start SSH agent and add key (if not already added)
if ! ssh-add -l | grep -q "$SSH_KEY"; then
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY"
fi

echo ""
echo "Your public SSH key (copy this to GitHub/GitLab):"
cat "${SSH_KEY}.pub"
echo ""
echo "Add it to GitHub: https://github.com/settings/keys"
echo "Add it to GitLab: https://gitlab.com/-/profile/keys"

# Force Git to use this key
git config --global core.sshCommand "ssh -i $SSH_KEY"

# Extra recommended Git configs
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "nvim"

echo ""
echo "✅ Git + SSH setup complete!"
git config --list --global

