# ⚡ ZarchBlack Installer

> **Freedom • Power • Simplicity** — Arch Linux, Done Right.

A beautiful, streamlined Arch Linux installer that sets up a full
**ZarchBlack KDE Plasma** desktop environment in one command.

---

## 🚀 Quick Install

Boot from any **Arch Linux live ISO**, connect to the internet, then run:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/ZarchBlack/zarchblack/main/install.sh)
```

---

## ✨ What Gets Installed

| Component | Details |
|---|---|
| **Desktop** | KDE Plasma 6 (Wayland) |
| **Display Manager** | SDDM with ZeroDark theme |
| **Boot Splash** | Plymouth ZarchBlack theme |
| **Browser** | Thorium Browser + Brave |
| **Package Manager** | zPackageManager + paru/yay |
| **Security** | ZarchGuard + zarch-hacking tools |
| **Filesystem** | btrfs (with Snapper snapshots) or ext4/xfs |
| **Swap** | ZRAM (compressed, fast) |
| **Audio** | PipeWire + WirePlumber |
| **Bootloader** | GRUB (UEFI + BIOS) |

---

## 🗂️ Script Structure

```
install.sh        ← Entry point (run this)
zarch-install.sh  ← Main installer (disk, users, base system)
zarch-kde.sh      ← KDE Plasma + ZarchBlack desktop setup
```

---

## 📋 Requirements

- Arch Linux live ISO (any recent version)
- Internet connection
- 20 GB+ disk space
- 4 GB+ RAM recommended

---

## 📥 Download ZarchBlack ISO

| | |
|---|---|
| **Latest Release** | [Hugging Face →](https://huggingface.co/datasets/zarchblack/zarchblack-releases) |
| **Version** | 2026.05.30 |
| **Architecture** | x86_64 |

---

## 📜 License

GPL-3.0 — See [LICENSE](LICENSE)
