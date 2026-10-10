#!/usr/bin/env bash
# ==============================================================================
# Dotfiles Setup & Installer Script for Arch Linux
# ==============================================================================
set -euo pipefail

# Color codes for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# ------------------------------------------------------------------------------
# 1. Pre-flight Checks
# ------------------------------------------------------------------------------
if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root or with sudo! It will invoke sudo when needed."
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    error "This script is designed specifically for Arch Linux."
    exit 1
fi

info "Checking sudo privileges..."
sudo -v
# Keep sudo alive during script execution
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

# ------------------------------------------------------------------------------
# 2. Package Management (Pacman & Yay)
# ------------------------------------------------------------------------------
info "Updating package databases and installing prerequisites..."
sudo pacman -Sy --needed --noconfirm base-devel git stow pciutils

# Check if yay is installed, install yay-bin if not present
if ! command -v yay &>/dev/null; then
    warn "yay (AUR helper) is not installed. Installing yay-bin..."
    TEMP_YAY="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$TEMP_YAY"
    (cd "$TEMP_YAY" && makepkg -si --noconfirm)
    rm -rf "$TEMP_YAY"
    success "yay installed successfully."
fi

# List of official Arch packages required by dotfiles
OFFICIAL_PACKAGES=(
    # Compositor, Session & Portals
    hyprland
    hypridle
    hyprlock
    swaylock
    waybar
    wofi
    mako
    swaybg
    awww
    xdg-desktop-portal-hyprland
    xdg-desktop-portal
    polkit-gnome
    sddm
    qt5-quickcontrols2
    qt5-graphicaleffects

    # Shell, Terminal & Dev
    kitty
    tmux
    zsh
    neovim
    yazi
    starship
    ripgrep
    fd
    fzf
    nodejs
    npm
    python
    python-pynvim
    python-requests
    unzip
    curl

    # Audio, Bluetooth & Network
    pipewire
    pipewire-pulse
    wireplumber
    pavucontrol
    pamixer
    playerctl
    bluez
    bluez-utils
    blueman
    network-manager-applet

    # Screen Capture & Clipboard
    grim
    slurp
    swappy
    wl-clipboard
    cliphist

    # GUI Apps & Tools
    thunar
    qbittorrent
    brightnessctl
    pacman-contrib
    libnotify

    # Qt & GTK Theming Engines
    qt5ct
    qt6ct
    qt5-wayland
    qt6-wayland
    kvantum
    kvantum-qt5
    adwaita-icon-theme
    papirus-icon-theme
    xfconf
    glib2
    dconf

    # System Monitors, Shell & Dev Tools
    btop
    github-cli
    lazygit
    docker
    docker-compose
    docker-buildx
    lazydocker

    # Document Viewers & Editors
    gedit
    zathura
    zathura-pdf-mupdf

    # Communication & Browsers
    discord
    telegram-desktop
    chromium

    # Media & Content Creation
    vlc
    obs-studio
    audacity
    blender
    gimp

    # Notes & Productivity
    obsidian

    # Gaming & Performance Overlay
    steam
    mangohud
    lib32-mangohud
    goverlay

    # Fonts
    ttf-jetbrains-mono-nerd
    otf-font-awesome
    inter-font
    noto-fonts
    noto-fonts-emoji
)

info "Installing official repository packages via pacman..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"

# AUR Packages required by dotfiles
AUR_PACKAGES=(
    zen-browser-bin
    wlogout
    wofi-calc
    wofi-emoji
    catppuccin-cursors-mocha
    catppuccin-gtk-theme-mocha
    dracula-gtk-theme
    heroic-games-launcher-bin
)

info "Installing AUR packages via yay..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"


# GPU Driver check & suggestion
info "Checking GPU hardware..."
if command -v lspci &>/dev/null; then
    if lspci | grep -i nvidia &>/dev/null; then
        info "NVIDIA GPU detected. Installing NVIDIA Wayland packages & OpenCL..."
        sudo pacman -S --needed --noconfirm nvidia-open nvidia-utils libva-nvidia-driver opencl-nvidia || true
    elif lspci | grep -i -E "amd|ati|radeon" &>/dev/null; then
        info "AMD GPU detected. Installing AMD Vulkan & VA-API drivers..."
        sudo pacman -S --needed --noconfirm mesa vulkan-radeon libva-mesa-driver || true
    elif lspci | grep -i intel &>/dev/null; then
        info "Intel GPU detected. Installing Intel Vulkan & VA-API drivers..."
        sudo pacman -S --needed --noconfirm mesa intel-media-driver vulkan-intel || true
    fi
fi

# ------------------------------------------------------------------------------
# 3. Git Submodules (Neovim configuration)
# ------------------------------------------------------------------------------
info "Initializing and updating git submodules (including .config/nvim)..."
git -C "$DOTFILES_DIR" submodule update --init --recursive
success "Submodules updated."

