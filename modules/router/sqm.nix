{ config, lib, pkgs, ... }:

let
  nets = import ../../lib/networks.nix;
  wan = config.router.wan.interface;
  
  # SQM configuration options
  cfg = config.router.sqm;
in
{
  options.router.sqm = {
    enable = lib.mkEnableOption "SQM (Smart Queue Management) with CAKE";
    
    upstreamBandwidth = lib.mkOption {
      type = lib.types.str;
      default = "900mbit";
      description = "Upstream bandwidth (slightly less than ISP speed)";
    };
    
    downstreamBandwidth = lib.mkOption {
      type = lib.types.str; 
      default = "900mbit";
      description = "Downstream bandwidth (slightly less than ISP speed)";
    };
    
    queueSize = lib.mkOption {
      type = lib.types.str;
      default = "1514";
      description = "Queue size in bytes (MTU + overhead)";
    };
    
    overheadBytes = lib.mkOption {
      type = lib.types.int;
      default = 44;
      description = "Overhead bytes for CAKE (PPPoE: 30, VLAN: 18, Ethernet: 14, etc)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure required kernel modules are available
    boot.kernelModules = [ "sch_cake" "sch_fq_codel" "act_mirred" "cls_u32" ];
    
    # Enable traffic control tools
    environment.systemPackages = with pkgs; [
      iproute2
      tcpdump
      ethtool
    ];

    # Create systemd service for SQM setup
    systemd.services.sqm-setup = {
      description = "Smart Queue Management (SQM) with CAKE";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "systemd-networkd.service" ];
      wants = [ "systemd-networkd.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "sqm-setup" ''
          #!/bin/bash
          set -e
          
          WAN_IFACE="${wan}"
          UPSTREAM_BW="${cfg.upstreamBandwidth}"
          DOWNSTREAM_BW="${cfg.downstreamBandwidth}"
          OVERHEAD=${toString cfg.overheadBytes}
          
          echo "Setting up SQM on interface: $WAN_IFACE"
          echo "Upstream: $UPSTREAM_BW, Downstream: $DOWNSTREAM_BW"
          
          # Remove existing qdiscs
          ${pkgs.iproute2}/bin/tc qdisc del dev "$WAN_IFACE" root 2>/dev/null || true
          ${pkgs.iproute2}/bin/tc qdisc del dev "$WAN_IFACE" ingress 2>/dev/null || true
          
          # Set up CAKE qdisc for upstream (egress)
          ${pkgs.iproute2}/bin/tc qdisc add dev "$WAN_IFACE" root cake \
            bandwidth "$UPSTREAM_BW" \
            overhead $OVERHEAD \
            besteffort \
            dual-dsthost \
            nat \
            wash \
            split-gso \
            ack-filter-aggressive \
            memlimit 32Mb \
            fwmark 0x1/0x1
          
          # Create ingress qdisc for downstream shaping
          ${pkgs.iproute2}/bin/tc qdisc add dev "$WAN_IFACE" handle ffff: ingress
          
          # Create IFB (Intermediate Functional Block) interface for downstream
          ${pkgs.iproute2}/bin/ip link add name ifb4"$WAN_IFACE" type ifb
          ${pkgs.iproute2}/bin/ip link set ifb4"$WAN_IFACE" up
          
          # Redirect ingress traffic to IFB interface
          ${pkgs.iproute2}/bin/tc filter add dev "$WAN_IFACE" parent ffff: \
            protocol ip \
            u32 match u32 0 0 \
            action mirred egress redirect dev ifb4"$WAN_IFACE"
          
          # Set up CAKE on IFB for downstream
          ${pkgs.iproute2}/bin/tc qdisc add dev ifb4"$WAN_IFACE" root cake \
            bandwidth "$DOWNSTREAM_BW" \
            overhead $OVERHEAD \
            besteffort \
            dual-srchost \
            nat \
            wash \
            ingress \
            split-gso \
            ack-filter-aggressive \
            memlimit 32Mb
          
          echo "SQM setup complete"
          
          # Show current configuration
          echo "=== Current TC Configuration ==="
          ${pkgs.iproute2}/bin/tc -s qdisc show dev "$WAN_IFACE"
          ${pkgs.iproute2}/bin/tc -s qdisc show dev ifb4"$WAN_IFACE" 2>/dev/null || true
        '';
        
        ExecStop = pkgs.writeShellScript "sqm-stop" ''
          #!/bin/bash
          WAN_IFACE="${wan}"
          
          echo "Stopping SQM on interface: $WAN_IFACE"
          
          # Remove qdiscs
          ${pkgs.iproute2}/bin/tc qdisc del dev "$WAN_IFACE" root 2>/dev/null || true
          ${pkgs.iproute2}/bin/tc qdisc del dev "$WAN_IFACE" ingress 2>/dev/null || true
          
          # Remove IFB interface
          ${pkgs.iproute2}/bin/ip link del ifb4"$WAN_IFACE" 2>/dev/null || true
          
          echo "SQM stopped"
        '';
      };
    };

    # Create monitoring script
    environment.etc."sqm-status.sh" = {
      text = ''
        #!/bin/bash
        
        WAN_IFACE="${wan}"
        
        echo "=== SQM Status for $WAN_IFACE ==="
        echo
        
        echo "--- Root qdisc (upstream) ---"
        tc -s qdisc show dev "$WAN_IFACE" | grep -A 5 "qdisc cake"
        
        echo
        echo "--- Ingress qdisc ---"
        tc -s qdisc show dev "$WAN_IFACE" | grep -A 5 "qdisc ingress"
        
        echo
        echo "--- IFB qdisc (downstream) ---"
        tc -s qdisc show dev "ifb4$WAN_IFACE" 2>/dev/null || echo "IFB interface not found"
        
        echo
        echo "--- Interface statistics ---"
        ip -s link show "$WAN_IFACE" | grep -A 2 -E "(RX|TX):"
        
        echo
        echo "--- CAKE statistics (if available) ---"
        tc -s -d qdisc show dev "$WAN_IFACE" | grep -A 20 "qdisc cake" || echo "CAKE stats not available"
      '';
      mode = "0755";
    };

    # Sysctl optimizations for SQM
    boot.kernel.sysctl = {
      # Network buffer tuning
      "net.core.default_qdisc" = "fq_codel";
      "net.core.rmem_default" = 262144;
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_default" = 262144; 
      "net.core.wmem_max" = 16777216;
      "net.core.netdev_max_backlog" = 5000;
      
      # TCP congestion control and buffering
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.ipv4.tcp_rmem" = "4096 87380 16777216";
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";
      "net.ipv4.tcp_mtu_probing" = 1;
      
      # Reduce buffer bloat
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_notsent_lowat" = 16384;
    };
  };
}