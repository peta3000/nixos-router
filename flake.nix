{
  description = "NixOS Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, disko, agenix, ... }:
  {
    nixosConfigurations = {
      gw-r86s-router = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/gw-r86s-router/default.nix
          disko.nixosModules.disko
          agenix.nixosModules.default
        ];
      };
      
      # Future hosts can be added here
      # monitoring-pi = nixpkgs.lib.nixosSystem { ... };

      # <‑‑ NEW workstation host
      ms-01-workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/ms-01-workstation/default.nix   # <-- create this file
          disko.nixosModules.disko                # for automated partitioning
          agenix.nixosModules.default             # (optional) secret handling
        ];
      };
    };
  };
}
