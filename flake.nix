{
  description = "Harua's NixOS Configuration";

  inputs = {
    # Official NixOS package repository
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";

      # Make Home Manager use the same nixpkgs version
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations.HaruaKimihiro = nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        ./hosts/victus/configuration.nix

        home-manager.nixosModules.home-manager

        {
          # Home Manager settings
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          # User configuration file
          home-manager.users.harua = import ./users/harua/home.nix;
        }
      ];
    };
  };
}
