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
  
  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "gw-r86s-router";
  
  # Basic services
  services.openssh.enable = true;

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
  
  # User configuration
  users.users.peter = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "25.11";

}
