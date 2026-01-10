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
  
  # SSH keys for user peter
  users.users.peter.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDEP5rIrh/WIZvCS8Tb4xkLtCDQAxs27Guxnxv0BQLs2iIe0kSmM+xXcvNCMSrmbNAzq6boSJsQ4PIVQCaSxNRrhcFH6Q1pY9y7MvbRqT72V++dQQtVKMkoVh4QQ5aobsml8KQx7QS6fuwEtMCE/8yoJPoyh1rqAqSS7/9MvA72Imr8LNdAkECDVkzrn3T8/gGJ9gEYFJrLpmm+lEzIU27P/x1BUQOpPbPMourkKdhSBgvr3LQCugEfzdUfskO8YCHmB+5KkCBXizpIH3QiN1TuZuPAT0ZacMAM1gZcZtEWr04K7hXdDgPCJzxDjfruoiOSqFvBYtdtECAb8AGicFqVuIGzIdYVP5pxWKwUR0LUXpSUKIqqF3gKc0HvSejxJ8NA79a2BS7ef7Plou4GmkfH+NdDti0iaS7pi6aqUTMVgGOvbDVTJT1L8clIdgLPomHL9kXae9EuiGHFSqpEC42FRFcmj30heWttG/OAo4Msbcs+ArruAskHJFN366rXRZM="
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICozYQT8O5X3hEKU7toJho+r66As0qaCt3nYXR0gRU0j"
  ];

  system.stateVersion = "25.11";

}
