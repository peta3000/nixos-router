#!/usr/bin/env bash
set -e

# -----------------------------------------------------------------
#  Generic NixOS‑installer – works for router and workstation hosts
# -----------------------------------------------------------------
#  * Default (no arguments) → router on production eMMC (unchanged)
#  * --host <name>          → picks the host from the map below
#  * --disk <name>          → old shortcut (router‑only) – kept for compatibility
# -----------------------------------------------------------------

# ------------------------------
#  Configuration – host map
# ------------------------------
# Add new hosts here.  Each entry provides:
#   * disk_id        – the by‑id path that will be wiped/formatted
#   * disko_cfg     – the disko module that creates the layout
#   * hostname       – the flake host name (used by `nixos-install`)
#   * description    – short text shown in `--help`
# ------------------------------
declare -A HOST_MAP_DISK_ID
declare -A HOST_MAP_DISKO
declare -A HOST_MAP_HOSTNAME
declare -A HOST_MAP_DESC

# Router – production (eMMC)
HOST_MAP_DISK_ID[gw-r86s-router]="mmc-SCA128_0x06b27b7d"
HOST_MAP_DISKO[gw-r86s-router]="r86s-emmc.nix"
HOST_MAP_HOSTNAME[gw-r86s-router]="gw-r86s-router"
HOST_MAP_DESC[gw-r86s-router]="R86S router (production eMMC, WAN‑router appliance)"

# Router – testing (NVMe)
HOST_MAP_DISK_ID[gw-r86s-router-test]="nvme-WD_Red_SN700_250GB_230506800251"
HOST_MAP_DISKO[gw-r86s-router-test]="r86s-nvme.nix"
HOST_MAP_HOSTNAME[gw-r86s-router-test]="gw-r86s-router"
HOST_MAP_DESC[gw-r86s-router-test]="R86S router (testing NVMe SSD)"

# Workstation – Mini‑Forum MS‑01 (250 GB OS SSD)
HOST_MAP_DISK_ID[ms-01-workstation]="nvme-INTENSO_SSD_1642507006001001"
HOST_MAP_DISKO[ms-01-workstation]="ms01-os-250.nix"
HOST_MAP_HOSTNAME[ms-01-workstation]="ms-01-workstation"
HOST_MAP_DESC[ms-01-workstation]="MS‑01 workstation (250 GB OS SSD, NVIDIA GPU)"

# -----------------------------------------------------------------
#  Default values (matches the historic router script)
# -----------------------------------------------------------------
REPO_URL="https://github.com/peta3000/nixos-infra.git"
REPO_BRANCH="restructure"
TARGET_HOST="gw-r86s-router"           # default host
DISK_TARGET="emmc"                     # old compatibility flag
HOSTNAME=""                            # will be filled from the host-map or overridded from --hostname

# -----------------------------------------------------------------
#  Helper functions
# -----------------------------------------------------------------
print_help() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --host <name>       Choose a host defined in the script (router or workstation).
  --disk <name>       (legacy) Select a disk layout: nvme | emmc | workstation.
  --hostname <name>   Override the flake hostname (rarely needed).
  --repo <url>        Override the git repository URL.
  --branch <branch>   Override the git branch.
  --help              Show this help message.
  (If omitted, the hostname is taken from the host‑map entry for the selected host.)

Supported hosts:
EOF
  for h in "${!HOST_MAP_DESC[@]}"; do
    printf "  %-20s – %s\n" "$h" "${HOST_MAP_DESC[$h]}"
  done
  echo
}

error_exit() {
  echo "ERROR: $1" >&2
  exit 1
}

# -----------------------------------------------------------------
#  Parse arguments
# -----------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --host)      TARGET_HOST="$2"; shift 2 ;;
    --disk)      DISK_TARGET="$2"; shift 2 ;;
    --hostname)  HOSTNAME="$2";    shift 2 ;;
    --repo)      REPO_URL="$2";    shift 2 ;;
    --branch)    REPO_BRANCH="$2"; shift 2 ;;
    --help)      print_help; exit 0 ;;
    *)           error_exit "Unknown option: $1" ;;
  esac
done

# -----------------------------------------------------------------
#  Resolve target host → disk, disko, hostname
# -----------------------------------------------------------------
# If the user supplied only --disk (old behaviour) we map that to a host.
if [[ -z "${HOST_MAP_DISK_ID[$TARGET_HOST]}" ]]; then
  # No explicit host – try to infer from the legacy --disk flag
  case $DISK_TARGET in
    nvme)        TARGET_HOST="gw-r86s-router-test" ;;
    emmc)        TARGET_HOST="gw-r86s-router" ;;
    workstation) TARGET_HOST="ms-01-workstation" ;;
    *)           error_exit "Unsupported --disk value: $DISK_TARGET" ;;
  esac
fi

# Verify that the chosen host exists in our map
if [[ -z "${HOST_MAP_DISK_ID[$TARGET_HOST]}" ]]; then
  error_exit "Host '$TARGET_HOST' is not defined in the installer script."
fi

