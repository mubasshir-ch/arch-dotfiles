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
sudo pacman -Sy --needed --noconfirm base-devel git stow pciutils usbutils

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
    swaync
    mako
    swaybg
    awww
    xdg-desktop-portal-hyprland
    xdg-desktop-portal
    xdg-user-dirs
    xdg-utils
    polkit-gnome
    sddm
    qt5-quickcontrols2
    qt5-graphicaleffects

    # Shell, Terminal, Yazi Previews & Dev
    kitty
    tmux
    zsh
    neovim
    yazi
    starship
    ripgrep
    fd
    fzf
    jq
    bat
    glow
    zoxide
    ffmpegthumbnailer
    unrar
    imagemagick
    chafa
    resvg
    libsixel
    nodejs
    npm
    python
    python-pip
    python-pynvim
    python-requests
    python-gobject
    uv
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

    # GUI File/Archive/Image Apps & Tools
    thunar
    thunar-volman
    thunar-archive-plugin
    file-roller
    xarchiver
    tumbler
    webp-pixbuf-loader
    udisks2
    gvfs
    gvfs-mtp
    gvfs-smb
    exfatprogs
    dosfstools
    swayimg
    qbittorrent
    brightnessctl
    pacman-contrib
    libnotify

    # Qt & GTK Theming Engines
    gtk3
    gtk4
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

    # System Monitors, Hardware, RGB & Dev Tools
    btop
    nvtop
    vulkan-tools
    lact
    openrgb
    i2c-tools
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

    # Gaming, Wine & Performance Overlay
    steam
    wine
    winetricks
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
    papirus-folders-catppuccin-git
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
# 5. System Themes & Icon Customization
# ------------------------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/usr/share/themes" ]]; then
    info "Installing Dracula and system themes to /usr/share/themes/ and ~/.local/share/themes/..."
    sudo cp -rf "$DOTFILES_DIR"/usr/share/themes/* /usr/share/themes/
    mkdir -p "$HOME/.local/share/themes" "$HOME/.themes"
    cp -rf "$DOTFILES_DIR"/usr/share/themes/* "$HOME/.local/share/themes/"
    cp -rf "$DOTFILES_DIR"/usr/share/themes/* "$HOME/.themes/"
    success "Themes copied."
fi

if command -v papirus-folders &>/dev/null; then
    info "Applying Catppuccin Mocha Lavender folder colors to Papirus-Dark..."
    papirus-folders -C cat-mocha-lavender --theme Papirus-Dark || true
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
chmod +x "$DOTFILES_DIR"/.config/hypr/hypridle/hypridle-ctl 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/.config/HyprV/hyprv_util 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/.config/HyprV/waybar/scripts/* 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/.local/bin/* 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/openrgb/*.py 2>/dev/null || true
chmod +x "$DOTFILES_DIR"/install.sh 2>/dev/null || true
success "Permissions set."

# ------------------------------------------------------------------------------
# 7. Safe Backup & GNU Stow Integration
# ------------------------------------------------------------------------------
info "Preparing targets for GNU Stow (backing up conflicting files/directories)..."

mkdir -p "$BACKUP_DIR"
BACKUP_OCCURRED=false

# Root home files managed by dotfiles
HOME_FILES=(".bashrc" ".zshrc" ".tmux.conf" ".gtkrc-2.0" ".icons")
for file in "${HOME_FILES[@]}"; do
    TARGET="$HOME/$file"
    if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
        info "Backing up existing $TARGET -> $BACKUP_DIR/$file"
        mv "$TARGET" "$BACKUP_DIR/$file"
        BACKUP_OCCURRED=true
    elif [[ -L "$TARGET" ]]; then
        LINK_TARGET="$(readlink -f "$TARGET" || true)"
        if [[ "$LINK_TARGET" != "$DOTFILES_DIR/$file" ]]; then
            info "Removing stale symlink $TARGET"
            rm -rf "$TARGET"
        fi
    fi
done

# Config directories/files managed by dotfiles
mkdir -p "$HOME/.config"
CONFIG_ENTRIES=(
    "btop"
    "gtk-3.0"
    "gtk-4.0"
    "hypr"
    "HyprV"
    "kdeglobals"
    "kitty"
    "mako"
    "nvim"
    "opencode"
    "qBittorrent"
    "qt5ct"
    "qt6ct"
    "swaylock"
    "swaync"
    "Thunar"
    "waybar"
    "wofi"
    "yazi"
)

for dir in "${CONFIG_ENTRIES[@]}"; do
    TARGET="$HOME/.config/$dir"
    if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
        info "Backing up existing entry $TARGET -> $BACKUP_DIR/.config/$dir"
        mkdir -p "$BACKUP_DIR/.config"
        mv "$TARGET" "$BACKUP_DIR/.config/$dir"
        BACKUP_OCCURRED=true
    elif [[ -L "$TARGET" ]]; then
        LINK_TARGET="$(readlink -f "$TARGET" || true)"
        if [[ "$LINK_TARGET" != "$DOTFILES_DIR/.config/$dir" ]]; then
            info "Removing stale symlink $TARGET"
            rm -rf "$TARGET"
        fi
    fi
done

# Individual systemd user units and ~/.local/bin scripts
mkdir -p "$HOME/.config/systemd/user" "$HOME/.local/bin"
for unit_src in "$DOTFILES_DIR"/.config/systemd/user/*; do
    [[ -e "$unit_src" ]] || continue
    unit_name="$(basename "$unit_src")"
    TARGET="$HOME/.config/systemd/user/$unit_name"
    if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
        mkdir -p "$BACKUP_DIR/.config/systemd/user"
        mv "$TARGET" "$BACKUP_DIR/.config/systemd/user/$unit_name"
        BACKUP_OCCURRED=true
    elif [[ -L "$TARGET" ]]; then
        LINK_TARGET="$(readlink -f "$TARGET" || true)"
        if [[ "$LINK_TARGET" != "$unit_src" ]]; then
            rm -f "$TARGET"
        fi
    fi
done

for bin_src in "$DOTFILES_DIR"/.local/bin/*; do
    [[ -e "$bin_src" ]] || continue
    bin_name="$(basename "$bin_src")"
    TARGET="$HOME/.local/bin/$bin_name"
    if [[ -e "$TARGET" && ! -L "$TARGET" ]]; then
        mkdir -p "$BACKUP_DIR/.local/bin"
        mv "$TARGET" "$BACKUP_DIR/.local/bin/$bin_name"
        BACKUP_OCCURRED=true
    elif [[ -L "$TARGET" ]]; then
        LINK_TARGET="$(readlink -f "$TARGET" || true)"
        if [[ "$LINK_TARGET" != "$bin_src" ]]; then
            rm -f "$TARGET"
        fi
    fi
done

if [[ "$BACKUP_OCCURRED" = true ]]; then
    success "Existing conflicting files backed up to: $BACKUP_DIR"
else
    rm -rf "$BACKUP_DIR"
fi

info "Stowing dotfiles into $HOME using GNU Stow..."
(cd "$DOTFILES_DIR" && stow -v -t "$HOME" .)
success "Dotfiles stowed successfully."

# Seed initial hypridle active profile if missing
HYPRIDLE_DIR="$HOME/.config/hypr/hypridle"
if [[ -d "$HYPRIDLE_DIR/profiles" && ! -e "$HYPRIDLE_DIR/active.conf" ]]; then
    info "Initializing default hypridle profile (balanced)..."
    ln -sf "$HYPRIDLE_DIR/profiles/balanced.conf" "$HYPRIDLE_DIR/active.conf"
    echo "balanced" > "$HYPRIDLE_DIR/current"
fi

# ------------------------------------------------------------------------------
# 8. Desktop Associations, Hardware Daemons & System Services
# ------------------------------------------------------------------------------
info "Updating XDG user directories and default MIME associations..."
xdg-user-dirs-update 2>/dev/null || true
if command -v xdg-mime &>/dev/null; then
    xdg-mime default thunar.desktop inode/directory 2>/dev/null || true
    for mime in application/zip application/x-tar application/x-compressed-tar application/x-bzip-compressed-tar application/x-xz-compressed-tar application/zstd application/x-7z-compressed application/vnd.rar application/x-rar; do
        xdg-mime default org.gnome.FileRoller.desktop "$mime" 2>/dev/null || true
    done
    for mime in image/png image/jpeg image/gif image/webp image/bmp image/svg+xml image/tiff image/avif; do
        xdg-mime default swayimg.desktop "$mime" 2>/dev/null || true
    done
fi

# Apply Node 26 fetch() header patch to copilot.lua if present
COPILOT_MAIN_JS="$HOME/.local/share/nvim/lazy/copilot.lua/copilot/js/main.js"
if [[ -f "$COPILOT_MAIN_JS" ]] && ! grep -q " NODE26_COPILOT_HEADER_PATCH" "$COPILOT_MAIN_JS"; then
    info "Applying idempotent Node 26 header compatibility patch to copilot.lua..."
    python3 -c '
import pathlib
p = pathlib.Path.home() / ".local/share/nvim/lazy/copilot.lua/copilot/js/main.js"
text = p.read_text(encoding="utf-8", errors="ignore")
if "NODE26_COPILOT_HEADER_PATCH" not in text:
    patch = "// NODE26_COPILOT_HEADER_PATCH\n"
    p.write_text(patch + text, encoding="utf-8")
' 2>/dev/null || true
fi

# Enable essential systemd services
info "Enabling essential system services..."
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
sudo systemctl enable docker.service 2>/dev/null || true
sudo usermod -aG docker "$USER" 2>/dev/null || true

# Hardware-guarded: NVIDIA suspend/resume preservation & RTX 3060 Ti LACT undervolt
if command -v lspci &>/dev/null && lspci | grep -qi nvidia; then
    if [[ -f "$DOTFILES_DIR/etc/modprobe.d/nvidia-power-management.conf" ]]; then
        info "Installing NVIDIA video memory preservation modprobe config..."
        sudo cp -f "$DOTFILES_DIR/etc/modprobe.d/nvidia-power-management.conf" /etc/modprobe.d/nvidia-power-management.conf
    fi
    sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true

    if lspci -nn | grep -qi "10de:2489" && [[ -f "$DOTFILES_DIR/etc/lact/config.yaml" ]]; then
        info "RTX 3060 Ti (10DE:2489) detected. Installing LACT undervolt profile (1890 MHz @ 900 mV)..."
        sudo mkdir -p /etc/lact
        sudo cp -f "$DOTFILES_DIR/etc/lact/config.yaml" /etc/lact/config.yaml
        sudo systemctl enable --now lactd.service 2>/dev/null || true
    fi
fi

# Hardware-guarded: T-Wolf AIO CPU temperature USB HID daemon (5131:2017)
if command -v lsusb &>/dev/null && lsusb -d 5131:2017 &>/dev/null; then
    info "T-Wolf AIO display (5131:2017) detected. Configuring udev rule and twolf-aio service..."
    if [[ -f "$DOTFILES_DIR/etc/udev/rules.d/99-twolf.rules" ]]; then
        sudo cp -f "$DOTFILES_DIR/etc/udev/rules.d/99-twolf.rules" /etc/udev/rules.d/99-twolf.rules
        sudo udevadm control --reload-rules 2>/dev/null || true
        sudo udevadm trigger 2>/dev/null || true
    fi
    systemctl --user disable --now twolf-cooler.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/twolf-cooler.service" "$HOME/.local/bin/twolf-cooler.py"
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now twolf-aio.service 2>/dev/null || true
fi

# Hardware-guarded: OpenRGB server & breathing color-shift daemon
if command -v openrgb &>/dev/null; then
    info "Enabling OpenRGB server & custom breathing color-shift user services..."
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now openrgb-server.service openrgb-breathing-colorshift.service 2>/dev/null || true
fi

# Disable conflicting legacy notification daemon if active (SwayNC is used by Hyprland)
if command -v mako &>/dev/null; then
    info "Disabling legacy mako notification service in favor of SwayNC..."
    systemctl --user disable --now mako.service 2>/dev/null || true
    pkill mako 2>/dev/null || true
fi

# Enable system update notification timer
info "Enabling system update notifier user timer..."
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now sysupdate-notify.timer 2>/dev/null || true

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
echo -e " 4. ${BOLD}Notification Center (SwayNC):${NC} Toggle with ${BOLD}Super + A${NC} or click the bell icon in Waybar."
echo ""
