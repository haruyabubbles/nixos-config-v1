{ config, pkgs, ... }:

{
  # ============================================================
  # FONTS
  # A curated set covering: programming, UI, emoji, and legacy compat.
  # ============================================================
  fonts.packages = with pkgs; [
    # JetBrains Mono Nerd Font — primary coding font.
    # Nerd Fonts patch adds icon glyphs used by eza, starship, etc.
    nerd-fonts.jetbrains-mono

    # Fira Code Nerd Font — ligature-heavy alternative programming font
    nerd-fonts.fira-code

    # Noto family — covers almost every Unicode script (no tofu boxes)
    noto-fonts
    noto-fonts-cjk-sans    # Chinese / Japanese / Korean
    noto-fonts-color-emoji # Color emoji (renamed in nixpkgs 25.05+)

    # Liberation fonts — metric-compatible replacements for Arial,
    # Times New Roman, Courier New (needed by Office files, PDFs, etc.)
    liberation_ttf

    # Inter — clean sans-serif for UI elements
    inter
  ];

  fonts.fontconfig = {
    enable = true;
    antialias = true;

    hinting = {
      enable = true;
      style  = "slight";
    };

    subpixel = {
      lcdfilter = "default";
      rgba      = "rgb";
    };

    defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font Mono" "Noto Sans Mono" ];
      sansSerif = [ "Inter"            "Noto Sans"   ];
      serif     = [ "Liberation Serif" "Noto Serif"  ];
      emoji     = [ "Noto Color Emoji"               ];
    };
  };
}
