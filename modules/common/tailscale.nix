{ config, lib, pkgs, ... }:

with lib;

{
  options.my.tailscale = {
    enable = mkEnableOption "Tailscale VPN";
    
    allowSsh = mkOption {
      type = types.bool;
      default = true;
      description = "Allow inbound SSH (22/tcp) via tailscale0 when networking.firewall is enabled.";
    };    

    # Optional: mark this host as a router / infra node
    advertiseRoutes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "CIDR routes to advertise via Tailscale";
    };

    # Optional: Tailscale ACL tags
    tags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Tailscale node tags";
    };
  };

  config = mkIf config.my.tailscale.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures =
        if config.my.tailscale.advertiseRoutes != []
        then "server"
        else "client";

      openFirewall = false; # we manage firewall ourselves
      extraUpFlags =
        concatLists [
          (optional (config.my.tailscale.tags != [])
            "--advertise-tags=${concatStringsSep "," config.my.tailscale.tags}")
          (optional (config.my.tailscale.advertiseRoutes != [])
            "--advertise-routes=${concatStringsSep "," config.my.tailscale.advertiseRoutes}")
        ];
    };
    # For "normal" hosts that use the standard NixOS firewall:
    # open SSH on tailscale0 only when the firewall is enabled.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts =
      mkIf (config.my.tailscale.allowSsh && (config.networking.firewall.enable or false)) [ 22 ];
  };
}

