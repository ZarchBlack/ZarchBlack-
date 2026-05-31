#!/bin/bash
#
# ZarchBlack Installer - Quick Launch Script
# Run with: sudo bash <(curl -fsSL https://raw.githubusercontent.com/ZarchBlack/zarchblack/main/install.sh)

set +e

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${PURPLE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║              ⚡ ZarchBlack Arch Installer v1.0 ⚡                             ║
║                                                                               ║
║         Freedom • Power • Simplicity — Arch Linux, ZarchBlack Style          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ── Preflight Checks ──────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo ""
    echo "Please run:"
    echo -e "  ${CYAN}sudo bash <(curl -fsSL https://raw.githubusercontent.com/ZarchBlack/zarchblack/main/install.sh)${NC}"
    exit 1
fi

echo -e "${CYAN}Checking internet connection...${NC}"
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    echo -e "${RED}Error: No internet connection${NC}"
    echo "Please connect to the internet and try again."
    echo ""
    echo "For WiFi, use: iwctl"
    exit 1
fi
echo -e "${GREEN}✓ Internet connected${NC}"

if [[ ! -f /etc/arch-release ]]; then
    echo -e "${RED}Error: This script must be run from the Arch Linux live ISO${NC}"
    exit 1
fi

# ── Dependencies ──────────────────────────────────────────────────────────────
echo -e "${CYAN}Installing dependencies...${NC}"
pacman -Sy --noconfirm --needed gum arch-install-scripts parted dosfstools btrfs-progs &>/dev/null || true
echo -e "${GREEN}✓ Dependencies installed${NC}"

# ── Download Installer ────────────────────────────────────────────────────────
INSTALL_DIR=$(mktemp -d)
trap 'rm -rf "$INSTALL_DIR"' EXIT
cd "$INSTALL_DIR"

echo -e "${CYAN}Downloading ZarchBlack Installer...${NC}"
INSTALLER_URL="https://raw.githubusercontent.com/ZarchBlack/zarchblack/main/zarch-install.sh"
curl -fsSL "$INSTALLER_URL" -o zarch-install.sh
if [[ ! -s zarch-install.sh ]]; then
    echo -e "${RED}Error: Failed to download installer (empty file)${NC}"
    exit 1
fi
chmod +x zarch-install.sh
echo -e "${GREEN}✓ Installer downloaded${NC}"

# ── Download KDE Setup Script ─────────────────────────────────────────────────
echo -e "${CYAN}Downloading ZarchBlack KDE setup script...${NC}"
KDE_URL="https://raw.githubusercontent.com/ZarchBlack/zarchblack/main/zarch-kde.sh"
curl -fsSL "$KDE_URL" -o /root/zarch-kde.sh 2>/dev/null || {
    echo -e "${CYAN}Note: KDE script will be downloaded during installation${NC}"
}
[[ -f /root/zarch-kde.sh ]] && chmod +x /root/zarch-kde.sh
echo -e "${GREEN}✓ Ready to install${NC}"

# ── Launch ────────────────────────────────────────────────────────────────────
echo -e "${PURPLE}Starting ZarchBlack installer...${NC}"
sleep 1
exec bash zarch-install.sh
