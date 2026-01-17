{ config, lib, pkgs, ... }:
{
  imports = [
    ./sysctl.nix
    ./interfaces.nix
    ./nat.nix
    ./dhcp-dns.nix
    ./firewall.nix
    ./sqm.nix
  ];
}
