#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                               ║
# ║               ⚡ ZarchBlack KDE Plasma Setup v1.0 ⚡                          ║
# ║                                                                               ║
# ║              Installs ZarchBlack KDE Plasma desktop environment               ║
# ║                                                                               ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
#
# Called by zarch-install.sh after base system install
# Usage: bash zarch-kde.sh [aur_helper] [filesystem]
#

set -Eeuo pipefail

AUR_HELPER="${1:-paru}"
FILESYSTEM="${2:-btrfs}"
VERSION="1.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ────────────────────────────────────────────────────────────────────────────────
# HELPERS
# ────────────────────────────────────────────────────────────────────────────────

have_gum() { command -v gum &>/dev/null; }

show_header() {
    clear
    if have_gum; then
        gum style \
            --foreground 141 --border-foreground 141 --border double \
            --align center --width 72 --margin "1 2" --padding "1 2" \
            "⚡ ZarchBlack KDE Setup v$VERSION ⚡" \
            "" \
            "Freedom • Power • Simplicity"
    else
        echo -e "${PURPLE}"
        cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║               ⚡ ZarchBlack KDE Plasma Setup v1.0 ⚡                          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"
    fi
}

show_step() {
    if have_gum; then
        gum style --foreground 141 --bold --margin "1 2" "$1"
    else
        echo -e "${PURPLE}▶ $1${NC}"
    fi
}

show_info() {
    if have_gum; then
        gum style --foreground 81 --margin "0 2" "$1"
    else
        echo -e "${CYAN}  $1${NC}"
    fi
}

show_success() {
    if have_gum; then
        gum style --foreground 82 "  ✓ $1"
    else
        echo -e "${GREEN}  ✓ $1${NC}"
    fi
}

show_warning() {
    if have_gum; then
        gum style --foreground 214 "  ⚠ $1"
    else
        echo -e "${YELLOW}  ⚠ $1${NC}"
    fi
}

install_packages() {
    local failed_packages=()
    local spinner=("|" "/" "-" "\\")

    for pkg in "$@"; do
        local i=0
        if have_gum; then
            gum spin --spinner dot --title "  Installing $pkg..." -- \
                sudo pacman -S --noconfirm --needed "$pkg" &>/tmp/zarch-install.log \
                || failed_packages+=("$pkg")
        else
            echo -ne "${CYAN}[ ] Installing ${pkg}...${NC}"
            (
                while true; do
                    echo -ne "\r${CYAN}[${spinner[i]}] Installing ${pkg}...${NC}"
                    i=$(( (i + 1) % 4 ))
                    sleep 0.1
                done
            ) &
            SPIN_PID=$!
            if sudo pacman -S --noconfirm --needed "$pkg" &>/tmp/zarch-install.log; then
                kill $SPIN_PID 2>/dev/null; wait $SPIN_PID 2>/dev/null
                echo -e "\r${GREEN}[✓] Installed ${pkg}${NC}"
            else
                kill $SPIN_PID 2>/dev/null; wait $SPIN_PID 2>/dev/null
                echo -e "\r${RED}[✗] Failed: ${pkg}${NC}"
                failed_packages+=("$pkg")
            fi
        fi
    done

    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        show_warning "Failed packages: ${failed_packages[*]}"
        show_warning "You can install them manually later."
    fi
}

