#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                               ║
# ║                    ⚡ ZarchBlack Arch Installer v1.0 ⚡                       ║
# ║                                                                               ║
# ║              Freedom • Power • Simplicity — Arch Linux, Done Right           ║
# ║                                                                               ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
#
# Author: ZarchBlack Team
# License: GPL-3.0
#

set -Eeuo pipefail

# ────────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

VERSION="1.0"
SCRIPT_NAME="ZarchBlack Installer"

ZARCH_KDE_URL="https://raw.githubusercontent.com/ZarchBlack/zarchblack/main/zarch-kde.sh"
MOUNTPOINT="/mnt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

declare -A CONFIG
CONFIG[locale]="en_US.UTF-8"
CONFIG[keyboard]="us"
CONFIG[timezone]="UTC"
CONFIG[hostname]="zarchblack"
CONFIG[username]=""
CONFIG[user_password]=""
CONFIG[root_password]=""
CONFIG[disk]=""
CONFIG[filesystem]="btrfs"
CONFIG[encrypt]="no"
CONFIG[encrypt_boot]="no"
CONFIG[encrypt_password]=""
CONFIG[swap]="zram"
CONFIG[swap_algo]="zstd"
CONFIG[gfx_driver]="mesa"
CONFIG[parallel_downloads]="5"
CONFIG[aur_helper]="paru"
CONFIG[extra_kernel]=""
CONFIG[uefi]="no"
CONFIG[boot_part]=""
CONFIG[root_part]=""
CONFIG[root_device]=""
CONFIG[partition_mode]="auto"
CONFIG[reuse_efi]="no"

# ────────────────────────────────────────────────────────────────────────────────
# ERROR HANDLING
# ────────────────────────────────────────────────────────────────────────────────

have_gum() { command -v gum &>/dev/null; }

on_err() {
    local exit_code=$?
    local line_no=${1:-?}
    local cmd=${2:-?}
    if have_gum; then
        gum style --foreground 196 --bold --margin "1 2" \
            "❌ ERROR (exit=$exit_code) at line $line_no" \
            "$cmd"
        echo ""
        gum input --placeholder "Press Enter to exit..."
    else
        echo -e "${RED}ERROR (exit=$exit_code) at line $line_no${NC}"
        echo -e "${RED}$cmd${NC}"
    fi
    exit "$exit_code"
}

trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR

# ────────────────────────────────────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ────────────────────────────────────────────────────────────────────────────────

setup_sudo() {
    if [[ ${EUID:-0} -eq 0 ]]; then
        SUDO_CMD=""
    else
        SUDO_CMD="sudo"
    fi
}

