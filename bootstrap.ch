#!/usr/bin/env bash
set -euo pipefail

mkdir -p lib modules/base modules/router hosts/gw-r86s-router

cat > flake.nix <<'EOF'
{
  description = "Router-only NixOS setup (GW-R86S)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {
    nixosConfigurations.gw-r86s-router = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/gw-r86s-router/default.nix
      ];
    };
  };
}
EOF

cat > lib/networks.nix <<'EOF'
# Single source of truth for VLANs/subnets and interface roles.
{
  # WAN selection:
  # - testing: enp1s0 (RJ45)
  # - production: enp5s0d1 (SFP+)
  wan = {
    testing = "enp1s0";
    production = "enp5s0d1";
  };

  lan = {
    bridge = "br-switch";
    # Initial bridge/trunk ports (LAN side)
    ports = [ "enp2s0" "enp3s0" "enp5s0" ];
  };

  # VLANs: VLAN 1 untagged (PVID) on all bridge ports.
  # VLAN 20/30/40/50 tagged on all bridge ports (for now).
  vlans = {
    lan     = { id = 1;  ifname = "br-switch";    cidr = "192.168.5.1/24";   };
    guest   = { id = 20; ifname = "br-switch.20"; cidr = "192.168.20.1/24";  };
    iot     = { id = 30; ifname = "br-switch.30"; cidr = "192.168.30.1/24";  };
    printer = { id = 40; ifname = "br-switch.40"; cidr = "192.168.40.1/24";  };
    dmz     = { id = 50; ifname = "br-switch.50"; cidr = "192.168.50.1/24";  };
  };

  dhcp = {
    lan     = { start = 100; end = 249; lease = "12h"; };
    guest   = { start = 100; end = 249; lease = "12h"; };
    iot     = { start = 100; end = 249; lease = "12h"; };
    printer = { start = 100; end = 249; lease = "12h"; };
    dmz     = { start = 100; end = 249; lease = "12h"; };
  };
}
EOF

cat > modules/base/default.nix <<'EOF'
{ config, lib, pkgs, ... }:
{
  time.timeZone = "Europe/Zurich";

  # Basic admin access
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
  };

  # Helpful tools on a router appliance
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    tcpdump
    ethtool
    iproute2
    nftables
  ];

  # Make sure systemd-networkd is used for the networking approach here.
  networking.useNetworkd = true;
  systemd.network.enable = true;

  # Router appliances should generally avoid NetworkManager
  networking.networkmanager.enable = false;

  # Keep Nix nice to work with
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
EOF

cat > modules/router/default.nix <<'EOF'
{ config, lib, pkgs, ... }:
{
  imports = [
    ./sysctl.nix
    ./interfaces.nix
    ./nat.nix
    ./dhcp-dns.nix
    ./firewall.nix
  ];
}
EOF

cat > modules/router/sysctl.nix <<'EOF'
{ config, lib, ... }:
{
  # Enable routing
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    # Reasonable anti-spoofing defaults (tune later if needed)
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
  };
}
EOF

cat > modules/router/interfaces.nix <<'EOF'
{ config, lib, pkgs, ... }:

let
  nets = import ../../lib/networks.nix;
  bridge = nets.lan.bridge;
  lanPorts = nets.lan.ports;
