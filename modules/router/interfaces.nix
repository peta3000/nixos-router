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

      extraConfig = ''
        [BridgeVLAN]
        VLAN=1
        PVID=1
        EgressUntagged=1

        [BridgeVLAN]
        VLAN=20
        [BridgeVLAN]
        VLAN=30
        [BridgeVLAN]
        VLAN=40
        [BridgeVLAN]
        VLAN=50
      '';

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
    systemd.network.networks."${bridge}-base" = {
      matchConfig.Name = bridge;
      networkConfig = {
        ConfigureWithoutCarrier = true;
        # Tell networkd that VLANs exist on this link:
        VLAN = [ "${bridge}.20" "${bridge}.30" "${bridge}.40" "${bridge}.50" ];
      };
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