# ------------------------------------------------------------------------------
# 4. Shell Framework & Plugins Setup
# ------------------------------------------------------------------------------
# Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    success "Oh My Zsh installed."
else
    info "Oh My Zsh is already installed."
fi

# Catppuccin theme for Oh My Zsh (specified in .zshrc)
OMZ_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$OMZ_CUSTOM/themes/catppuccin-flavors"
if [[ ! -d "$OMZ_CUSTOM/themes/catppuccin-zsh" ]]; then
    info "Installing Catppuccin theme for Oh My Zsh..."
    git clone https://github.com/JannoTjarks/catppuccin-zsh.git "$OMZ_CUSTOM/themes/catppuccin-zsh"
    ln -sf "$OMZ_CUSTOM/themes/catppuccin-zsh/catppuccin.zsh-theme" "$OMZ_CUSTOM/themes/catppuccin.zsh-theme"
    ln -sf "$OMZ_CUSTOM/themes/catppuccin-zsh/catppuccin-flavors"/* "$OMZ_CUSTOM/themes/catppuccin-flavors/"
    success "Catppuccin ZSH theme installed."
else
    info "Catppuccin ZSH theme is already installed."
    ln -sf "$OMZ_CUSTOM/themes/catppuccin-zsh/catppuccin.zsh-theme" "$OMZ_CUSTOM/themes/catppuccin.zsh-theme"
    ln -sf "$OMZ_CUSTOM/themes/catppuccin-zsh/catppuccin-flavors"/* "$OMZ_CUSTOM/themes/catppuccin-flavors/"
fi

# Tmux Plugin Manager (TPM)
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    info "Installing Tmux Plugin Manager (TPM)..."
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    success "TPM installed."
else
    info "TPM is already installed."
fi

# ------------------------------------------------------------------------------
# 5. System Themes Installation
# ------------------------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/usr/share/themes" ]]; then
    info "Installing Dracula and system themes to /usr/share/themes/ and ~/.local/share/themes/..."
    sudo cp -rf "$DOTFILES_DIR"/usr/share/themes/* /usr/share/themes/
    mkdir -p "$HOME/.local/share/themes" "$HOME/.themes"
    cp -rf "$DOTFILES_DIR"/usr/share/themes/* "$HOME/.local/share/themes/"
    cp -rf "$DOTFILES_DIR"/usr/share/themes/* "$HOME/.themes/"
    success "Themes copied."
fi

# Catppuccin Theme for Telegram Desktop
TELEGRAM_THEMES_DIR="$HOME/.local/share/TelegramDesktop/themes"
if [[ ! -f "$TELEGRAM_THEMES_DIR/catppuccin-mocha.tdesktop-theme" ]]; then
    info "Setting up Catppuccin Mocha theme for Telegram Desktop..."
    mkdir -p "$TELEGRAM_THEMES_DIR"
    TEMP_TG="$(mktemp -d)"
    if curl -sL "https://raw.githubusercontent.com/catppuccin/telegram/main/src/mocha/desktop" -o "$TEMP_TG/colors.tdesktop-theme"; then
        python3 -c "
import zipfile
with zipfile.ZipFile('$TELEGRAM_THEMES_DIR/catppuccin-mocha.tdesktop-theme', 'w', zipfile.ZIP_DEFLATED) as z:
    z.write('$TEMP_TG/colors.tdesktop-theme', 'colors.tdesktop-theme')
" 2>/dev/null || true
        success "Catppuccin Mocha theme for Telegram Desktop created at $TELEGRAM_THEMES_DIR."
    fi
    rm -rf "$TEMP_TG"
fi


# ------------------------------------------------------------------------------
# 6. Script Execution Permissions
# ------------------------------------------------------------------------------
info "Setting executable permissions on helper scripts..."
chmod +x "$DOTFILES_DIR"/.config/hypr/*.sh 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/.config/hypr/xdg-portal-hyprland 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/.config/HyprV/hyprv_util 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/.config/HyprV/waybar/scripts/* 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/install.sh 2>/dev/null || true
success "Permissions set."

# ------------------------------------------------------------------------------
# 7. Safe Backup & GNU Stow Integration
# ------------------------------------------------------------------------------
info "Preparing targets for GNU Stow (backing up conflicting files/directories)..."

mkdir -p "$BACKUP_DIR"
BACKUP_OCCURRED=false

# Root home files managed by dotfiles
HOME_FILES=(".bashrc" ".zshrc" ".tmux.conf")
for file in "${HOME_FILES[@]}"; do
    TARGET="$HOME/$file"
    if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
        info "Backing up existing $TARGET -> $BACKUP_DIR/$file"
        mv "$TARGET" "$BACKUP_DIR/$file"
        BACKUP_OCCURRED=true
    elif [[ -L "$TARGET" ]]; then
        LINK_TARGET="$(readlink -f "$TARGET")"
        if [[ "$LINK_TARGET" != "$DOTFILES_DIR/$file" ]]; then
            info "Removing stale symlink $TARGET"
            rm -f "$TARGET"
        fi
    fi
done

# Config directories managed by dotfiles
mkdir -p "$HOME/.config"
CONFIG_ENTRIES=(
    "gtk-3.0"
    "gtk-4.0"
    "hypr"
    "HyprV"
    "kitty"
    "mako"
    "nvim"
    "qBittorrent"
    "qt5ct"
    "qt6ct"
    "swaylock"
    "waybar"
    "wofi"
)

for dir in "${CONFIG_ENTRIES[@]}"; do
    TARGET="$HOME/.config/$dir"
    if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
        info "Backing up existing directory $TARGET -> $BACKUP_DIR/.config/$dir"
        mkdir -p "$BACKUP_DIR/.config"
        mv "$TARGET" "$BACKUP_DIR/.config/$dir"
        BACKUP_OCCURRED=true
    elif [[ -L "$TARGET" ]]; then
        LINK_TARGET="$(readlink -f "$TARGET")"
        if [[ "$LINK_TARGET" != "$DOTFILES_DIR/.config/$dir" ]]; then
            info "Removing stale symlink $TARGET"
            rm -rf "$TARGET"
        fi
    fi
done

if [[ "$BACKUP_OCCURRED" = true ]]; then
    success "Existing conflicting files backed up to: $BACKUP_DIR"
else
    rm -rf "$BACKUP_DIR"
fi

info "Stowing dotfiles into $HOME using GNU Stow..."
# Run stow targeting $HOME
(cd "$DOTFILES_DIR" && stow -v -t "$HOME" .)
success "Dotfiles stowed successfully."

# ------------------------------------------------------------------------------
# 8. Post-Install Configurations & Services
# ------------------------------------------------------------------------------
# Enable essential systemd services
info "Enabling essential system services..."
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
sudo systemctl enable docker.service 2>/dev/null || true
sudo usermod -aG docker "$USER" 2>/dev/null || true

# Setup SDDM Login Manager with HyprV sdt Theme
info "Setting up SDDM Display Manager with HyprV theme..."
if [[ ! -d "/usr/share/sddm/themes/sdt" ]]; then
    info "Downloading HyprV sdt SDDM theme..."
    TEMP_SDDM="$(mktemp -d)"
    git clone --depth 1 --filter=blob:none --sparse https://github.com/SolDoesTech/HyprV4.git "$TEMP_SDDM"
    (cd "$TEMP_SDDM" && git sparse-checkout set Extras/sdt)
    sudo cp -r "$TEMP_SDDM/Extras/sdt" /usr/share/sddm/themes/
    sudo chown -R "$USER:$USER" /usr/share/sddm/themes/sdt
    rm -rf "$TEMP_SDDM"
    success "sdt theme installed."
fi

# Set sdt as active theme in SDDM configuration
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=sdt" | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null

# Sync active wallpaper to sdt theme
WALLPAPER_SRC=""
if [[ -f "$HOME/.config/hypr/wallpaper.jpg" ]]; then
    WALLPAPER_SRC="$HOME/.config/hypr/wallpaper.jpg"
elif [[ -f "$DOTFILES_DIR/.config/hypr/wallpaper.jpg" ]]; then
    WALLPAPER_SRC="$DOTFILES_DIR/.config/hypr/wallpaper.jpg"
fi

if [[ -n "$WALLPAPER_SRC" && -d "/usr/share/sddm/themes/sdt" ]]; then
    sudo rm -f /usr/share/sddm/themes/sdt/wallpaper.jpg
    sudo cp -f "$WALLPAPER_SRC" /usr/share/sddm/themes/sdt/wallpaper.jpg
    sudo chmod 644 /usr/share/sddm/themes/sdt/wallpaper.jpg
fi



# Enable SDDM service
info "Enabling SDDM service..."
sudo systemctl enable sddm 2>/dev/null || true
success "SDDM display manager configured and enabled."

# Change default shell to ZSH if it is not already
CURRENT_SHELL="$(basename "$SHELL")"
if [[ "$CURRENT_SHELL" != "zsh" ]]; then
    if command -v zsh &>/dev/null; then
        ZSH_PATH="$(command -v zsh)"
        info "Setting default shell to $ZSH_PATH..."
        chsh -s "$ZSH_PATH" "$USER" || warn "Could not change default shell automatically. Run 'chsh -s $(command -v zsh)' manually."
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo -e "${GREEN}${BOLD}             Dotfiles Setup Completed Successfully!             ${NC}"
echo -e "${GREEN}${BOLD}================================================================${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo -e " 1. ${BOLD}Install Tmux Plugins:${NC} Open tmux and press ${BOLD}Ctrl+b${NC} then ${BOLD}Shift+i${NC} (I)."
echo -e " 2. ${BOLD}Start Hyprland:${NC} Log in or run ${BOLD}Hyprland${NC}."
echo -e " 3. ${BOLD}Telegram Theme:${NC} In Telegram Desktop, open or apply ${BOLD}~/.local/share/TelegramDesktop/themes/catppuccin-mocha.tdesktop-theme${NC}."
echo ""

