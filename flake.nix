{
  description = "NixOS Infrastructure (Router + Future Hosts)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
  };

  outputs = { nixpkgs, disko, ... }:
  {
    nixosConfigurations = {
      gw-r86s-router = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/gw-r86s-router/default.nix
          disko.nixosModules.disko
        ];
      };
      
      # Future hosts can be added here
      # monitoring-pi = nixpkgs.lib.nixosSystem { ... };
    };
  };
}
