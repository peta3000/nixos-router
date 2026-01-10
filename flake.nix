{
  description = "Router-only NixOS setup (GW-R86S)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {
    nixosConfigurations.gw-r86s-router = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/gw-r86s-router/default.nix
      ];
    };
  };
}
