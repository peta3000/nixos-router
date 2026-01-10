{ config, lib, pkgs, ... }:

let
  nets = import ../../lib/networks.nix;
  bridge = nets.lan.bridge;

  # Helper: create a deterministic per-port network config
  # (More reliable than "Name=a b c", and it wins over generic 99-* defaults.)
  mkLanPort = ifname: {
    matchConfig.Name = ifname;
    networkConfig = {
      Bridge = bridge;
      ConfigureWithoutCarrier = true;

      # LAN ports must not become DHCP clients
      DHCP = "no";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
    };

    # VLAN 1 untagged everywhere; VLANs 20/30/40/50 tagged everywhere (for now)
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

    # LAN ports -> bridge (one .network per port, stable matching)
    systemd.network.networks."10-lan-enp2s0" = mkLanPort "enp2s0";
    systemd.network.networks."10-lan-enp3s0" = mkLanPort "enp3s0";
    systemd.network.networks."10-lan-enp5s0" = mkLanPort "enp5s0";

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

        # Tell networkd that VLAN netdevs exist on this link
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
      networkConfig.ConfigureWithoutCarrier = true;
      address = [ nets.vlans.guest.cidr ];
    };
    systemd.network.networks."vlan30" = {
      matchConfig.Name = "${bridge}.30";
      networkConfig.ConfigureWithoutCarrier = true;
      address = [ nets.vlans.iot.cidr ];
    };
    systemd.network.networks."vlan40" = {
      matchConfig.Name = "${bridge}.40";
      networkConfig.ConfigureWithoutCarrier = true;
      address = [ nets.vlans.printer.cidr ];
    };
    systemd.network.networks."vlan50" = {
      matchConfig.Name = "${bridge}.50";
      networkConfig.ConfigureWithoutCarrier = true;
      address = [ nets.vlans.dmz.cidr ];
    };
  };
}
