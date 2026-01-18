#!/usr/bin/env bash
# R86S Router Installation Script
set -e

# Configuration
REPO_URL="https://github.com/peta3000/nixos-infra.git"
REPO_BRANCH="restructure"  # Default to restructure branch
TARGET_HOST="gw-r86s-router"

# Disk IDs for R86S (update these)
NVME_DISK="nvme-WD_Red_SN700_250GB_230506800251"
EMMC_DISK="mmc-SCA128_0x06b27b7d"

# Parse arguments
DISK_TARGET="nvme"  # Default to nvme for testing
HOSTNAME="$TARGET_HOST"

while [[ $# -gt 0 ]]; do
  case $1 in
    --disk) DISK_TARGET="$2"; shift 2 ;;
    --hostname) HOSTNAME="$2"; shift 2 ;;
    --repo) REPO_URL="$2"; shift 2 ;;
    --branch) REPO_BRANCH="$2"; shift 2 ;;
    --help) 
      echo "Usage: $0 [--disk nvme|emmc] [--hostname name] [--repo url] [--branch branch]"
      echo "  --disk: Target disk (nvme for testing, emmc for production)"
      echo "  --hostname: System hostname (default: gw-r86s-router)"
      echo "  --repo: Git repository URL"
      echo "  --branch: Git branch to use (default: restructure)"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Select disk and disko config
case $DISK_TARGET in
  nvme)
    DISK_ID="$NVME_DISK"
    DISKO_CONFIG="r86s-nvme.nix"
    echo "Installing to NVMe SSD (testing)"
    ;;
  emmc)
    DISK_ID="$EMMC_DISK"
    DISKO_CONFIG="r86s-emmc.nix"
    echo "Installing to eMMC (production)"
    ;;
  *)
    echo "Error: --disk must be 'nvme' or 'emmc'"
    exit 1
    ;;
esac

echo "=== R86S Router Installation ==="
echo "Target: $HOSTNAME"
echo "Repository: $REPO_URL (branch: $REPO_BRANCH)"
echo "Disk: /dev/disk/by-id/$DISK_ID"
echo "Config: $DISKO_CONFIG"
echo ""

# Confirm installation
read -p "This will ERASE the target disk. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Setup environment
echo "Setting up environment..."
nix-env -f '<nixpkgs>' -iA git
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Clone repository
echo "Cloning configuration from branch '$REPO_BRANCH'..."
rm -rf /tmp/nix-config
git clone --branch "$REPO_BRANCH" "$REPO_URL" /tmp/nix-config

# Prepare disko configuration
echo "Preparing disk configuration..."
DISKO_FILE="/tmp/nix-config/disko/$DISKO_CONFIG"
sed -i "s|NVME_DISK_ID|$DISK_ID|g" "$DISKO_FILE"
sed -i "s|EMMC_DISK_ID|$DISK_ID|g" "$DISKO_FILE"

# Format and mount disk
echo "Formatting disk with disko..."
nix --experimental-features "nix-command flakes" run github:nix-community/disko \
    -- --mode format,mount "$DISKO_FILE"

# Copy configuration to target
echo "Copying configuration..."
mkdir -p /mnt/etc/nixos
cp -r /tmp/nix-config/* /mnt/etc/nixos/

# Install NixOS
echo "Installing NixOS..."
nixos-install \
  --root "/mnt" \
  --no-root-passwd \
  --flake "git+file:///mnt/etc/nixos#$HOSTNAME"

echo ""
echo "=== Installation Complete! ==="
echo "Next steps:"
echo "1. Remove installation media"
echo "2. Reboot: reboot"
echo "3. SSH into new system: ssh root@router-ip"