check_root() {
    if [[ ${EUID:-0} -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    setup_sudo
}

check_uefi() {
    if [[ -d /sys/firmware/efi/efivars ]]; then
        CONFIG[uefi]="yes"
    else
        CONFIG[uefi]="no"
    fi
}

INTERNET_OK="no"
check_internet() {
    [[ "$INTERNET_OK" == "yes" ]] && return 0
    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        INTERNET_OK="yes"
        return 0
    fi
    echo -e "${RED}Error: No internet connection${NC}"
    exit 1
}

ensure_dependencies() {
    local deps_needed=()
    command -v gum &>/dev/null       || deps_needed+=("gum")
    command -v parted &>/dev/null    || deps_needed+=("parted")
    command -v arch-chroot &>/dev/null || deps_needed+=("arch-install-scripts")
    command -v sgdisk &>/dev/null    || deps_needed+=("gptfdisk")
    command -v mkfs.btrfs &>/dev/null || deps_needed+=("btrfs-progs")
    command -v mkfs.fat &>/dev/null  || deps_needed+=("dosfstools")
    command -v mkfs.ext4 &>/dev/null || deps_needed+=("e2fsprogs")
    command -v curl &>/dev/null      || deps_needed+=("curl")
    if [[ ${#deps_needed[@]} -gt 0 ]]; then
        echo -e "${CYAN}Installing required dependencies...${NC}"
        pacman -Sy --noconfirm "${deps_needed[@]}" &>/dev/null
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# GUM UI HELPERS
# ────────────────────────────────────────────────────────────────────────────────

show_header() {
    clear
    gum style \
        --foreground 141 --border-foreground 141 --border double \
        --align center --width 72 --margin "1 2" --padding "1 2" \
        "⚡ $SCRIPT_NAME v$VERSION ⚡" \
        "" \
        "Freedom • Power • Simplicity"
}

show_submenu_header() {
    gum style --foreground 141 --bold --margin "1 2" "$1"
}

show_info()    { gum style --foreground 81  --margin "0 2" "$1"; }
show_success() { gum style --foreground 82  "  ✓ $1"; }
show_error()   { gum style --foreground 196 "  ✗ $1"; }
show_warning() { gum style --foreground 214 "  ⚠ $1"; }

confirm_action() {
    gum confirm --affirmative "Yes" --negative "No" "$1"
}

run_step() {
    local title="$1"; shift
    show_info "$title"
    "$@"
    show_success "${title%...}"
}

# ────────────────────────────────────────────────────────────────────────────────
# 1. LOCALES
# ────────────────────────────────────────────────────────────────────────────────

select_locales() {
    show_header
    show_submenu_header "🗺️  System Locales"
    echo ""
    show_info "Select your system locale"
    echo ""

    local locales=(
        "en_US.UTF-8" "en_GB.UTF-8" "de_DE.UTF-8" "fr_FR.UTF-8"
        "es_ES.UTF-8" "it_IT.UTF-8" "pt_BR.UTF-8" "pt_PT.UTF-8"
        "ru_RU.UTF-8" "ja_JP.UTF-8" "ko_KR.UTF-8" "zh_CN.UTF-8"
        "ar_MA.UTF-8" "ar_SA.UTF-8" "pl_PL.UTF-8" "nl_NL.UTF-8"
        "tr_TR.UTF-8" "sv_SE.UTF-8" "da_DK.UTF-8" "fi_FI.UTF-8"
    )

    local locale_selection=""
    locale_selection=$(printf '%s\n' "${locales[@]}" | gum filter \
        --placeholder "Search locale..." --height 12) || true
    [[ -n "$locale_selection" ]] && CONFIG[locale]="$locale_selection"
    show_success "System locale: ${CONFIG[locale]}"

    echo ""
    show_info "Select your keyboard layout"
    echo ""

    local keyboards=(
        "us" "uk" "de" "fr" "es" "it" "pt-latin9" "br-abnt2"
        "ru" "pl" "cz" "hu" "se" "no" "dk" "fi" "nl" "ara"
        "tr" "gr" "il" "latam" "dvorak" "colemak"
    )

    local kb_selection=""
    kb_selection=$(printf '%s\n' "${keyboards[@]}" | gum filter \
        --placeholder "Search keyboard layout..." --height 12) || true
    if [[ -n "$kb_selection" ]]; then
        CONFIG[keyboard]="$kb_selection"
        loadkeys "$kb_selection" 2>/dev/null || true
    fi
    show_success "Keyboard layout: ${CONFIG[keyboard]}"
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 2. TIMEZONE
# ────────────────────────────────────────────────────────────────────────────────

select_timezone() {
    show_header
    show_submenu_header "🕐 Timezone"
    echo ""
    show_info "Select your timezone"
    echo ""

    local regions=""
    regions=$(find /usr/share/zoneinfo -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | \
              grep -vE '^(\+|posix|right|zoneinfo)$' | sort) || true

    local region=""
    region=$(echo "$regions" | gum filter --placeholder "Search region..." \
        --height 12 --header "Select region:") || true

    if [[ -n "$region" ]]; then
        local cities=""
        cities=$(find "/usr/share/zoneinfo/$region" -type f -printf '%f\n' 2>/dev/null | sort) || true
        if [[ -n "$cities" ]]; then
            local city=""
            city=$(echo "$cities" | gum filter --placeholder "Search city..." \
                --height 12 --header "Select city:") || true
            [[ -n "$city" ]] && CONFIG[timezone]="$region/$city" || CONFIG[timezone]="$region"
        else
            CONFIG[timezone]="$region"
        fi
        show_success "Timezone: ${CONFIG[timezone]}"
    fi
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 3. DISK CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

select_partitioning_mode() {
    show_header
    show_submenu_header "💾 Disk Configuration"
    echo ""

    local mode_options=(
        "Auto    │ Wipe entire disk and partition automatically (Recommended)"
        "Manual  │ Choose existing partitions (dual-boot, custom layouts)"
    )

    local mode_sel=""
    mode_sel=$(printf '%s\n' "${mode_options[@]}" | gum choose --height 4 \
        --header "Select partitioning mode:") || true

    if [[ "$mode_sel" == "Manual"* ]]; then
        CONFIG[partition_mode]="manual"
        manual_partitioning
    else
        CONFIG[partition_mode]="auto"
        select_disk
    fi
}

manual_partitioning() {
    show_header
    show_submenu_header "💾 Manual Partitioning"
    echo ""
    gum style --foreground 226 --bold --margin "0 2" \
        "ℹ️  Your partitions will not be wiped — only assigned ones will be formatted."
    echo ""
    gum style --foreground 245 --margin "0 2" \
        "$(lsblk -o NAME,SIZE,FSTYPE,LABEL,TYPE,MOUNTPOINT 2>/dev/null)"
    echo ""

    if confirm_action "Launch cfdisk to create or modify partitions first?"; then
        local disks=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && disks+=("$line")
        done < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null \
            | { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } | sed 's/  */ /g')
        if [[ ${#disks[@]} -gt 0 ]]; then
            local disk_sel=""
            disk_sel=$(printf '%s\n' "${disks[@]}" | gum choose --height 10 \
                --header "Select disk to open in cfdisk:") || true
            if [[ -n "$disk_sel" ]]; then
                local target_disk
                target_disk=$(echo "$disk_sel" | awk '{print $1}')
                cfdisk "$target_disk" || true
                partprobe "$target_disk" || true
                udevadm settle
            fi
        fi
    fi

    local partitions=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && partitions+=("$line")
    done < <(lsblk -lpno NAME,SIZE,FSTYPE,LABEL 2>/dev/null \
        | { grep -E '^/dev/(sd|nvme|vd|mmcblk)[^ ]*[0-9]' || true; } | sed 's/  */ /g')

    [[ ${#partitions[@]} -eq 0 ]] && { show_error "No partitions found."; return; }

    # Boot partition
    echo ""
    local boot_options=("-- Skip (no separate boot partition) --")
    for p in "${partitions[@]}"; do boot_options+=("$p"); done
    local boot_sel=""
    boot_sel=$(printf '%s\n' "${boot_options[@]}" | gum choose --height 14 \
        --header "Boot / EFI partition:") || true

    if [[ "$boot_sel" == "-- Skip"* ]]; then
        CONFIG[boot_part]=""
        CONFIG[reuse_efi]="no"
    else
        CONFIG[boot_part]=$(echo "$boot_sel" | awk '{print $1}')
        show_success "Boot/EFI partition: ${CONFIG[boot_part]}"
        if [[ "${CONFIG[uefi]}" == "yes" ]]; then
            local efi_action=""
            efi_action=$(printf '%s\n' \
                "Format  │ Wipe and format as FAT32  (single-OS or new ESP)" \
                "Reuse   │ Mount without formatting   (Windows dual-boot)" \
                | gum choose --height 4 --header "What to do with this EFI partition:") || true
            [[ "$efi_action" == "Reuse"* ]] && CONFIG[reuse_efi]="yes" || CONFIG[reuse_efi]="no"
        fi
    fi

    # Root partition
    echo ""
    local root_sel=""
    root_sel=$(printf '%s\n' "${partitions[@]}" | gum choose --height 14 \
        --header "Root ( / ) partition:") || true
    [[ -z "$root_sel" ]] && { show_error "No root partition selected."; return; }
    CONFIG[root_part]=$(echo "$root_sel" | awk '{print $1}')
    show_success "Root partition: ${CONFIG[root_part]}"

    local parent_disk
    parent_disk=$(lsblk -no PKNAME "${CONFIG[root_part]}" 2>/dev/null | head -1)
    CONFIG[disk]="${parent_disk:+/dev/$parent_disk}"
    [[ -z "${CONFIG[disk]}" ]] && CONFIG[disk]="${CONFIG[root_part]}"

    # Filesystem
    select_filesystem
    # Encryption
    configure_encryption
    sleep 0.5
}

select_disk() {
    show_header
    show_submenu_header "💾 Disk Configuration"
    echo ""
    gum style --foreground 196 --bold --margin "0 2" \
        "⚠️  WARNING: The selected disk will be COMPLETELY ERASED!"
    echo ""

    local disks=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && disks+=("$line")
    done < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null | \
        { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } | sed 's/  */ /g')

    [[ ${#disks[@]} -eq 0 ]] && { show_error "No suitable disks found!"; exit 1; }

    local disk_selection=""
    disk_selection=$(printf '%s\n' "${disks[@]}" | gum choose --height 10 \
        --header "Available disks:") || true
    if [[ -n "$disk_selection" ]]; then
        CONFIG[disk]=$(echo "$disk_selection" | awk '{print $1}')
        show_success "Selected disk: ${CONFIG[disk]}"
        echo ""
        gum style --foreground 245 --margin "0 2" \
            "$(lsblk "${CONFIG[disk]}" 2>/dev/null)"
    fi

    echo ""
    select_filesystem
    configure_encryption
    sleep 0.5
}

select_filesystem() {
    echo ""
    show_info "Select filesystem type"
    echo ""
    local filesystems=(
        "btrfs    │ Modern CoW filesystem with snapshots (Recommended)"
        "ext4     │ Traditional reliable filesystem"
        "xfs      │ High-performance filesystem"
    )
    local fs_selection=""
    fs_selection=$(printf '%s\n' "${filesystems[@]}" | gum choose --height 5 \
        --header "Filesystem:") || true
    [[ -n "$fs_selection" ]] && CONFIG[filesystem]=$(echo "$fs_selection" | awk '{print $1}')
    show_success "Filesystem: ${CONFIG[filesystem]}"
}

configure_encryption() {
    echo ""
    show_info "Disk Encryption (LUKS2)"
    echo ""
    if confirm_action "Enable full disk encryption?"; then
        CONFIG[encrypt]="yes"
        local enc_pass1="" enc_pass2=""
        enc_pass1=$(gum input --password --placeholder "Enter encryption password" --width 50) || true
        enc_pass2=$(gum input --password --placeholder "Confirm encryption password" --width 50) || true
        if [[ "$enc_pass1" == "$enc_pass2" && -n "$enc_pass1" ]]; then
            CONFIG[encrypt_password]="$enc_pass1"
            show_success "Disk encryption enabled"
            echo ""
            local encrypt_options=(
                "root      │ Encrypt root only  (Faster boot)"
                "root+boot │ Encrypt root & boot (More secure)"
            )
            local enc_selection=""
            enc_selection=$(printf '%s\n' "${encrypt_options[@]}" | gum choose --height 4 \
                --header "Encryption scope:") || true
            [[ "$enc_selection" == "root+boot"* ]] && CONFIG[encrypt_boot]="yes" || CONFIG[encrypt_boot]="no"
        else
            show_error "Passwords don't match. Encryption disabled."
            CONFIG[encrypt]="no"; CONFIG[encrypt_boot]="no"; CONFIG[encrypt_password]=""
        fi
    else
        CONFIG[encrypt]="no"; CONFIG[encrypt_boot]="no"; CONFIG[encrypt_password]=""
        show_info "Disk encryption disabled"
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# 4. SWAP
# ────────────────────────────────────────────────────────────────────────────────

configure_swap() {
    show_header
    show_submenu_header "🔄 Swap Configuration"
    echo ""
    show_info "Select swap type for your system"
    echo ""
    local swap_options=(
        "zram     │ Compressed RAM swap (Recommended, fast)"
        "file     │ Traditional swap file on disk"
        "none     │ No swap"
    )
    local swap_selection=""
    swap_selection=$(printf '%s\n' "${swap_options[@]}" | gum choose --height 5 \
        --header "Swap type:") || true
    if [[ -n "$swap_selection" ]]; then
        CONFIG[swap]=$(echo "$swap_selection" | awk '{print $1}')
        show_success "Swap type: ${CONFIG[swap]}"
        if [[ "${CONFIG[swap]}" == "zram" ]]; then
            echo ""
            show_info "Select zram compression algorithm"
            echo ""
            local algos=(
                "zstd     │ Best compression ratio (Recommended)"
                "lz4      │ Fastest compression"
                "lzo      │ Balanced speed/ratio"
            )
            local algo_selection=""
            algo_selection=$(printf '%s\n' "${algos[@]}" | gum choose --height 5 \
                --header "Algorithm:") || true
            [[ -n "$algo_selection" ]] && CONFIG[swap_algo]=$(echo "$algo_selection" | awk '{print $1}')
            show_success "Compression: ${CONFIG[swap_algo]}"
        fi
    fi
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 5. HOSTNAME
# ────────────────────────────────────────────────────────────────────────────────

configure_hostname() {
    show_header
    show_submenu_header "💻 Hostname"
    echo ""
    show_info "Enter a hostname for your system"
    echo ""
    local hostname=""
    hostname=$(gum input --placeholder "zarchblack" --value "${CONFIG[hostname]}" \
        --width 40 --header "Hostname:") || true
    if [[ "$hostname" =~ ^[a-z][a-z0-9-]*$ && ${#hostname} -le 63 ]]; then
        CONFIG[hostname]="$hostname"
    else
        show_warning "Invalid hostname, using default: zarchblack"
        CONFIG[hostname]="zarchblack"
    fi
    show_success "Hostname: ${CONFIG[hostname]}"
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 6. GRAPHICS DRIVER
# ────────────────────────────────────────────────────────────────────────────────

select_graphics_driver() {
    show_header
    show_submenu_header "🎮 Graphics Driver"
    echo ""

    local is_vm="no"
    if systemd-detect-virt -q 2>/dev/null; then
        is_vm="yes"
        gum style --foreground 82 --margin "0 2" "🔍 Virtual Machine detected."
        echo ""
    fi

    show_info "Select the graphics driver for your system"
    echo ""

    local drivers=()
    [[ "$is_vm" == "yes" ]] && drivers+=("vm                   │ Virtual Machine")
    drivers+=(
        "intel                │ Intel Graphics"
        "amd                  │ AMD Graphics"
        "nvidia-turing        │ NVIDIA Turing+ (RTX 20/30/40, GTX 1650+)"
        "nvidia-legacy        │ NVIDIA Legacy (GTX 900/1000 series)"
        "intel-amd            │ Intel + AMD (Hybrid)"
        "intel-nvidia-turing  │ Intel + NVIDIA Turing+ (Optimus)"
        "intel-nvidia-legacy  │ Intel + NVIDIA Legacy (Optimus)"
        "amd-nvidia-turing    │ AMD + NVIDIA Turing+ (Hybrid)"
        "amd-nvidia-legacy    │ AMD + NVIDIA Legacy (Hybrid)"
    )
    [[ "$is_vm" != "yes" ]] && drivers+=("vm                   │ Virtual Machine")

    local driver_selection=""
    driver_selection=$(printf '%s\n' "${drivers[@]}" | gum choose --height 12 \
        --header "Graphics driver:") || true
    if [[ -n "$driver_selection" ]]; then
        CONFIG[gfx_driver]=$(echo "$driver_selection" | awk '{print $1}')
        show_success "Graphics driver: ${CONFIG[gfx_driver]}"
    fi
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 7. AUTHENTICATION
# ────────────────────────────────────────────────────────────────────────────────

configure_authentication() {
    show_header
    show_submenu_header "👤 User Account Setup"
    echo ""
    show_info "Create your user account"
    echo ""

    local username=""
    username=$(gum input --placeholder "username" --width 40 \
        --header "Username (lowercase):") || true
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ || ${#username} -gt 32 || -z "$username" ]]; then
        show_warning "Invalid username. Using 'user'"
        username="user"
    fi
    CONFIG[username]="$username"
    show_success "Username: ${CONFIG[username]}"

    echo ""
    local user_pass1="" user_pass2=""
    user_pass1=$(gum input --password --placeholder "Password for $username" --width 50) || true
    user_pass2=$(gum input --password --placeholder "Confirm password" --width 50) || true
    if [[ "$user_pass1" == "$user_pass2" && ${#user_pass1} -ge 1 ]]; then
        CONFIG[user_password]="$user_pass1"
        show_success "User password set"
    else
        show_error "Passwords don't match. Please reconfigure."
        sleep 1; configure_authentication; return
    fi

    echo ""
    show_submenu_header "🔐 Root Password"
    echo ""
    if confirm_action "Use same password for root?"; then
        CONFIG[root_password]="${CONFIG[user_password]}"
        show_success "Root password set (same as user)"
    else
        local root_pass1="" root_pass2=""
        root_pass1=$(gum input --password --placeholder "Root password" --width 50) || true
        root_pass2=$(gum input --password --placeholder "Confirm root password" --width 50) || true
        if [[ "$root_pass1" == "$root_pass2" && -n "$root_pass1" ]]; then
            CONFIG[root_password]="$root_pass1"
            show_success "Root password set"
        else
            show_warning "Passwords don't match. Using user password for root."
            CONFIG[root_password]="${CONFIG[user_password]}"
        fi
    fi
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 8. PARALLEL DOWNLOADS
# ────────────────────────────────────────────────────────────────────────────────

configure_parallel_downloads() {
    show_header
    show_submenu_header "⚡ Parallel Downloads"
    echo ""
    show_info "Set number of parallel package downloads"
    echo ""
    local options=(
        "3      │ Conservative (slow connections)"
        "5      │ Default (recommended)"
        "10     │ Fast (good connections)"
        "15     │ Maximum (excellent connections)"
    )
    local selection=""
    selection=$(printf '%s\n' "${options[@]}" | gum choose --height 6 \
        --header "Parallel downloads:") || true
    [[ -n "$selection" ]] && CONFIG[parallel_downloads]=$(echo "$selection" | awk '{print $1}')
    show_success "Parallel downloads: ${CONFIG[parallel_downloads]}"
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 9. AUR HELPER
# ────────────────────────────────────────────────────────────────────────────────

select_aur_helper() {
    show_header
    show_submenu_header "📦 AUR Helper"
    echo ""
    show_info "Select the AUR helper to install"
    echo ""
    local helpers=(
        "paru   │ Rust-based, feature-rich (Recommended)"
        "yay    │ Go-based, popular choice"
    )
    local selection=""
    selection=$(printf '%s\n' "${helpers[@]}" | gum choose --height 4 \
        --header "AUR Helper:") || true
    [[ -n "$selection" ]] && CONFIG[aur_helper]=$(echo "$selection" | awk '{print $1}')
    show_success "AUR helper: ${CONFIG[aur_helper]}"
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# 10. ADDITIONAL KERNEL
# ────────────────────────────────────────────────────────────────────────────────

select_extra_kernel() {
    show_header
    show_submenu_header "🐧 Additional Kernel"
    echo ""
    gum style --foreground 220 --bold --border normal --border-foreground 220 \
        --align left --margin "0 2" --padding "0 1" \
        "These kernels install ALONGSIDE the default linux kernel."
    echo ""

    local options=(
        "None"
        "linux-cachyos   │ CachyOS optimized kernel  (Chaotic-AUR)"
        "linux-lts       │ Long Term Support kernel   (official repos)"
        "linux-zen       │ Zen kernel — desktop optimized"
    )

    local selections=""
    selections=$(printf '%s\n' "${options[@]}" | gum choose --no-limit \
        --header "Additional kernels (Space to toggle, Enter to confirm):") || true

    CONFIG[extra_kernel]=""
    if [[ -z "$selections" ]] || echo "$selections" | grep -q "^None$"; then
        show_success "No additional kernel selected"
        sleep 0.5; return
    fi

    while IFS= read -r line; do
        case "$line" in
            "linux-cachyos"*) CONFIG[extra_kernel]+="linux-cachyos linux-cachyos-headers " ;;
            "linux-lts"*)     CONFIG[extra_kernel]+="linux-lts linux-lts-headers " ;;
            "linux-zen"*)     CONFIG[extra_kernel]+="linux-zen linux-zen-headers " ;;
        esac
    done <<< "$selections"

    CONFIG[extra_kernel]="${CONFIG[extra_kernel]% }"
    show_success "Extra kernels: ${CONFIG[extra_kernel]}"
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# PACMAN HELPERS
# ────────────────────────────────────────────────────────────────────────────────

apply_parallel_downloads() {
    local conf="$1"
    local count="${CONFIG[parallel_downloads]}"
    if grep -q '^#*ParallelDownloads' "$conf"; then
        sed -i "s/^#*ParallelDownloads.*/ParallelDownloads = $count/" "$conf"
    else
        sed -i '/^\[options\]/a ParallelDownloads = '"$count" "$conf"
    fi
}

configure_pacman_options() {
    local conf="$1"
    local simple_opts=(Color ILoveCandy VerbosePkgLists DisableDownloadTimeout)
    for opt in "${simple_opts[@]}"; do
        if grep -q "^#\s*${opt}" "$conf"; then
            sed -i "s/^#\s*${opt}.*/${opt}/" "$conf"
        elif ! grep -q "^${opt}" "$conf"; then
            sed -i '/^\[options\]/a '"${opt}" "$conf"
        fi
    done
}

# ────────────────────────────────────────────────────────────────────────────────
# MAIN MENU
# ────────────────────────────────────────────────────────────────────────────────

show_main_menu() {
    while true; do
        show_header

        local boot_mode="BIOS"
        [[ "${CONFIG[uefi]}" == "yes" ]] && boot_mode="UEFI"

        gum style --foreground 245 --margin "0 2" "Boot Mode: $boot_mode"
        echo ""

        local disk_info="${CONFIG[disk]:-Not configured}"
        if [[ -n "${CONFIG[disk]}" ]]; then
            disk_info+=" (${CONFIG[filesystem]}"
            [[ "${CONFIG[encrypt]}" == "yes" ]] && disk_info+=", encrypted"
            disk_info+=")"
        fi

        local kernel_label="None"
        [[ "${CONFIG[extra_kernel]}" == *"linux-cachyos"* ]] && kernel_label="CachyOS"
        [[ "${CONFIG[extra_kernel]}" == *"linux-lts"* ]]     && kernel_label="LTS"
        [[ "${CONFIG[extra_kernel]}" == *"linux-zen"* ]]     && kernel_label="Zen"

        local menu_items=(
            ""
            "1.  Locales               │ ${CONFIG[locale]} / ${CONFIG[keyboard]}"
            "2.  Timezone              │ ${CONFIG[timezone]}"
            "3.  Disk Configuration    │ $disk_info"
            "4.  Swap                  │ ${CONFIG[swap]}"
            "5.  Hostname              │ ${CONFIG[hostname]}"
            "6.  Graphics Driver       │ ${CONFIG[gfx_driver]}"
            "7.  Authentication        │ ${CONFIG[username]:-Not configured}"
            "8.  Parallel Downloads    │ ${CONFIG[parallel_downloads]}"
            "9.  AUR Helper            │ ${CONFIG[aur_helper]}"
            "10. Additional Kernel     │ $kernel_label"
            "──────────────────────────────────────────────"
            "11. Start Installation"
            "0.  Exit"
        )

        local selection=""
        selection=$(printf '%s\n' "${menu_items[@]}" | gum choose --height 20 \
            --header $'Configure your ZarchBlack installation:\n') || true

        case "$selection" in
            "1."*)  select_locales ;;
            "2."*)  select_timezone ;;
            "3."*)  select_partitioning_mode ;;
            "4."*)  configure_swap ;;
            "5."*)  configure_hostname ;;
            "6."*)  select_graphics_driver ;;
            "7."*)  configure_authentication ;;
            "8."*)  configure_parallel_downloads ;;
            "9."*)  select_aur_helper ;;
            "10."*) select_extra_kernel ;;
            "11."*)
                if validate_config; then
                    show_summary
                    if confirm_action "Start installation? THIS WILL ERASE ${CONFIG[disk]}"; then
                        perform_installation
                        break
                    fi
                fi
                ;;
            "0."*)
                if confirm_action "Exit installer?"; then
                    echo "Installation cancelled."
                    exit 0
                fi
                ;;
        esac
    done
}

# ────────────────────────────────────────────────────────────────────────────────
# VALIDATION & SUMMARY
# ────────────────────────────────────────────────────────────────────────────────

validate_config() {
    local errors=()
    [[ -z "${CONFIG[disk]}" ]]          && errors+=("Disk not configured")
    [[ -z "${CONFIG[username]}" ]]      && errors+=("User account not configured")
    [[ -z "${CONFIG[user_password]}" ]] && errors+=("User password not set")
    [[ -z "${CONFIG[root_password]}" ]] && errors+=("Root password not set")
    if [[ ${#errors[@]} -gt 0 ]]; then
        show_header
        gum style --foreground 196 --bold --margin "1 2" "❌ Configuration Incomplete"
        echo ""
        for error in "${errors[@]}"; do show_error "$error"; done
        echo ""
        gum input --placeholder "Press Enter to continue..."
        return 1
    fi
    return 0
}

show_summary() {
    show_header
    show_submenu_header "📋 Installation Summary"
    echo ""

    local encrypt_status="No"
    [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" == "yes" ]] && \
        encrypt_status="Yes (LUKS2, root + boot)"
    [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" != "yes" ]] && \
        encrypt_status="Yes (LUKS2, root only)"

    local boot_mode="BIOS/Legacy"
    [[ "${CONFIG[uefi]}" == "yes" ]] && boot_mode="UEFI"

    gum style --border rounded --border-foreground 141 --padding "1 2" --margin "0 2" \
        "Locale:        ${CONFIG[locale]}" \
        "Keyboard:      ${CONFIG[keyboard]}" \
        "Timezone:      ${CONFIG[timezone]}" \
        "Hostname:      ${CONFIG[hostname]}" \
        "" \
        "Username:      ${CONFIG[username]}" \
        "" \
        "Target Disk:   ${CONFIG[disk]}" \
        "Filesystem:    ${CONFIG[filesystem]}" \
        "Encryption:    $encrypt_status" \
        "Swap:          ${CONFIG[swap]}" \
        "" \
        "AUR Helper:    ${CONFIG[aur_helper]}" \
        "Graphics:      ${CONFIG[gfx_driver]}" \
        "Boot Mode:     $boot_mode" \
        "Downloads:     ${CONFIG[parallel_downloads]} parallel"

    echo ""
    gum style --foreground 196 --bold --margin "0 2" \
        "⚠️  ALL DATA ON ${CONFIG[disk]} WILL BE PERMANENTLY ERASED!"
    echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# INSTALLATION
# ────────────────────────────────────────────────────────────────────────────────

perform_installation() {
    show_header
    gum style --foreground 141 --bold --margin "1 2" "🚀 Starting ZarchBlack Installation..."
    echo ""

    run_step "Partitioning disk..."      partition_disk
    [[ "${CONFIG[encrypt]}" == "yes" ]] && run_step "Setting up encryption..." setup_encryption
    run_step "Formatting partitions..."  format_partitions
    run_step "Mounting filesystems..."   mount_filesystems

    show_info "Installing base system (this may take a while)..."
    install_base_system
    show_success "Base system installed"

    show_info "Adding ZarchBlack and Chaotic-AUR repositories..."
    add_repos
    show_success "Repositories configured"

    if [[ -n "${CONFIG[extra_kernel]}" ]]; then
        show_info "Installing additional kernels: ${CONFIG[extra_kernel]}..."
        # shellcheck disable=SC2086
        arch-chroot "$MOUNTPOINT" pacman -S --needed --noconfirm ${CONFIG[extra_kernel]} \
            || show_warning "Some extra kernel packages failed — continuing"
        arch-chroot "$MOUNTPOINT" grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
        show_success "Additional kernels installed"
    fi

    run_step "Configuring system..."            configure_system
    run_step "Installing GRUB bootloader..."    install_bootloader
    run_step "Configuring Btrfs snapshots..."   setup_snapper
    run_step "Creating user account..."         create_user
    run_step "Installing graphics drivers..."   install_graphics
    run_step "Configuring swap..."              setup_swap_system

    show_info "Preparing ZarchBlack KDE desktop..."
    prepare_desktop_installer
    show_success "KDE installer ready"

    echo ""
    gum style --foreground 82 --bold --border double --border-foreground 82 \
        --align center --width 62 --margin "1 2" --padding "1 2" \
        "🎉 Base Installation Complete! 🎉" \
        "" \
        "The system will now chroot into your new installation" \
        "to run the ZarchBlack KDE Plasma setup script."

    echo ""
    gum input --placeholder "Press Enter to continue to KDE installation..."
    run_desktop_installer

    show_header
    gum style --foreground 82 --bold --border double --border-foreground 82 \
        --align center --width 60 --margin "1 2" --padding "1 2" \
        "⚡ ZarchBlack Installation Complete! ⚡" \
        "" \
        "Freedom • Power • Simplicity" \
        "" \
        "Remove the installation media and reboot:" \
        "  sudo reboot"
    echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# DISK OPERATIONS
# ────────────────────────────────────────────────────────────────────────────────

partition_disk() {
    [[ "${CONFIG[partition_mode]}" == "manual" ]] && return 0
    local disk="${CONFIG[disk]}"
    [[ -n "$disk" ]] || { echo "ERROR: CONFIG[disk] is empty"; exit 1; }

    wipefs -af "$disk" 2>/dev/null || true
    sgdisk -Z "$disk" &>/dev/null || true

    if [[ "${CONFIG[uefi]}" == "yes" ]]; then
        parted -s "$disk" mklabel gpt
        parted -s "$disk" mkpart ESP fat32 1MiB 2049MiB
        parted -s "$disk" set 1 esp on
        parted -s "$disk" mkpart primary 2049MiB 100%
    else
        parted -s "$disk" mklabel msdos
        parted -s "$disk" mkpart primary ext4 1MiB 2049MiB
        parted -s "$disk" set 1 boot on
        parted -s "$disk" mkpart primary 2049MiB 100%
    fi

    partprobe "$disk" || true
    udevadm settle
    sleep 1

    if [[ "$disk" == *"nvme"* || "$disk" == *"mmcblk"* ]]; then
        CONFIG[boot_part]="${disk}p1"
        CONFIG[root_part]="${disk}p2"
    else
        CONFIG[boot_part]="${disk}1"
        CONFIG[root_part]="${disk}2"
    fi
}

setup_encryption() {
    [[ "${CONFIG[encrypt]}" == "yes" ]] || return 0
    [[ -n "${CONFIG[encrypt_password]}" ]] || { echo "ERROR: Encryption password empty"; exit 1; }
    echo -n "${CONFIG[encrypt_password]}" | cryptsetup luksFormat --type luks2 "${CONFIG[root_part]}" -
    echo -n "${CONFIG[encrypt_password]}" | cryptsetup open "${CONFIG[root_part]}" cryptroot -
    CONFIG[root_device]="/dev/mapper/cryptroot"
}

format_partitions() {
    local root_device="${CONFIG[root_part]}"
    [[ "${CONFIG[encrypt]}" == "yes" ]] && root_device="${CONFIG[root_device]}"

    if [[ -n "${CONFIG[boot_part]}" && "${CONFIG[reuse_efi]}" != "yes" ]]; then
        [[ "${CONFIG[uefi]}" == "yes" ]] && mkfs.fat -F32 "${CONFIG[boot_part]}" || \
            mkfs.ext4 -F "${CONFIG[boot_part]}"
    fi

    case "${CONFIG[filesystem]}" in
        btrfs) mkfs.btrfs -f "$root_device" ;;
        ext4)  mkfs.ext4 -F "$root_device" ;;
        xfs)   mkfs.xfs -f "$root_device" ;;
    esac
}

mount_filesystems() {
    local root_device="${CONFIG[root_part]}"
    [[ "${CONFIG[encrypt]}" == "yes" ]] && root_device="${CONFIG[root_device]}"

    if [[ "${CONFIG[filesystem]}" == "btrfs" ]]; then
        mount "$root_device" "$MOUNTPOINT"
        btrfs subvolume create "$MOUNTPOINT/@"
        btrfs subvolume create "$MOUNTPOINT/@home"
        btrfs subvolume create "$MOUNTPOINT/@var"
        btrfs subvolume create "$MOUNTPOINT/@tmp"
        umount "$MOUNTPOINT"
        mount -o noatime,compress=zstd,subvol=@ "$root_device" "$MOUNTPOINT"
        mkdir -p "$MOUNTPOINT"/{home,var,tmp,boot}
        mount -o noatime,compress=zstd,subvol=@home "$root_device" "$MOUNTPOINT/home"
        mount -o noatime,compress=zstd,subvol=@var  "$root_device" "$MOUNTPOINT/var"
        mount -o noatime,compress=zstd,subvol=@tmp  "$root_device" "$MOUNTPOINT/tmp"
    else
        mount "$root_device" "$MOUNTPOINT"
        mkdir -p "$MOUNTPOINT/boot"
    fi

    if [[ "${CONFIG[uefi]}" == "yes" ]]; then
        mkdir -p "$MOUNTPOINT/boot/efi"
        mount "${CONFIG[boot_part]}" "$MOUNTPOINT/boot/efi"
    elif [[ -n "${CONFIG[boot_part]}" ]]; then
        mount "${CONFIG[boot_part]}" "$MOUNTPOINT/boot"
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# SYSTEM INSTALLATION
# ────────────────────────────────────────────────────────────────────────────────

import_chaotic_key() {
    local keyid="3056513887B78AEB"
    local keyservers=("keyserver.ubuntu.com" "keys.openpgp.org" "pgp.mit.edu")
    for ks in "${keyservers[@]}"; do
        pacman-key --recv-key "$keyid" --keyserver "$ks" 2>/dev/null && \
            { pacman-key --lsign-key "$keyid" || true; return 0; }
        show_warning "Keyserver $ks failed, trying next..."
    done
    pacman-key --lsign-key "$keyid" || true
}

add_temp_repo() {
    sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' /etc/pacman.conf

    # ZarchBlack local repo
    if ! grep -q "\[zarchblack-local\]" /etc/pacman.conf; then
        cat >> /etc/pacman.conf << 'EOF'

[zarchblack-local]
SigLevel = Optional TrustAll
Server = https://github.com/ZarchBlack/zarchblack-packages/releases/download/repo
EOF
    fi

    # CachyOS repositories
    if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
        pacman-key --recv-key F3B607488DB35A47 --keyserver keyserver.ubuntu.com 2>/dev/null || \
        pacman-key --recv-key F3B607488DB35A47 --keyserver keys.openpgp.org 2>/dev/null || true
        pacman-key --lsign-key F3B607488DB35A47 || true
        pacman -U --noconfirm \
            'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' || true
        pacman -U --noconfirm \
            'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-18-1-any.pkg.tar.zst' || true
        pacman -U --noconfirm \
            'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-18-1-any.pkg.tar.zst' || true
        cat >> /etc/pacman.conf << 'EOF'

[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
    fi

    # Chaotic-AUR
    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        import_chaotic_key
        pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
        pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true
        echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf
    fi

    apply_parallel_downloads /etc/pacman.conf
    configure_pacman_options /etc/pacman.conf
    pacman -Sy
}

install_base_system() {
    add_temp_repo

    local critical="base base-devel linux linux-headers linux-firmware"
    # Microcode auto-detect
    grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null && critical+=" intel-ucode"
    grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null && critical+=" amd-ucode"

    critical+=" grub efibootmgr os-prober update-grub"
    critical+=" btrfs-progs dosfstools e2fsprogs xfsprogs gptfdisk"
    critical+=" sudo nano vim git wget curl"
    critical+=" networkmanager iw iwd ppp lftp avahi samba netctl dhcpcd openssh"
    critical+=" openvpn dnsmasq dhclient nss-mdns net-tools reflector wireguard-tools"
    critical+=" bluez bluez-libs bluez-utils bluez-tools bluez-hid2hci"
    critical+=" pipewire wireplumber pipewire-jack pipewire-support lib32-pipewire-jack"
    critical+=" alsa-utils alsa-plugins alsa-firmware pavucontrol-qt libdvdcss"
    critical+=" gstreamer gst-libav gst-plugins-bad gst-plugins-base gst-plugins-ugly"
    critical+=" gst-plugins-good gst-plugin-pipewire"
    critical+=" cups hplip print-manager"
    critical+=" xorg-server xorg-xinit xorg-xwayland libinput xf86-input-libinput"
    critical+=" mkinitcpio"

    # shellcheck disable=SC2086
    pacstrap -K "$MOUNTPOINT" $critical

    local optional="orca iio-sensor-proxy fwupd sof-firmware"
    # shellcheck disable=SC2086
    pacstrap -K "$MOUNTPOINT" $optional 2>/dev/null || \
        show_warning "Some optional packages failed — continuing"

    if [[ "${CONFIG[filesystem]}" == "btrfs" ]]; then
        pacstrap -K "$MOUNTPOINT" snapper grub-btrfs inotify-tools 2>/dev/null || \
            show_warning "Some Btrfs snapshot packages failed — continuing"
    fi

    genfstab -U "$MOUNTPOINT" >> "$MOUNTPOINT/etc/fstab"
}

add_repos() {
    sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' "$MOUNTPOINT/etc/pacman.conf"

    # ZarchBlack local repo
    if ! grep -q "\[zarchblack-local\]" "$MOUNTPOINT/etc/pacman.conf"; then
        cat >> "$MOUNTPOINT/etc/pacman.conf" << 'EOF'

[zarchblack-local]
SigLevel = Optional TrustAll
Server = https://github.com/ZarchBlack/zarchblack-packages/releases/download/repo
EOF
    fi

    # CachyOS repositories
    if ! grep -q "\[cachyos\]" "$MOUNTPOINT/etc/pacman.conf"; then
        local cachyos_keyid="F3B607488DB35A47"
        for ks in keyserver.ubuntu.com keys.openpgp.org pgp.mit.edu; do
            arch-chroot "$MOUNTPOINT" pacman-key --recv-key "$cachyos_keyid" \
                --keyserver "$ks" 2>/dev/null && break
        done
        arch-chroot "$MOUNTPOINT" pacman-key --lsign-key "$cachyos_keyid" || true
        arch-chroot "$MOUNTPOINT" pacman -U --noconfirm \
            'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' || true
        arch-chroot "$MOUNTPOINT" pacman -U --noconfirm \
            'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-18-1-any.pkg.tar.zst' || true
        arch-chroot "$MOUNTPOINT" pacman -U --noconfirm \
            'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-18-1-any.pkg.tar.zst' || true
        cat >> "$MOUNTPOINT/etc/pacman.conf" << 'EOF'

[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
    fi

    # Chaotic-AUR
    if ! grep -q "\[chaotic-aur\]" "$MOUNTPOINT/etc/pacman.conf"; then
        local keyid="3056513887B78AEB"
        for ks in keyserver.ubuntu.com keys.openpgp.org pgp.mit.edu; do
            arch-chroot "$MOUNTPOINT" pacman-key --recv-key "$keyid" \
                --keyserver "$ks" 2>/dev/null && break
        done
        arch-chroot "$MOUNTPOINT" pacman-key --lsign-key "$keyid" || true
        arch-chroot "$MOUNTPOINT" pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' || true
        arch-chroot "$MOUNTPOINT" pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true
        echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' \
            >> "$MOUNTPOINT/etc/pacman.conf"
    fi

    apply_parallel_downloads "$MOUNTPOINT/etc/pacman.conf"
    configure_pacman_options "$MOUNTPOINT/etc/pacman.conf"
    arch-chroot "$MOUNTPOINT" pacman -Sy
}

configure_system() {
    arch-chroot "$MOUNTPOINT" ln -sf "/usr/share/zoneinfo/${CONFIG[timezone]}" /etc/localtime
    arch-chroot "$MOUNTPOINT" hwclock --systohc

    echo "${CONFIG[locale]} UTF-8" >> "$MOUNTPOINT/etc/locale.gen"
    echo "en_US.UTF-8 UTF-8"       >> "$MOUNTPOINT/etc/locale.gen"
    arch-chroot "$MOUNTPOINT" locale-gen
    echo "LANG=${CONFIG[locale]}" > "$MOUNTPOINT/etc/locale.conf"
    echo "KEYMAP=${CONFIG[keyboard]}" > "$MOUNTPOINT/etc/vconsole.conf"

    mkdir -p "$MOUNTPOINT/etc/X11/xorg.conf.d"
    cat > "$MOUNTPOINT/etc/X11/xorg.conf.d/00-keyboard.conf" << EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "${CONFIG[keyboard]}"
EndSection
EOF

    echo "${CONFIG[hostname]}" > "$MOUNTPOINT/etc/hostname"
    cat > "$MOUNTPOINT/etc/hosts" << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${CONFIG[hostname]}.localdomain ${CONFIG[hostname]}
EOF

    arch-chroot "$MOUNTPOINT" systemctl enable NetworkManager
    mkdir -p "$MOUNTPOINT/etc/NetworkManager/conf.d"
    cat > "$MOUNTPOINT/etc/NetworkManager/conf.d/wifi-backend.conf" << EOF
[device]
wifi.backend=wpa_supplicant
EOF

    if [[ "${CONFIG[encrypt]}" == "yes" ]]; then
        sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' \
            "$MOUNTPOINT/etc/mkinitcpio.conf"
        arch-chroot "$MOUNTPOINT" mkinitcpio -P
    fi
}

install_bootloader() {
    if [[ "${CONFIG[uefi]}" == "yes" ]]; then
        mkdir -p "$MOUNTPOINT/boot/efi"
        mountpoint -q "$MOUNTPOINT/boot/efi" || mount "${CONFIG[boot_part]}" "$MOUNTPOINT/boot/efi"
        arch-chroot "$MOUNTPOINT" grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=ZarchBlack \
            --recheck
    else
        arch-chroot "$MOUNTPOINT" grub-install --target=i386-pc "${CONFIG[disk]}"
    fi

    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 nvme_load=yes"/' \
        "$MOUNTPOINT/etc/default/grub"
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="ZarchBlack"/' "$MOUNTPOINT/etc/default/grub"
    sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$MOUNTPOINT/etc/default/grub"

    if [[ "${CONFIG[encrypt]}" == "yes" ]]; then
        local uuid=""
        uuid=$(blkid -s UUID -o value "${CONFIG[root_part]}")
        sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"rd.luks.name=${uuid}=cryptroot root=/dev/mapper/cryptroot\"|" \
            "$MOUNTPOINT/etc/default/grub"
    fi

    arch-chroot "$MOUNTPOINT" grub-mkconfig -o /boot/grub/grub.cfg
}

setup_snapper() {
    [[ "${CONFIG[filesystem]}" != "btrfs" ]] && return 0
    mkdir -p "$MOUNTPOINT/etc/snapper/configs"
    cat > "$MOUNTPOINT/etc/snapper/configs/root" << 'SNAPCFG'
SUBVOLUME="/"
FSTYPE="btrfs"
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
NUMBER_CLEANUP="yes"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
SNAPCFG

    btrfs subvolume create "$MOUNTPOINT/.snapshots" 2>/dev/null || true
    chmod 750 "$MOUNTPOINT/.snapshots"
    show_success "Snapper configured"
}

create_user() {
    echo "root:${CONFIG[root_password]}" | arch-chroot "$MOUNTPOINT" chpasswd

    local groups="sys network power cups realtime rfkill lp users video storage kvm audio wheel adm"
    for grp in $groups; do
        arch-chroot "$MOUNTPOINT" groupadd -f "$grp" 2>/dev/null || true
    done

    arch-chroot "$MOUNTPOINT" useradd -m \
        -G sys,network,power,cups,realtime,rfkill,lp,users,video,storage,kvm,audio,wheel,adm \
        -s /bin/bash "${CONFIG[username]}"
    echo "${CONFIG[username]}:${CONFIG[user_password]}" | arch-chroot "$MOUNTPOINT" chpasswd
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "$MOUNTPOINT/etc/sudoers"
}

install_graphics() {
    local packages=""
    local needs_nvidia_config="no"
    local base_drivers="mesa mesa-utils lib32-mesa xf86-video-fbdev"

    case "${CONFIG[gfx_driver]}" in
        "intel")               packages="xf86-video-intel vulkan-intel $base_drivers" ;;
        "amd")                 packages="xf86-video-amdgpu vulkan-radeon $base_drivers" ;;
        "nvidia-turing")
            packages="nvidia-open-dkms nvidia-utils nvidia-settings libvdpau opencl-nvidia lib32-nvidia-utils $base_drivers"
            needs_nvidia_config="yes" ;;
        "nvidia-legacy")
            packages="nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils $base_drivers"
            needs_nvidia_config="yes" ;;
        "intel-amd")           packages="xf86-video-intel vulkan-intel xf86-video-amdgpu vulkan-radeon $base_drivers" ;;
        "intel-nvidia-turing")
            packages="xf86-video-intel vulkan-intel nvidia-open-dkms nvidia-utils lib32-nvidia-utils $base_drivers"
            needs_nvidia_config="yes" ;;
        "amd-nvidia-turing")
            packages="xf86-video-amdgpu vulkan-radeon nvidia-open-dkms nvidia-utils lib32-nvidia-utils $base_drivers"
            needs_nvidia_config="yes" ;;
        "vm")
            packages="$base_drivers xorg-server xorg-xinit"
            local vm_type
            vm_type=$(systemd-detect-virt 2>/dev/null || echo "unknown")
            case "$vm_type" in
                "qemu"|"kvm") packages+=" spice-vdagent qemu-guest-agent" ;;
                "vmware")     packages+=" open-vm-tools" ;;
                "oracle")     packages+=" virtualbox-guest-utils" ;;
                *)            packages+=" spice-vdagent qemu-guest-agent open-vm-tools" ;;
            esac ;;
    esac

    if [[ -n "$packages" ]]; then
        # shellcheck disable=SC2086
        arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed $packages \
            || show_warning "Some graphics packages failed — system may still work"
    fi

    if [[ "$needs_nvidia_config" == "yes" ]]; then
        sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' \
            "$MOUNTPOINT/etc/mkinitcpio.conf"
        arch-chroot "$MOUNTPOINT" mkinitcpio -P
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1"/' \
            "$MOUNTPOINT/etc/default/grub"
        arch-chroot "$MOUNTPOINT" grub-mkconfig -o /boot/grub/grub.cfg
    fi
}

setup_swap_system() {
    case "${CONFIG[swap]}" in
        "zram")
            arch-chroot "$MOUNTPOINT" pacman -S --noconfirm zram-generator
            cat > "$MOUNTPOINT/etc/systemd/zram-generator.conf" << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = ${CONFIG[swap_algo]}
EOF
            ;;
        "file")
            arch-chroot "$MOUNTPOINT" fallocate -l 4G /swapfile
            arch-chroot "$MOUNTPOINT" chmod 600 /swapfile
            arch-chroot "$MOUNTPOINT" mkswap /swapfile
            echo "/swapfile none swap defaults 0 0" >> "$MOUNTPOINT/etc/fstab"
            ;;
    esac
}

# ────────────────────────────────────────────────────────────────────────────────
# DESKTOP INSTALLER
# ────────────────────────────────────────────────────────────────────────────────

prepare_desktop_installer() {
    local user="${CONFIG[username]}"
    local user_home="$MOUNTPOINT/home/${user}"

    if [[ -f "/root/zarch-kde.sh" ]]; then
        cp /root/zarch-kde.sh "${user_home}/zarch-kde.sh"
    else
        curl -fsSL "$ZARCH_KDE_URL" -o "${user_home}/zarch-kde.sh" || {
            cat > "${user_home}/zarch-kde.sh" << 'KDESCRIPT'
#!/bin/bash
echo "ZarchBlack KDE installer placeholder"
echo "Please download from: https://github.com/ZarchBlack/zarchblack"
KDESCRIPT
        }
    fi
    chmod +x "${user_home}/zarch-kde.sh"
    arch-chroot "$MOUNTPOINT" chown "${user}:${user}" "/home/${user}/zarch-kde.sh"
}

run_desktop_installer() {
    local user="${CONFIG[username]}"
    local user_home="/home/${user}"

    show_header
    gum style --foreground 141 --bold --margin "1 2" \
        "⚡ Running ZarchBlack KDE Plasma Setup (as ${user})..."
    echo ""

    [[ ! -f "${MOUNTPOINT}${user_home}/zarch-kde.sh" ]] && {
        show_error "KDE script not found"
        return 1
    }

    arch-chroot "$MOUNTPOINT" chown -R "${user}:${user}" "${user_home}"
    echo "${user} ALL=(ALL:ALL) NOPASSWD: ALL" > "$MOUNTPOINT/etc/sudoers.d/99-zarch-installer"
    chmod 0440 "$MOUNTPOINT/etc/sudoers.d/99-zarch-installer"

    arch-chroot "$MOUNTPOINT" su -l "$user" -c "bash '${user_home}/zarch-kde.sh' '${CONFIG[aur_helper]}' '${CONFIG[filesystem]}'"

    rm -f "$MOUNTPOINT/etc/sudoers.d/99-zarch-installer"
}

# ────────────────────────────────────────────────────────────────────────────────
# MAIN ENTRY POINT
# ────────────────────────────────────────────────────────────────────────────────

main() {
    check_root
    check_uefi
    if ! command -v gum &>/dev/null; then
        check_internet
        ensure_dependencies
    fi
    show_main_menu
}

main "$@"
