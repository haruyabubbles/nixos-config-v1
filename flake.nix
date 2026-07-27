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

    # nix-flatpak input
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # Add lobster repository
    lobster.url = "github:justchokingaround/lobster";
  };

  # 1. Added "@ inputs" here to make the variable accessible
  outputs = { self, nixpkgs, home-manager, nix-flatpak, lobster, ... } @ inputs:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations.victus = nixpkgs.lib.nixosSystem {
      inherit system;

      # 2. Added specialArgs to pass inputs down to modules/development.nix
      specialArgs = { inherit inputs; };

      modules = [
        ./hosts/victus/configuration.nix

        home-manager.nixosModules.home-manager
        
        # Load nix-flatpak module into the system
        nix-flatpak.nixosModules.nix-flatpak

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
