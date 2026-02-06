{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix                # generated on the *new* OS SSD
    ../../modules/base/default.nix               # SSH, firewall, common tools
    ../../modules/common/tailscale.nix           # optional VPN
    ../../modules/common/network-tools.nix       # iproute2, curl, etc.
    ../../modules/workstation/desktop.nix        # X/Wayland, GPU, Steam, etc.
    ../../modules/common/persist.nix             # bind‑mounts for /persist
 
    # --------Disk layout modules ------------------------------------------------
    ../../disko/ms01-os-250.nix                  # OS‑disk layout (ext4)
    ../../disko/ms01-data-512.nix                # 512 GB Btrfs pool
#    ../../disko/ms01-data-1tb.nix                # 1 TB Btrfs pool (optional), uncomment once ready
  ];

  # -------------------------------------------------
  # Host‑specific values
  # -------------------------------------------------
  networking.hostName = "ms-01-workstation";

  # If you want the router‑related modules (sysctl, SQM) you can import them as well:
  # imports = imports ++ [ ../../modules/router/sysctl.nix ../../modules/router/sqm.nix ];

  # Enable the data‑disk bind‑mounts defined in persist.nix:
  # (persist.nix contains the /persist mount and the bind‑mounts for /home, /var/lib, …)

  # Example – enable the LLM service that you already have on the router:
  # imports = imports ++ [ ../../modules/router/llm-service.nix ];
}
