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
    # gamescope is installed via programs.gamescope.enable = true in configuration.nix.

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
    btop             # Modern resource monitor with graphs for CPU/RAM/disk/net

    # ----------------------------------------------------------
    # HARDWARE INSPECTION
    # ----------------------------------------------------------
    # pciutils (lspci) and usbutils (lsusb) are declared in
    # hosts/victus/configuration.nix under SYSTEM PACKAGES.
    # They are referenced by the gpu-switch.nix wrapper scripts
    # and need to be available system-wide, not just per-user.

    # ----------------------------------------------------------
    # SERIAL / EMBEDDED / NETWORKING
    # ----------------------------------------------------------
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
    # p7zip is declared in hosts/victus/configuration.nix under SYSTEM PACKAGES.
    jq               # Command-line JSON processor — slice, filter, and format JSON

    # ----------------------------------------------------------
    # PRODUCTIVITY & OFFICE
    # ----------------------------------------------------------
    libreoffice                    # Full office suite (Writer, Calc, Impress, etc.)
    #python3Packages.jupyterlab   # JupyterLab — browser-based notebook for Python/data science
    fastfetch                      # System info fetcher (like neofetch, but faster)
    scrcpy                         # Mirror and control Android device screen over USB/WiFi
    obsidian                        # Markdown-based knowledge base / note-taking app (unfree)

    # ----------------------------------------------------------
    # WINDOWS COMPATIBILITY (Wine)
    # ----------------------------------------------------------
    # wineWow64Packages.stable runs both 32-bit and 64-bit Windows apps.
    # "WoW64" = Windows on Windows 64 = the 32-bit compatibility layer inside
    # a 64-bit Wine installation (Wine-on-Wine, essentially).
    # NOTE: wineWowPackages was renamed to wineWow64Packages in nixpkgs 26.05.
    # Using the old name triggers an evaluation warning on every rebuild.
    #wineWow64Packages.stable
    #winetricks       # Script that installs Windows runtimes/libraries into Wine prefixes
                     # (Visual C++ redistributables, DirectX, .NET, etc.)
    #bottles          # GUI frontend for managing Wine prefixes — easier than raw Wine commands
    #dxvk            # DirectX → Vulkan layer — uncomment when Wine is enabled above

    # ----------------------------------------------------------
    # VULKAN / GRAPHICS DEBUGGING
    # ----------------------------------------------------------
    vulkan-tools     # `vulkaninfo` — verify Vulkan is working; `vkcube` for a spinning test cube
    vulkan-loader    # Runtime Vulkan ICD loader — apps link against this to find the GPU driver
    # mesa-demos is declared in modules/gpu-switch.nix (used by the gpu-info script).

    # ----------------------------------------------------------
    # SYSTEM DEBUGGING
    # ----------------------------------------------------------
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
    # pkgs.system was deprecated in nixpkgs 25.11; use stdenv.hostPlatform.system.
    # Both evaluate to "x86_64-linux" on this machine but the new form
    # avoids the evaluation warning printed on every rebuild.
    inputs.lobster.packages.${pkgs.stdenv.hostPlatform.system}.lobster  # CLI anime/movie streaming tool

    # Claude Code — Anthropic's AI coding assistant CLI (unfree)
    claude-code

    # n8n — workflow automation tool. Uncomment along with services.n8n
    # and services.postgresql below when you want to use it.
    #n8n
  ];

  # ============================================================
  # N8N + POSTGRESQL — Workflow Automation (disabled)
  # Uncomment the block below (and the n8n package above) to re-enable.
  # One-time manual setup after first enable:
  #   sudo -u postgres createuser n8n
  #   sudo -u postgres createdb -O n8n n8n
  # ============================================================
  # services.n8n = {
  #   enable = true;
  #   openFirewall = true;
  #   environment = {
  #     N8N_PORT = "5678";
  #     WEBHOOK_URL = "http://localhost:5678/";
  #     DB_TYPE            = "postgresdb";
  #     DB_POSTGRESDB_HOST = "localhost";
  #     DB_POSTGRESDB_DATABASE = "n8n";
  #     DB_POSTGRESDB_USER     = "n8n";
  #   };
  # };
  # services.postgresql = {
  #   enable = true;
  #   package = pkgs.postgresql_16;
  #   enableTCPIP = true;
  #   authentication = pkgs.lib.mkOverride 10 ''
  #     local   all       all                 trust
  #     host    all       all   127.0.0.1/32  trust
  #     host    all       all   ::1/128       trust
  #   '';
  # };

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