install_aur_packages() {
    local failed_packages=()
    for pkg in "$@"; do
        if have_gum; then
            gum spin --spinner dot --title "  Installing $pkg (AUR)..." -- \
                "$AUR_HELPER" -S --noconfirm --needed "$pkg" &>/tmp/zarch-aur.log \
                || failed_packages+=("$pkg")
        else
            echo -ne "${CYAN}[ ] Installing ${pkg} (AUR)...${NC}"
            if "$AUR_HELPER" -S --noconfirm --needed "$pkg" &>/tmp/zarch-aur.log; then
                echo -e "\r${GREEN}[✓] Installed ${pkg}${NC}"
            else
                echo -e "\r${RED}[✗] Failed: ${pkg}${NC}"
                failed_packages+=("$pkg")
            fi
        fi
    done
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        show_warning "AUR Failed: ${failed_packages[*]}"
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# INSTALL AUR HELPER
# ────────────────────────────────────────────────────────────────────────────────

install_aur_helper() {
    show_step "Installing AUR helper: $AUR_HELPER"

    if command -v "$AUR_HELPER" &>/dev/null; then
        show_success "$AUR_HELPER already installed"
        return 0
    fi

    sudo pacman -S --needed --noconfirm git base-devel &>/dev/null

    local tmpdir
    tmpdir=$(mktemp -d)
    cd "$tmpdir"

    git clone "https://aur.archlinux.org/${AUR_HELPER}.git" . &>/dev/null
    makepkg -si --noconfirm &>/dev/null

    cd ~
    rm -rf "$tmpdir"
    show_success "$AUR_HELPER installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# KDE PLASMA CORE
# ────────────────────────────────────────────────────────────────────────────────

install_kde_core() {
    show_step "Installing KDE Plasma Core"
    show_info "This may take a while..."

    install_packages \
        plasma-desktop plasma-workspace plasma-nm plasma-pa \
        plasma-browser-integration plasma-integration plasma-systemmonitor \
        plasma-thunderbolt plasma-vault plasma-disks plasma-keyboard \
        plasma-activities plasma-activities-stats plasma-firewall \
        plasma-login-manager plasma-workspace-wallpapers plasma5support \
        libplasma kwin kwin-x11 kwayland \
        bluedevil breeze breeze-gtk drkonqi kde-gtk-config \
        kde-system-meta kgamma kglobalacceld kpipewire kscreenlocker \
        kscreen kwrited layer-shell-qt milou powerdevil \
        qqc2-breeze-style systemsettings kinfocenter krunner \
        sddm sddm-kcm \
        kdeplasma-addons

    show_success "KDE Plasma Core installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# KDE APPLICATIONS
# ────────────────────────────────────────────────────────────────────────────────

install_kde_apps() {
    show_step "Installing KDE Applications"

    install_packages \
        ark dolphin dolphin-plugins filelight gwenview okular spectacle \
        kamera kcolorchooser kdegraphics-thumbnailers colord-kde \
        kate kcharselect kdialog kfind kgpg konsole ksystemlog \
        kwalletmanager partitionmanager qalculate-qt kcalc sweeper \
        yakuake kclock kcron kjournald koko \
        audiocd-kio ffmpegthumbs phonon-qt6-vlc k3b kamoso elisa kmix \
        discover kde-cli-tools ksshaskpass ksystemstats kwallet-pam \
        packagekit-qt6 polkit-kde-agent systemdgenie \
        kdeconnect kdenetwork-filesharing kio-admin kio-extras \
        kio-gdrive kio-zeroconf konversation krdc krfb kget \
        markdownpart isoimagewriter \
        akregator kaddressbook merkuro

    show_success "KDE Applications installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# ZARCHBLACK CUSTOM PACKAGES
# ────────────────────────────────────────────────────────────────────────────────

install_zarchblack_packages() {
    show_step "Installing ZarchBlack Custom Packages"
    show_info "Fetching from ZarchBlack repository..."

    install_packages \
        zpackagemanager \
        zarchguard \
        zarch-hacking \
        calamares \
        kde-material-you-colors \
        neo-candy-icons-git \
        slot-symbolic-dark-icons \
        variety \
        thorium-browser-bin

    show_success "ZarchBlack packages installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# THEMING & VISUAL
# ────────────────────────────────────────────────────────────────────────────────

install_theming() {
    show_step "Installing Theming & Visual Components"

    install_packages \
        kvantum kvantum-qt5 qt5ct qt6-base qt6-wayland qt6-declarative \
        qt6-multimedia-ffmpeg qt5-declarative qt5-wayland \
        adw-gtk-theme gnome-themes-extra materia-gtk-theme \
        bibata-cursor-theme \
        noto-fonts noto-fonts-emoji noto-fonts-cjk \
        ttf-jetbrains-mono ttf-jetbrains-mono-nerd \
        ttf-fira-code ttf-hack ttf-hack-nerd \
        ttf-roboto ttf-dejavu ttf-liberation \
        awesome-terminal-fonts cantarell-fonts \
        plymouth breeze-plymouth plymouth-kcm

    # AUR theming packages
    install_aur_packages \
        kwin-effect-rounded-corners-git \
        plasma6-applets-panel-colorizer \
        colloid-cursors-git \
        vimix-cursors

    show_success "Theming installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# APPLICATIONS
# ────────────────────────────────────────────────────────────────────────────────

install_applications() {
    show_step "Installing Applications"

    install_packages \
        brave-bin \
        libreoffice-still \
        gimp krita \
        vlc audacity \
        keepassxc \
        qbittorrent \
        calibre \
        meld \
        localsend \
        btop htop nvtop \
        fastfetch \
        tmux screen \
        neovim vim \
        bat eza fd fzf ripgrep \
        ncdu dust duf \
        git-lfs \
        flatpak flatpak-kcm \
        timeshift \
        firewalld

    show_success "Applications installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# SYSTEM SERVICES
# ────────────────────────────────────────────────────────────────────────────────

configure_services() {
    show_step "Configuring System Services"

    local services=(
        sddm
        NetworkManager
        bluetooth
        cups
        firewalld
        fstrim.timer
        reflector.timer
        systemd-timesyncd
    )

    for service in "${services[@]}"; do
        sudo systemctl enable "$service" &>/dev/null \
            && show_success "Enabled: $service" \
            || show_warning "Could not enable: $service"
    done
}

# ────────────────────────────────────────────────────────────────────────────────
# PLYMOUTH THEME
# ────────────────────────────────────────────────────────────────────────────────

configure_plymouth() {
    show_step "Configuring Plymouth Boot Splash"

    if [[ -d /usr/share/plymouth/themes/zarchblack ]]; then
        sudo plymouth-set-default-theme zarchblack -R &>/dev/null \
            && show_success "Plymouth theme: zarchblack" \
            || show_warning "Could not set Plymouth theme"
    else
        show_warning "ZarchBlack Plymouth theme not found — using breeze"
        sudo plymouth-set-default-theme breeze -R &>/dev/null || true
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# SDDM THEME
# ────────────────────────────────────────────────────────────────────────────────

configure_sddm() {
    show_step "Configuring SDDM Login Screen"

    sudo mkdir -p /etc/sddm.conf.d
    cat << 'EOF' | sudo tee /etc/sddm.conf.d/zarchblack.conf > /dev/null
[Theme]
Current=ZeroDark

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Wayland]
SessionDir=/usr/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions
EOF
    show_success "SDDM configured"
}

# ────────────────────────────────────────────────────────────────────────────────
# PACMAN CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

configure_pacman() {
    show_step "Configuring Pacman"

    sudo sed -i 's/^#Color/Color/'                   /etc/pacman.conf
    sudo sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
    sudo sed -i 's/^#ILoveCandy/ILoveCandy/'           /etc/pacman.conf
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

    show_success "Pacman configured"
}

# ────────────────────────────────────────────────────────────────────────────────
# ZRAM (if not already set)
# ────────────────────────────────────────────────────────────────────────────────

configure_zram() {
    if [[ ! -f /etc/systemd/zram-generator.conf ]]; then
        show_step "Configuring ZRAM Swap"
        sudo pacman -S --noconfirm --needed zram-generator &>/dev/null
        cat << 'EOF' | sudo tee /etc/systemd/zram-generator.conf > /dev/null
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
        show_success "ZRAM configured"
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# WAYLAND SESSION
# ────────────────────────────────────────────────────────────────────────────────

configure_wayland() {
    show_step "Configuring Wayland Session"

    cat << 'EOF' | sudo tee -a /etc/environment > /dev/null
# Wayland
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
GDK_BACKEND=wayland,x11
SDL_VIDEODRIVER=wayland
MOZ_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=auto
EOF
    show_success "Wayland environment configured"
}

# ────────────────────────────────────────────────────────────────────────────────
# FINALIZE
# ────────────────────────────────────────────────────────────────────────────────

finalize() {
    show_step "Finalizing ZarchBlack Setup"

    # XDG user dirs
    xdg-user-dirs-update &>/dev/null || true

    # Flatpak remote
    flatpak remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo &>/dev/null || true

    # Clean package cache
    sudo pacman -Scc --noconfirm &>/dev/null || true

    show_success "Cleanup done"
}

# ────────────────────────────────────────────────────────────────────────────────
# MAIN
# ────────────────────────────────────────────────────────────────────────────────

main() {
    show_header

    if have_gum; then
        gum style --foreground 245 --margin "0 2" \
            "AUR Helper: $AUR_HELPER | Filesystem: $FILESYSTEM"
    else
        echo -e "${CYAN}  AUR Helper: $AUR_HELPER | Filesystem: $FILESYSTEM${NC}"
    fi
    echo ""

    install_aur_helper
    install_kde_core
    install_kde_apps
    install_zarchblack_packages
    install_theming
    install_applications
    configure_services
    configure_plymouth
    configure_sddm
    configure_pacman
    configure_zram
    configure_wayland
    finalize

    echo ""
    if have_gum; then
        gum style --foreground 82 --bold --border double --border-foreground 82 \
            --align center --width 60 --margin "1 2" --padding "1 2" \
            "⚡ ZarchBlack KDE Setup Complete! ⚡" \
            "" \
            "Freedom • Power • Simplicity" \
            "" \
            "Reboot to enjoy your new system!" \
            "  sudo reboot"
    else
        echo -e "${GREEN}"
        cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║           ⚡ ZarchBlack KDE Setup Complete! ⚡         ║
║                                                       ║
║          Freedom  •  Power  •  Simplicity             ║
║                                                       ║
║        Reboot to enjoy your new system!               ║
║              sudo reboot                              ║
╚═══════════════════════════════════════════════════════╝
EOF
        echo -e "${NC}"
    fi
}

main "$@"