# Pull the concrete values
DISK_ID="${HOST_MAP_DISK_ID[$TARGET_HOST]}"
DISKO_CONFIG="${HOST_MAP_DISKO[$TARGET_HOST]}"
# -----------------------------------------------------------------
# Determine the flake hostname.
#   * If the user supplied --hostname, keep that value.
#   * Otherwise take the hostname defined in the host‑map.
# -----------------------------------------------------------------
if [ -z "$HOSTNAME" ]; then
  HOSTNAME="${HOST_MAP_HOSTNAME[$TARGET_HOST]}"
fi

# -----------------------------------------------------------------
#  Show a short summary (helps avoid accidental wipes)
# -----------------------------------------------------------------
cat <<EOF
=== NixOS Installation – Generic Installer ===
Target host      : $TARGET_HOST
Flake hostname   : $HOSTNAME
Disk ID (wipe)   : $DISK_ID
Disk layout file : $DISKO_CONFIG
Repository       : $REPO_URL (branch: $REPO_BRANCH)
EOF

# -----------------------------------------------------------------
#  Confirmation (dangerous operation)
# -----------------------------------------------------------------
read -p "THIS WILL COMPLETELY ERASE /dev/disk/by-id/$DISK_ID. Continue? (y/N) " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { echo "Installation cancelled."; exit 1; }

# -----------------------------------------------------------------
#  Environment preparation (same as original script)
# -----------------------------------------------------------------
echo "Setting up environment..."
nix-env -f '<nixpkgs>' -iA git
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# -----------------------------------------------------------------
#  Clone the flake repository
# -----------------------------------------------------------------
echo "Cloning repository (branch: $REPO_BRANCH)..."
tmpdir="/tmp/nix-config-$$"
rm -rf "$tmpdir"
git clone --branch "$REPO_BRANCH" "$REPO_URL" "$tmpdir"

# -----------------------------------------------------------------
#  Prepare the disko file (replace placeholders)
# -----------------------------------------------------------------
DISKO_FILE="$tmpdir/disko/$DISKO_CONFIG"
if [[ ! -f "$DISKO_FILE" ]]; then
  error_exit "Disco file $DISKO_FILE not found."
fi

echo "Injecting actual disk identifier..."
sed -i "s|NVME_DISK_ID|$DISK_ID|g; s|EMMC_DISK_ID|$DISK_ID|g" "$DISKO_FILE"

# -----------------------------------------------------------------
#  Verify the physical disk exists
# -----------------------------------------------------------------
if [[ ! -e "/dev/disk/by-id/$DISK_ID" ]]; then
  echo "Available disks:"
  ls -l /dev/disk/by-id/ | grep -E "(nvme|mmc)"
  error_exit "Disk /dev/disk/by-id/$DISK_ID not found."
fi

# -----------------------------------------------------------------
#  **FULL DISK WIPE**
# -----------------------------------------------------------------
echo "=== COMPLETE DISK WIPE ==="
sudo wipefs -a "/dev/disk/by-id/$DISK_ID"

# --- option with dd: slower, will owerwrite with zeros------------
# Zero‑fill the entire SSD.  No `count=` → writes until EOF.
# sudo dd if=/dev/zero of="/dev/disk/by-id/$DISK_ID" bs=1M status=progress

# --- option with sgdisk: quicker, does not write zeros------------
# Make sure sgdisk is available (install it if necessary)
nix-env -f '<nixpkgs>' -iA nixpkgs.gdisk   # <-- you can comment this out if gdisk is already on the system

# Zap the entire partition table (fast, no data‑zeroing)
sudo sgdisk --zap-all "/dev/disk/by-id/$DISK_ID"

# Flush caches so the kernel sees the cleared device before disko.
sync

sleep 2   # let the kernel see the changes

# -----------------------------------------------------------------
#  Run disko to format + mount the partitions
# -----------------------------------------------------------------
echo "Running disko (format,mount) ..."
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko \
    -- --mode format,mount "$DISKO_FILE"

# -----------------------------------------------------------------
#  Copy the configuration into the mounted target
# -----------------------------------------------------------------
echo "Copying flake configuration to /mnt ..."
sudo mkdir -p /mnt/etc/nixos
sudo cp -r "$tmpdir"/* /mnt/etc/nixos/
sudo chown -R root:root /mnt/etc/nixos

# -----------------------------------------------------------------
#  NixOS installation
# -----------------------------------------------------------------
echo "Running nixos-install ..."
if [[ -d "/mnt/etc/nixos/.git" ]]; then
  sudo nixos-install --root /mnt --no-root-passwd --flake "git+file:///mnt/etc/nixos#$HOSTNAME"
else
  sudo nixos-install --root /mnt --no-root-passwd --flake "/mnt/etc/nixos#$HOSTNAME"
fi

# -----------------------------------------------------------------
#  Finish
# -----------------------------------------------------------------
cat <<EOF

=== Installation complete! ===
* Remove the install media
* Reboot (`reboot`)
* SSH to the new host (e.g. `ssh peter@$HOSTNAME`)

EOF
