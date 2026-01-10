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
