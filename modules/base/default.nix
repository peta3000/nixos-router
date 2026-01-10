{ config, lib, pkgs, ... }:
{
  time.timeZone = "Europe/Zurich";
  
  imports = [
    ../common/tailscale.nix
    # other shared modules
  ];

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

  # Enable default NixOS firewall for all nosts by default
  networking.firewall.enable = lib.mkDefault true;

  # Keep Nix nice to work with
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
