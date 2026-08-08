{
  # A short human-readable description of this flake.
  # Shown by `nix flake metadata` and flake registries.
  description = "Harua's NixOS Configuration";

  # ============================================================
  # INPUTS
  # These are external Nix flakes that this config depends on.
  # Each input is fetched and locked in flake.lock so builds
  # are reproducible — `nix flake update` refreshes the lock.
  # ============================================================
  inputs = {
    # The main NixOS package repository, pinned to the 26.05 stable release.
    # All packages (pkgs.*) come from here unless overridden.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Home Manager manages per-user config (dotfiles, user packages, etc.)
    # Pinned to the matching release so it stays compatible with nixpkgs.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";

      # Tell home-manager to reuse the same nixpkgs we declared above
      # instead of fetching its own copy — saves bandwidth and ensures
      # both use identical package versions.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-flatpak lets you declaratively install Flatpak apps from Flathub
    # (or any Flatpak remote) inside your NixOS config.
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # lobster — a CLI media player/streamer tool.
    lobster.url = "github:justchokingaround/lobster";

    # Noctalia — the Wayland desktop shell (bar, launcher, notifications,
    # lock screen, control center, etc.) used in the NNN stack.
    #
    # IMPORTANT: we intentionally do NOT add `inputs.nixpkgs.follows = nixpkgs`
    # here. Noctalia provides a binary cache (noctalia.cachix.org) to avoid
    # compiling from source. That cache is built against Noctalia's own pinned
    # nixpkgs. If we force it to follow our nixpkgs the store hashes won't
    # match and the cache will be useless — everything compiles locally instead.
    noctalia.url = "github:noctalia-dev/noctalia";
  };

  # ============================================================
  # OUTPUTS
  # This is what the flake produces — in our case, one NixOS
  # system configuration named "victus" (the machine hostname).
  #
  # `@ inputs` captures the whole inputs attrset so we can pass
  # it down into modules that need to reference other flakes
  # (e.g. noctalia's NixOS module and home-manager module).
  # ============================================================
  outputs = { self, nixpkgs, home-manager, nix-flatpak, lobster, noctalia, ... } @ inputs:
  let
    # The CPU architecture of the target machine.
    # x86_64-linux covers most modern 64-bit Intel/AMD PCs.
    system = "x86_64-linux";
  in
  {
    # "victus" matches the `networking.hostName` set in configuration.nix.
    # Build/switch with: sudo nixos-rebuild switch --flake /etc/nixos#victus
    nixosConfigurations.victus = nixpkgs.lib.nixosSystem {
      inherit system;

      # specialArgs passes extra values into every NixOS module's function
      # arguments. We pass `inputs` so modules can import from other flakes
      # (e.g. `inputs.noctalia.nixosModules.default` in nnn.nix).
      specialArgs = { inherit inputs; };

      modules = [
        # Main host configuration — hardware, services, users, etc.
        ./hosts/victus/configuration.nix

        # Adds the `home-manager.users.<name>` NixOS option that wires
        # home-manager into the system build.
        home-manager.nixosModules.home-manager

        # Adds the `services.flatpak.*` and `home.flatpak.*` options for
        # declarative Flatpak management.
        nix-flatpak.nixosModules.nix-flatpak

        # Inline module for home-manager settings that don't belong in
        # the host config but aren't a whole file on their own.
        {
          # Use the system-level nixpkgs instead of home-manager fetching
          # its own copy — keeps package versions consistent.
          home-manager.useGlobalPkgs = true;

          # Install user packages into the user's profile rather than
          # system-wide, keeping each user's environment self-contained.
          home-manager.useUserPackages = true;

          # Pass `inputs` into home-manager modules as well.
          # Without this, home.nix cannot reference `inputs.noctalia`
          # to import the Noctalia home-manager module.
          home-manager.extraSpecialArgs = { inherit inputs; };

          # Point home-manager at harua's home configuration file.
          home-manager.users.harua = import ./users/harua/home.nix;
        }
      ];
    };
  };
}
