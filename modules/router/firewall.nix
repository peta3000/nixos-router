{ config, lib, pkgs, ... }:
let
  nets = import ../../lib/networks.nix;
  b = nets.lan.bridge;
  wan = config.router.wan.interface;
in {
  networking.nftables.enable = true;

  # Enhanced firewall ruleset matching OpenWrt configuration
  # Implements all inter-VLAN policies and specific restrictions
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
        type filter hook input priority 0;
        policy drop;

        iif "lo" accept
        ct state established,related accept

        # ICMP - allow ping for debugging and network health
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept

        # Allow DHCP/DNS to router from all internal networks
        iifname $LAN udp dport { 53, 67, 68 } accept
        iifname $LAN tcp dport 53 accept
        iifname $GUEST udp dport { 53, 67, 68 } accept
        iifname $GUEST tcp dport 53 accept
        iifname $IOT udp dport { 53, 67, 68 } accept
        iifname $IOT tcp dport 53 accept
        iifname $PRINTER udp dport { 53, 67, 68 } accept
        iifname $PRINTER tcp dport 53 accept
        iifname $DMZ udp dport { 53, 67, 68 } accept
        iifname $DMZ tcp dport 53 accept

        # Allow SSH management from VLAN1 (LAN)
        iifname $LAN tcp dport 22 accept
        
        # Allow SSH access via tailscale
        iifname "tailscale0" tcp dport 22 accept

        # WAN input rules (essential services only)
        # DHCP client renewal
        iifname $WAN udp dport 68 accept
        # Allow ping from WAN (matching OpenWrt)
        iifname $WAN ip protocol icmp icmp type echo-request accept
        # IGMP for multicast
        iifname $WAN ip protocol igmp accept

        # IPv6 essential services from WAN
        iifname $WAN ip6 nexthdr udp udp dport 546 accept  # DHCPv6
        iifname $WAN ip6 saddr fe80::/10 ip6 nexthdr icmpv6 icmpv6 type { 130, 131, 132, 143 } accept  # MLD
        iifname $WAN ip6 nexthdr icmpv6 icmpv6 type { echo-request, echo-reply, destination-unreachable, packet-too-big, time-exceeded, nd-router-solicit, nd-neighbor-solicit, nd-router-advert, nd-neighbor-advert } limit rate 1000/second accept

        # VPN support (if needed)
        # iifname $WAN ip protocol esp accept  # IPSec ESP
        # iifname $WAN udp dport 500 accept    # ISAKMP

        # TEMP: allow SSH from upstream LAN on WAN (remove in production)
        iifname $WAN ip saddr 192.168.3.0/24 tcp dport 22 accept

        # Block everything else from WAN
      }

      chain forward {
        type filter hook forward priority 0;
        policy drop;

        ct state established,related accept

        # === WAN INBOUND RULES ===
        # Allow HTTP/HTTPS to DMZ from WAN (web services)
        iifname $WAN oifname $DMZ tcp dport { 80, 443 } accept

        # === INTERNAL -> WAN (Internet Access) ===
        # All internal networks can access internet
        iifname { $LAN, $GUEST, $IOT, $PRINTER, $DMZ } oifname $WAN accept

        # === LAN (Management) -> Internal Networks ===
        # LAN has full access to all segments (management network)
        iifname $LAN oifname { $GUEST, $IOT, $PRINTER, $DMZ } accept

        # === GUEST NETWORK POLICIES ===
        # Guest -> Printer network (for printing access)
        iifname $GUEST oifname $PRINTER accept
        
        # Block Guest access to specific router/management IPs
        iifname $GUEST oifname $LAN ip daddr { 192.168.5.1, 192.168.5.110 } reject
        iifname $GUEST oifname $PRINTER ip daddr { 192.168.40.1, 192.168.40.217 } tcp reject
        
        # Block Guest access to printer admin interface
        iifname $GUEST oifname $PRINTER ip daddr 192.168.40.230 tcp dport { 80, 443 } reject

        # === IOT NETWORK POLICIES ===
        # IoT is isolated - only internet access (already allowed above)
        # No lateral movement to other VLANs

        # === PRINTER NETWORK POLICIES ===
        # Printers are mostly isolated - only internet and admin from LAN
        # (Optional) Allow printer -> LAN for specific services
        # iifname $PRINTER oifname $LAN tcp dport { 445, 139 } accept  # SMB if needed

        # === DMZ POLICIES ===
        # DMZ isolated except for internet access
        # Web services accessible from WAN (handled above)

        # === UNIFI CONTROLLER RULES ===
        # Allow access to UniFi controller on upstream network
        iifname $LAN oifname $WAN ip daddr 192.168.1.166 tcp dport { 8080, 8443 } accept
        iifname $LAN oifname $WAN ip daddr 192.168.1.166 udp dport 3478 accept  # STUN
        
        # Allow APs to inform controller (from any internal network)
        iifname { $LAN, $GUEST, $IOT, $PRINTER } oifname $WAN ip daddr 192.168.1.166 tcp dport 8080 accept

        # === IPv6 FORWARDING ===
        # Allow essential IPv6 forwarding
        iifname $WAN ip6 nexthdr icmpv6 icmpv6 type { echo-request, echo-reply, destination-unreachable, packet-too-big, time-exceeded } limit rate 1000/second accept

        # Drop everything else
      }
    }

    table inet nat {
      chain postrouting {
        type nat hook postrouting priority 100;
        policy accept;

        # Masquerade internal networks going to WAN
        oifname $WAN masquerade
      }
    }
  '';
}