in
{
  # Host decides WAN interface via hosts/<name>/default.nix
  options.router.wan.interface = lib.mkOption {
    type = lib.types.str;
    description = "Physical WAN interface name (e.g. enp1s0 for testing, enp5s0d1 for production).";
  };

  config = {
    # Ensure systemd-networkd is running
    systemd.network.enable = true;

    # Create the bridge with VLAN filtering
    systemd.network.netdevs."${bridge}" = {
      netdevConfig = {
        Name = bridge;
        Kind = "bridge";
      };
      bridgeConfig = {
        VLANFiltering = true;
      };
    };

    # Add LAN ports to the bridge and define per-port VLAN policy:
    # VLAN 1: PVID + untagged (management/LAN by default)
    # VLAN 20/30/40/50: tagged (trunk everywhere initially)
    systemd.network.networks."lan-ports" = {
      matchConfig.Name = lib.concatStringsSep " " lanPorts;
      networkConfig = {
        Bridge = bridge;
        ConfigureWithoutCarrier = true;
      };

      bridgeVLANs = [
        { VLAN = 1;  PVID = true; EgressUntagged = true; }
        { VLAN = 20; }
        { VLAN = 30; }
        { VLAN = 40; }
        { VLAN = 50; }
      ];
    };

    # WAN (DHCP for testing; later you can change to static if you want)
    systemd.network.networks."wan" = {
      matchConfig.Name = config.router.wan.interface;
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
    };

    # L3 on VLAN 1 (bridge itself)
    systemd.network.networks."${bridge}-vlan1" = {
      matchConfig.Name = bridge;
      networkConfig.ConfigureWithoutCarrier = true;
      address = [ nets.vlans.lan.cidr ];
    };

    # Create VLAN netdevs on the bridge for the tagged VLANs
    systemd.network.netdevs."${bridge}.20" = {
      netdevConfig = { Name = "${bridge}.20"; Kind = "vlan"; };
      vlanConfig.Id = 20;
    };
    systemd.network.netdevs."${bridge}.30" = {
      netdevConfig = { Name = "${bridge}.30"; Kind = "vlan"; };
      vlanConfig.Id = 30;
    };
    systemd.network.netdevs."${bridge}.40" = {
      netdevConfig = { Name = "${bridge}.40"; Kind = "vlan"; };
      vlanConfig.Id = 40;
    };
    systemd.network.netdevs."${bridge}.50" = {
      netdevConfig = { Name = "${bridge}.50"; Kind = "vlan"; };
      vlanConfig.Id = 50;
    };

    # Assign addresses to VLAN interfaces
    systemd.network.networks."vlan20" = {
      matchConfig.Name = "${bridge}.20";
      address = [ nets.vlans.guest.cidr ];
    };
    systemd.network.networks."vlan30" = {
      matchConfig.Name = "${bridge}.30";
      address = [ nets.vlans.iot.cidr ];
    };
    systemd.network.networks."vlan40" = {
      matchConfig.Name = "${bridge}.40";
      address = [ nets.vlans.printer.cidr ];
    };
    systemd.network.networks."vlan50" = {
      matchConfig.Name = "${bridge}.50";
      address = [ nets.vlans.dmz.cidr ];
    };
  };
}
EOF

cat > modules/router/dhcp-dns.nix <<'EOF'
{ config, lib, pkgs, ... }:

let
  nets = import ../../lib/networks.nix;
  b = nets.lan.bridge;
in
{
  # dnsmasq = simple and very close to OpenWrt behaviour
  services.dnsmasq = {
    enable = true;

    # Keep it explicit: only listen on internal interfaces
    settings = {
      domain-needed = true;
      bogus-priv = true;
      expand-hosts = true;
      domain = "lan";

      # Bind to the router's internal interfaces:
      interface = [
        b
        "${b}.20"
        "${b}.30"
        "${b}.40"
        "${b}.50"
      ];
      bind-interfaces = true;

      # DHCP ranges per VLAN
      dhcp-range = [
        "interface:${b},192.168.5.${toString nets.dhcp.lan.start},192.168.5.${toString nets.dhcp.lan.end},${nets.dhcp.lan.lease}"
        "interface:${b}.20,192.168.20.${toString nets.dhcp.guest.start},192.168.20.${toString nets.dhcp.guest.end},${nets.dhcp.guest.lease}"
        "interface:${b}.30,192.168.30.${toString nets.dhcp.iot.start},192.168.30.${toString nets.dhcp.iot.end},${nets.dhcp.iot.lease}"
        "interface:${b}.40,192.168.40.${toString nets.dhcp.printer.start},192.168.40.${toString nets.dhcp.printer.end},${nets.dhcp.printer.lease}"
        "interface:${b}.50,192.168.50.${toString nets.dhcp.dmz.start},192.168.50.${toString nets.dhcp.dmz.end},${nets.dhcp.dmz.lease}"
      ];

      # ---- Static leases (add yours here) ----
      # dhcp-host = [
      #   "14:33:75:17:0C:DD,192.168.5.110,Zyxel--NWA50AX-PRO"
      #   "30:05:5C:4E:BF:FC,192.168.5.230,BRN30055C4EBFFC"
      # ];
    };
  };
}
EOF

