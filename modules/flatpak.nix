# ============================================================
# modules/flatpak.nix
#
# Declarative Flatpak application management via nix-flatpak.
#
# HOW IT LINKS:
#   Imported by → hosts/victus/configuration.nix
#   Powered by  → nix-flatpak flake input (declared in flake.nix)
#                 loaded as nix-flatpak.nixosModules.nix-flatpak
#                 inside flake.nix's modules list
#
# WHAT IS FLATPAK:
#   Flatpak is a distribution-agnostic app packaging format.
#   Apps run inside a sandbox and bundle their own libraries,
#   so they don't depend on system packages. This is useful for
#   apps not yet in nixpkgs, or apps that need specific library
#   versions (e.g. Sober which needs Roblox's exact runtime).
#
# WHAT IS FLATHUB:
#   Flathub (flathub.org) is the main Flatpak app store —
#   think of it as the "App Store" for Linux Flatpaks.
#   We add it as a remote below so packages can be installed from it.
#
# NORMAL vs NIX-FLATPAK:
#   Without nix-flatpak, you'd install Flatpaks manually with:
#     flatpak install flathub org.vinegarhq.Sober
#   With nix-flatpak, packages listed here are installed/removed
#   declaratively on every `nixos-rebuild switch`, matching the
#   same approach as regular nixpkgs packages.
# ============================================================
{ pkgs, ... }:

{
  services.flatpak = {
    # Enable the Flatpak runtime and portal services.
    # This also installs the `flatpak` CLI tool.
    # Under the hood this enables: flatpak.service, xdg-desktop-portal.service,
    # and the per-session Flatpak user daemon.
    enable = true;

    # Flatpak remotes are the repositories Flatpak pulls apps from.
    # Each remote has a name (used in CLI commands like `flatpak install flathub ...`)
    # and a location (the .flatpakrepo URL that describes the repository).
    remotes = [
      {
        name     = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    # Flatpak apps to install declaratively.
    # Format: "reverse.domain.AppId" — the same ID shown by `flatpak list`.
    # nix-flatpak will install these on rebuild and remove any that
    # you delete from this list on the next rebuild.
    packages = [
      # Sober — an unofficial Roblox client for Linux.
      # Roblox doesn't publish a Linux client, and Sober runs the
      # Android version of Roblox through a compatibility layer.
      # It needs to be a Flatpak because it bundles specific Android
      # runtime libraries that aren't in nixpkgs.
      "org.vinegarhq.Sober"
    ];
  };

  # Flatpak apps install their .desktop launcher files and icons into
  # /var/lib/flatpak/exports/share (system) and
  # ~/.local/share/flatpak/exports/share (user).
  #
  # XDG_DATA_DIRS tells desktop environments and app launchers where
  # to look for .desktop files and icon themes. Without these paths,
  # Flatpak app icons won't appear in the Noctalia launcher or any
  # other app menu — the apps are installed but invisible.
  #
  # $HOME is expanded at login time, not here, so the variable
  # reference is intentional (not a Nix interpolation).
  environment.sessionVariables.XDG_DATA_DIRS = [
    "/var/lib/flatpak/exports/share"        # System-installed Flatpaks
    "$HOME/.local/share/flatpak/exports/share" # User-installed Flatpaks
  ];
}
