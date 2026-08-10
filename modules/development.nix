# ============================================================
# modules/development.nix
#
# System-wide developer tools, applications, and local services.
#
# HOW IT LINKS:
#   Imported by → hosts/victus/configuration.nix
#   Receives `inputs` via specialArgs from flake.nix so it can
#   pull the lobster package from the lobster flake input.
#   No other module imports this file.
#
# WHY SYSTEM-WIDE vs HOME-MANAGER:
#   Packages here go into the system profile (/run/current-system).
#   They are available to ALL users including root.
#   Per-user packages that only harua needs go in users/harua/home.nix
#   instead (via home.packages). Either works; the split here is
#   "dev tools the whole machine needs" vs "personal user preferences".
# ============================================================
{ config, pkgs, inputs, ... }:

{
  # NixOS normally blocks "unfree" packages (proprietary licenses).
  # Enabling this allows: Discord, Spotify, VSCode, NVIDIA drivers,
  # Obsidian, and others. Without it, those package installs fail
  # with "unfree package" errors.
  nixpkgs.config.allowUnfree = true;

  # `with pkgs;` lets us write package names directly without the
  # `pkgs.` prefix inside the list.
  environment.systemPackages = with pkgs; [

    # ----------------------------------------------------------
    # COMMUNICATION & SOCIAL
    # ----------------------------------------------------------
    spotify          # Music streaming client (unfree)
    telegram-desktop # Telegram messenger desktop client
    vesktop          # Voice/text chat for gaming and communities (unfree)

    # ----------------------------------------------------------
    # EDITORS & VERSION CONTROL
    # ----------------------------------------------------------
    vscode           # Visual Studio Code — GUI code editor (unfree)
    neovim           # Vim-based terminal editor, highly extensible
    git              # Distributed version control system
    git-lfs          # Git Large File Storage — stores big files (models, assets) outside the repo

    # ----------------------------------------------------------
    # PROGRAMMING LANGUAGES & RUNTIMES
    # ----------------------------------------------------------
    python3          # Python 3 interpreter — used by many tools and scripts
    nodejs           # JavaScript/TypeScript runtime — needed for web dev and some CLI tools
    openjdk          # Open-source Java Development Kit — Java/Kotlin/Scala

    # ----------------------------------------------------------
    # BUILD TOOLS
    # ----------------------------------------------------------
    gcc              # GNU C/C++ compiler — required to build most native Linux software
    gnumake          # Make build system — reads Makefiles to compile projects
    alacritty

    # ----------------------------------------------------------
    # CREATIVE / MEDIA PRODUCTION
    # ----------------------------------------------------------
    gimp             # GNU Image Manipulation Program — raster image editor
    krita            # Digital painting / illustration app
    obs-studio       # Screen recording and live streaming software

    # ----------------------------------------------------------
    # MEDIA PLAYBACK
    # ----------------------------------------------------------
    vlc              # Versatile media player — plays almost any format
    mpv              # Lightweight, scriptable media player (used by ani-cli)
    ani-cli          # CLI tool to stream anime from the terminal via mpv

    # ----------------------------------------------------------
    # GAMING
    # ----------------------------------------------------------
    heroic           # Open-source Epic Games / GOG launcher for Linux
    lutris           # Game manager that handles Wine, Proton, emulators, etc.
    mangohud         # In-game overlay showing FPS, CPU/GPU usage, temps
    protonup-qt      # GUI tool to install/update Proton-GE (custom Proton builds)
    gamescope        # Wayland-based micro-compositor for running games at custom resolution/framerate

    # ----------------------------------------------------------
    # TERMINAL UTILITIES (modern replacements for classic tools)
    # ----------------------------------------------------------
    tmux             # Terminal multiplexer — split terminal into panes, keep sessions alive over SSH
    zoxide           # Smarter `cd` — learns your frequently visited directories; `z foo` jumps to them
    ripgrep          # `rg` — extremely fast grep alternative, respects .gitignore
    fd               # Faster and friendlier `find` replacement
    fzf              # Fuzzy finder — pipe any list into it for interactive filtering
    bat              # `cat` with syntax highlighting, line numbers, and Git integration
    eza              # Modern `ls` replacement with colours, icons, and tree view

    # ----------------------------------------------------------
    # SYSTEM MONITORING
    # ----------------------------------------------------------
    htop             # Interactive process viewer (classic, widely available)
    btop             # Modern resource monitor with graphs for CPU/RAM/disk/net
    nvtopPackages.full # GPU process monitor — shows NVIDIA + Intel GPU usage in one view

    # ----------------------------------------------------------
    # HARDWARE INSPECTION
    # ----------------------------------------------------------
    pciutils         # `lspci` — list PCI devices (GPU, WiFi, etc.)
    usbutils         # `lsusb` — list USB devices

    # ----------------------------------------------------------
    # SERIAL / EMBEDDED / NETWORKING
    # ----------------------------------------------------------
    screen           # Terminal multiplexer also used for serial console access (`screen /dev/ttyUSB0`)
    minicom          # Serial terminal emulator — useful for UART debugging on microcontrollers
    gh               # GitHub CLI — manage PRs, issues, repos from the terminal
    nmap             # Network scanner — discover hosts, open ports, and services

    # ----------------------------------------------------------
    # FILE & DOWNLOAD UTILITIES
    # ----------------------------------------------------------
    curl             # Transfer data with URLs — the standard HTTP/API testing tool
    wget             # Download files from the web (recursive downloads, mirrors)
    unzip            # Extract .zip archives
    zip              # Create .zip archives
    p7zip            # 7-Zip — handles .7z, .rar, and many other archive formats
    tree             # Print directory structure as a tree
    jq               # Command-line JSON processor — slice, filter, and format JSON
    unzip            # (duplicate — safe to remove one)

    # ----------------------------------------------------------
    # PRODUCTIVITY & OFFICE
    # ----------------------------------------------------------
    libreoffice                    # Full office suite (Writer, Calc, Impress, etc.)
    python3Packages.jupyterlab     # JupyterLab — browser-based notebook for Python/data science
    fastfetch                      # System info fetcher (like neofetch, but faster)
    scrcpy                         # Mirror and control Android device screen over USB/WiFi
    obsidian                       # Markdown-based knowledge base / note-taking app (unfree)

    # ----------------------------------------------------------
    # WINDOWS COMPATIBILITY (Wine)
    # ----------------------------------------------------------
    # wineWowPackages.stable runs both 32-bit and 64-bit Windows apps.
    # "WoW" = Windows on Windows = the 32-bit subsystem inside 64-bit Wine.
    wineWowPackages.stable
    winetricks       # Script that installs Windows runtimes/libraries into Wine prefixes
                     # (Visual C++ redistributables, DirectX, .NET, etc.)
    bottles          # GUI frontend for managing Wine prefixes — easier than raw Wine commands
    dxvk             # DirectX 9/10/11 → Vulkan translation layer — makes Windows games run faster in Wine

    # ----------------------------------------------------------
    # VULKAN / GRAPHICS DEBUGGING
    # ----------------------------------------------------------
    vulkan-tools     # `vulkaninfo` — verify Vulkan is working; `vkcube` for a spinning test cube
    vulkan-loader    # Runtime Vulkan ICD loader — apps link against this to find the GPU driver
    mesa-demos       # `glxinfo`, `glxgears` — OpenGL debugging and info tools

    # ----------------------------------------------------------
    # SYSTEM DEBUGGING
    # ----------------------------------------------------------
    rofi             # Application launcher / window switcher (X11 and XWayland)
    strace           # System call tracer — record every syscall a process makes; invaluable for debugging

    # ----------------------------------------------------------
    # DATABASES & TUNNELS (for local dev)
    # ----------------------------------------------------------
    postgresql_16    # PostgreSQL CLI tools (psql, pg_dump, etc.)
                     # The actual server daemon is configured below via services.postgresql
    ngrok            # Expose localhost ports to the internet via a secure tunnel (unfree)
    cloudflared      # Cloudflare Tunnel client — alternative to ngrok, no port forwarding needed

    # ----------------------------------------------------------
    # PRIVACY / VPN
    # ----------------------------------------------------------
    proton-vpn-cli   # ProtonVPN command-line client
    tor              # Tor anonymity network CLI and libraries
    torsocks         # Wrapper to route any app's TCP through Tor (`torsocks curl ...`)

    # ----------------------------------------------------------
    # EXTERNAL FLAKE PACKAGES
    # lobster is not in nixpkgs — it comes from the lobster flake
    # input declared in flake.nix. We reference it via `inputs`
    # which is available here because flake.nix passes it through
    # specialArgs = { inherit inputs; }.
    # ${pkgs.system} evaluates to "x86_64-linux" on this machine.
    # ----------------------------------------------------------
    inputs.lobster.packages.${pkgs.system}.lobster  # CLI anime/movie streaming tool

    # Claude Code — Anthropic's AI coding assistant CLI (unfree)
    claude-code

    # n8n package (binary). The n8n SERVICE is configured separately
    # below via services.n8n. Having the package here gives you the
    # `n8n` CLI command even when the service is stopped.
    n8n
  ];

  # ============================================================
  # N8N — Workflow Automation
  # n8n is a self-hosted workflow automation tool (like Zapier/Make).
  # It runs as a systemd service on port 5678.
  #
  # HOW IT LINKS TO POSTGRESQL:
  #   services.n8n sets DB_TYPE=postgresdb, pointing n8n at the
  #   local PostgreSQL server (services.postgresql below).
  #   n8n will NOT start successfully until the database and user
  #   exist — see the one-time setup note under services.postgresql.
  # ============================================================
  services.n8n = {
    enable = true;

    # Opens port 5678 in the firewall so n8n is reachable from
    # the local network (or Tailscale). Remove if you only want
    # localhost access.
    openFirewall = true;

    environment = {
      N8N_PORT = "5678";                         # Which port n8n listens on

      # The public URL n8n uses to build webhook URLs.
      # Change this to your Tailscale IP or domain if you access
      # n8n from other devices.
      WEBHOOK_URL = "http://localhost:5678/";

      # Switch n8n's storage from the default SQLite file to PostgreSQL.
      # PostgreSQL handles concurrent workflows and larger datasets better.
      DB_TYPE            = "postgresdb";
      DB_POSTGRESDB_HOST = "localhost";          # Local postgres socket/host
      DB_POSTGRESDB_DATABASE = "n8n";            # Database name (must exist — see below)
      DB_POSTGRESDB_USER     = "n8n";            # Postgres user (must exist — see below)
      # DB_POSTGRESDB_PASSWORD = "";             # No password because auth = trust below
    };
  };

  # ============================================================
  # POSTGRESQL — Relational Database Server
  # Used as the backend for n8n (above).
  # The `postgresql_16` package is version 16 (current stable LTS).
  #
  # AFTER FIRST REBUILD — one-time manual setup required:
  #   Nix installs and starts the PostgreSQL server but does NOT
  #   create roles or databases. Run these commands once:
  #
  #     sudo -u postgres createuser n8n
  #     sudo -u postgres createdb -O n8n n8n
  #
  #   After that, n8n can connect and create its own schema.
  # ============================================================
  services.postgresql = {
    enable = true;

    # Pin to PostgreSQL 16 explicitly so the version doesn't change
    # unexpectedly on a nixpkgs update (data migration between major
    # versions requires manual steps with `pg_upgrade`).
    package = pkgs.postgresql_16;

    # Allow TCP connections (not just Unix socket).
    # Needed by apps that connect via host = "localhost" / 127.0.0.1.
    enableTCPIP = true;

    # pg_hba.conf controls who can connect and how they authenticate.
    # mkOverride 10 means this value takes priority over any default
    # set elsewhere in the NixOS module system (lower number = higher priority).
    #
    # "trust" = no password required.
    # This is fine for a local dev machine where PostgreSQL is not
    # exposed to the internet. If you open the machine to a network,
    # switch to "scram-sha-256" and set passwords.
    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE  USER  ADDRESS       METHOD
      local   all       all                 trust    # Unix socket — any local user
      host    all       all   127.0.0.1/32  trust    # IPv4 localhost
      host    all       all   ::1/128       trust    # IPv6 localhost
    '';
  };

  # ============================================================
  # TOR — Anonymous Network Client
  # Runs a local SOCKS5 proxy at 127.0.0.1:9050.
  # Use `torsocks <command>` to route any TCP app through Tor,
  # or configure apps to use SOCKS proxy at localhost:9050.
  #
  # Example:
  #   torsocks curl https://check.torproject.org/api/ip
  # ============================================================
  services.tor = {
    enable = true;

    # client.enable = true starts the SOCKS proxy.
    # Without this, Tor runs as a relay/hidden-service node only,
    # not as a client you can route traffic through.
    client.enable = true;
  };
}
