#!/usr/bin/env bash
DRY_RUN=${1:-false}

set -e

DOTFILES="$HOME/dotfiles"
OS="$(uname)"

echo "Starting category-aware installer..."
echo "Detected OS: $OS"

echo "Running bootstrap..."

if [[ "$OS" == "Darwin" ]]; then
    bash "$DOTFILES/bootstrap/macos.sh"
else
    bash "$DOTFILES/bootstrap/arch.sh"
fi


# Dispatcher function
install_app() {
    local app="$1"
    local method="$2"

    if [[ "$method" == "N/A" || -z "$method" ]]; then
        echo "Skipping $app (not available on this OS)"
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] $method"
    else
        echo "Installing $app..."
        eval "$method"
    fi
}

# Read resources into associative array
declare -A resources
while IFS=: read -r app macOS_method arch_method; do
    [[ -z "$app" ]] && continue

    app=$(echo "$app" | xargs)

    if [[ "$OS" == "Darwin" ]]; then
        resources["$app"]="$macOS_method"
    else
        resources["$app"]="$arch_method"
    fi
done < "$DOTFILES/resources.txt"

# Function to install a category
install_category() {
    local category_file="$1"

    while read -r app; do
        # Skip comments and empty lines
        [[ "$app" =~ ^#.*$ || -z "$app" ]] && continue

        method="${resources[$app]}"

        # Detect missing resource
        if [[ -z "$method" ]]; then
            echo "⚠ No install method defined for '$app'"
            continue
        fi

        install_app "$app" "$method"

    done < "$category_file"
}

##essentials for whole system
echo "Installing system essentials..."
install_category "$DOTFILES/categories/system.txt"


# --- 1️⃣ Install core category automatically ---
echo "Installing core apps..."
install_category "$DOTFILES/categories/core.txt"

# --- 2️⃣ Install OS-specific category automatically ---
if [[ "$OS" == "Darwin" ]]; then
    echo "Installing macOS-specific apps..."
    install_category "$DOTFILES/categories/macOS.txt"
else
    echo "Installing Arch-specific apps..."
    install_category "$DOTFILES/categories/arch.txt"
fi

# --- 3️⃣ Prompt for optional categories ---
for category_file in "$DOTFILES"/categories/*.txt; do
    category_name=$(basename "$category_file" .txt)
    # Skip core and OS-specific categories
    [[ "$category_name" == "core" || "$category_name" == "macOS" || "$category_name" == "arch" ]] && continue

    read -rp "Do you want to install category '$category_name'? [y/N]: " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        install_category "$category_file"
    fi
done

# --- 4️⃣ Stow configs ---
echo "Linking configs via stow..."
for dir in zsh kitty starship wezterm yabai; do
    stow -v -t "$HOME" "$dir"
done

# --- 5️⃣ Git setup ---
echo "Setting up Git..."
bash git/gitsetup.sh

echo "Dotfiles setup complete!"

