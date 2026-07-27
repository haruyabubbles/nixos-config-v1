  { config, pkgs, inputs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    spotify
    telegram-desktop
    discord

    vscode
    neovim
    git
    git-lfs

    python3
    nodejs
    openjdk

    gcc
    gnumake

    gimp
    krita
    obs-studio

    vlc
    mpv
    ani-cli

    heroic
    lutris
    mangohud
    protonup-qt
    gamescope

    tmux
    zoxide
    ripgrep
    fd
    fzf
    bat
    eza

    htop
    btop
    nvtopPackages.full

    pciutils
    usbutils

    screen
    minicom
    gh
    nmap

    curl
    wget
    unzip
    zip

    libreoffice
    python3Packages.jupyterlab
    p7zip
    tree
    jq
    fastfetch
    scrcpy

    # game packages
    vulkan-tools
    vulkan-loader

    #wineWowPackages.stable
    dxvk

    mesa-demos

    #sober

    # other Program
    obsidian
    rofi
    strace

    n8n

    # Replace system type (e.g., x86_64-linux)
    inputs.lobster.packages.${pkgs.system}.lobster 


  ];

  services.n8n = {
    enable = true;
    openFirewall = true; # Opens port 5678 by default
    environment = {
      N8N_PORT = "5678";
      WEBHOOK_URL = "http://localhost:5678/";
    };
  };

}