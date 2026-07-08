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
  ];