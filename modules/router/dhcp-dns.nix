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
