# ============================================================
# modules/desktop/nnn.nix
#
# The NNN stack: NixOS + Niri + Noctalia
#
# Niri   — scrollable-tiling Wayland compositor (window manager)
# Noctalia — integrated desktop shell: bar, launcher, notifications,
#            lock screen, wallpaper picker, control center, etc.
# greetd  — lightweight display/login manager for Wayland
#
# This module replaces the Cinnamon + LightDM setup that was here
# before. Everything Wayland-native, no X11 desktop session.
# ============================================================
{ config, pkgs, inputs, ... }:

{
  # Pull in Noctalia's NixOS module, which provides the
  # `programs.noctalia` option used below.
  # The module is sourced from the noctalia flake input in flake.nix.
  imports = [
    inputs.noctalia.nixosModules.default
  ];

  # ============================================================
  # NIRI — Window Manager
  # ============================================================

  # Enabling niri:
  #   - Installs the niri package
  #   - Registers a Wayland desktop session entry (used by greetd)
  #   - Sets up PAM rules so niri can lock the screen
  #   - Enables polkit (needed for privilege dialogs in Wayland)
  programs.niri.enable = true;

  # ============================================================
  # NOCTALIA — Desktop Shell
  # ============================================================

  programs.noctalia = {
    enable = true;

    # recommendedServices.enable = true automatically enables a
    # curated set of system services that Noctalia's widgets depend on:
    #   - power-profiles-daemon  (power profile switcher in control center)
    #   - upower                 (battery info)
    #   - bluetooth / bluez      (Bluetooth control panel)
    #   - and other small helpers
    recommendedServices.enable = true;

    # Start Noctalia as a proper systemd user service instead of using
    # niri's spawn-at-startup. Benefits:
    #   - Noctalia is pre-warmed before you interact with it → launcher opens instantly
    #   - Clean lifecycle: systemd restarts it on crash automatically
    #   - No double-start race condition
    # IMPORTANT: with this enabled, remove `spawn-at-startup "noctalia"`
    # from ~/.config/niri/config.kdl (already done).
    systemd.enable = true;
  };

  # ============================================================
  # BINARY CACHE
  # Noctalia is not in nixpkgs, so without a cache every rebuild
  # would compile it from source (slow — can take 20+ minutes).
  # These settings tell Nix to fetch pre-built binaries from
  # Noctalia's Cachix cache instead.
  #
  # The public key below lets Nix verify the binaries are genuine
  # and haven't been tampered with.
  # ============================================================
  nix.settings = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  # ============================================================
  # GREETD — Display / Login Manager
  # Replaces LightDM. greetd is a minimal Wayland-friendly login
  # manager; tuigreet is its terminal-based greeter UI.
  # ============================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # ============================================================
  # REQUIRED HARDWARE SERVICES
  # ============================================================

  hardware.bluetooth.enable = true;
  services.upower.enable = true;
  security.polkit.enable = true;

  # ============================================================
  # XDG DESKTOP PORTAL
  # Portals let sandboxed/Wayland apps request system services
  # (file picker, screen share, notifications) through D-Bus.
  #
  #   xdg-desktop-portal-gtk  — file dialogs, app chooser
  #   xdg-desktop-portal-gnome — screen share (pipewire), better
  #                               file picker for GTK4 apps
  # ============================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
  };

  # ============================================================
  # WAYLAND + NVIDIA ENVIRONMENT VARIABLES
  # These are set for every user session on the machine.
  # ============================================================
  environment.sessionVariables = {
    # Tell Electron/Chrome apps to run in Wayland mode natively
    NIXOS_OZONE_WL = "1";

    # Use the nvidia-drm GBM backend for Wayland framebuffer allocation
    GBM_BACKEND = "nvidia-drm";

    # Force NVIDIA's GLX implementation
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Use NVIDIA for VAAPI hardware video decode
    LIBVA_DRIVER_NAME = "nvidia";

    # Hint to apps that this is a Wayland session
    XDG_SESSION_TYPE = "wayland";

    # Force Qt apps to use the native Wayland backend (no XWayland)
    QT_QPA_PLATFORM = "wayland";

    # Qt 5 apps: use Wayland platform plugin and GTK style
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };

  # ============================================================
  # SYSTEM PACKAGES
  # ============================================================
  environment.systemPackages = with pkgs; [
    # Terminals
    foot        # lightweight Wayland-native terminal (fallback)
    kitty       # GPU-accelerated terminal with Catppuccin theme support
    polkit_gnome

    # Clipboard
    wl-clipboard  # wl-copy / wl-paste — Wayland clipboard CLI
    cliphist      # clipboard history daemon (stores wl-paste output)

    # Screenshot tools
    grim          # Wayland screenshot capture
    slurp         # Interactive region/window selector for grim
    swappy        # Screenshot annotation and editing tool

    # Launcher (used for clipboard history picker)
    fuzzel        # Fast Wayland-native dmenu-compatible launcher

    # Media and brightness keys (used in niri keybinds)
    playerctl     # MPRIS media player control (play/pause/next/prev)
    brightnessctl # Laptop backlight control

    # File manager
    nemo          # Cinnamon file manager (already familiar from previous setup)

    # Utilities
    fastfetch     # System info display (modern neofetch replacement)
    hyprpicker    # Color picker — copies hex to clipboard
    wl-color-picker # GUI color picker for Wayland
  ];
}
