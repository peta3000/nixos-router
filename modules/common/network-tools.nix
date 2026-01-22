{ pkgs, lib, config, ... }:

{
  options.my.networkTools = {
    enable = lib.mkEnableOption "network diagnostic tools";
  };

  config = lib.mkIf config.my.networkTools.enable {
    environment.systemPackages = with pkgs; [
      # Basic network tools
      nettools      # arp, netstat, route
      iproute2      # ip command (modern replacement)
      bind.dnsutils # dig, nslookup, host
      
      # Network testing & debugging
      mtr          # better traceroute
      iperf3       # bandwidth testing
      tcpdump      # packet capture
      nmap         # network scanning
      socat        # network debugging
      
      # HTTP/web tools
      curl wget    # web requests
      
      # Hardware tools
      ethtool      # ethernet settings
      
      # Analysis (CLI versions)
      wireshark-cli # tshark, etc.
    ];
  };
}