cat > modules/router/nat.nix <<'EOF'
{ config, lib, ... }:
{
  # We will do NAT in nftables (see firewall.nix).
  # This module exists to make the intent explicit and easy to extend later.
}
EOF

cat > modules/router/firewall.nix <<'EOF'
{ config, lib, pkgs, ... }:

let
  nets = import ../../lib/networks.nix;
  b = nets.lan.bridge;
  wan = config.router.wan.interface;
in
{
  networking.nftables.enable = true;

  # IMPORTANT:
  # - Default: drop inbound from WAN
  # - Allow LAN management (ssh) from VLAN1 by default
  # - Allow DNS/DHCP to router from internal VLANs
  # - Allow forwarding from internal VLANs -> WAN
  # - Allow LAN (VLAN1) -> IoT/Printer/DMZ (like your OpenWrt forwardings)
  #
  # You can refine inter-VLAN later (e.g. block Guest -> LAN, etc.)
  networking.nftables.ruleset = ''
    flush ruleset

    define WAN = ${wan}
    define LAN = ${b}
    define GUEST = ${b}.20
    define IOT = ${b}.30
    define PRINTER = ${b}.40
    define DMZ = ${b}.50

    table inet filter {
      chain input {
        type filter hook input priority 0; policy drop;

        iif "lo" accept
        ct state established,related accept

        # ICMP is useful for debugging (tune later if desired)
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # Allow DHCP/DNS to router from internal nets
        iifname $LAN udp dport {67, 53} accept
        iifname $LAN tcp dport 53 accept

        iifname $GUEST udp dport {67, 53} accept
        iifname $GUEST tcp dport 53 accept

        iifname $IOT udp dport {67, 53} accept
        iifname $IOT tcp dport 53 accept

        iifname $PRINTER udp dport {67, 53} accept
        iifname $PRINTER tcp dport 53 accept

        iifname $DMZ udp dport {67, 53} accept
        iifname $DMZ tcp dport 53 accept

        # Allow SSH management from VLAN1 (LAN)
        iifname $LAN tcp dport 22 accept

        # Drop everything else (including inbound from WAN)
      }

      chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept

        # Allow internal -> WAN
        iifname { $LAN, $GUEST, $IOT, $PRINTER, $DMZ } oifname $WAN accept

        # Allow LAN -> internal (management can reach segments)
        iifname $LAN oifname { $GUEST, $IOT, $PRINTER, $DMZ } accept

        # (Optional) allow DMZ -> LAN? Default is no.
        # iifname $DMZ oifname $LAN accept
      }
    }

    table inet nat {
      chain postrouting {
        type nat hook postrouting priority 100; policy accept;

        # Masquerade internal networks out to WAN
        oifname $WAN masquerade
      }
    }
  '';
}
EOF

cat > hosts/gw-r86s-router/default.nix <<'EOF'
{ config, lib, pkgs, ... }:

let
  nets = import ../../lib/networks.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base/default.nix
    ../../modules/router/default.nix
  ];

  networking.hostName = "gw-r86s-router";

  # Choose WAN interface:
  # - testing: enp1s0
  # - production: enp5s0d1
  router.wan.interface = nets.wan.testing;

  # Optional: static addressing on WAN instead of DHCP (uncomment if needed)
  # systemd.network.networks."wan".networkConfig.DHCP = "no";
  # systemd.network.networks."wan".address = [ "192.168.1.179/24" ];
  # systemd.network.networks."wan".routes = [
  #   { routeConfig.Gateway = "192.168.1.1"; }
  # ];
  # networking.nameservers = [ "192.168.1.10" "192.168.1.1" ];
}
EOF

cat > hosts/gw-r86s-router/hardware-configuration.nix <<'EOF'
# Placeholder: replace this file with the real one from:
#   /etc/nixos/hardware-configuration.nix
# generated on the GW-R86S with nixos-generate-config.
{ ... }: { }
EOF

echo "Done."
echo
echo "Next steps:"
echo "1) Replace hosts/gw-r86s-router/hardware-configuration.nix with the real generated one."
echo "2) Run: sudo nixos-rebuild switch --flake .#gw-r86s-router"
EOF

