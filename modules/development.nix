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

let
  # ------------------------------------------------------------
  # Spotify — forced onto the PulseAudio backend (via PipeWire's
  # pulse emulation) instead of its native PipeWire audio API.
  #
  # WHY: recent Spotify Linux client builds (1.2.8x/1.2.9x) ship a
  # native PipeWire audio backend that's buggy: the first track
  # plays fine, but the next track (via Next, or auto-advance, or
  # even Pause/Play) silently fails ("Sorry, can't play this
  # right now") while the UI progress bar keeps animating on its
  # own until it reaches the track's full duration, and Spotify
  # Connect still reports this device as "Playing" to other
  # clients (e.g. your phone) because the app never told the
  # server playback died. A full restart "fixes" it for exactly
  # one song, then it recurs. This is a widely reported upstream
  # bug, not a PipeWire/WirePlumber tuning issue on this machine.
  #
  # FIX: pass --audio-api=pulseaudio to fall back to the old,
  # stable pulse/libpulse path (PipeWire still handles the audio
  # underneath via the pulse emulation socket — see audio.nix).
  # wrapProgram layers on top of nixpkgs' spotify FHS wrapper, so
  # both the CLI and the app-launcher .desktop entry (which just
  # execs `spotify %U`) pick it up.
  #
  # UPDATE (2026-09-06): --audio-api=pulseaudio alone did NOT fix the
  # "Can't play the current song" freeze on this machine (confirmed live
  # via /proc/<pid>/cmdline that the flag really was reaching the real
  # .spotify-wrapped process — it just wasn't enough). Root-caused via
  # nixpkgs' own snapcraft revision history: the bug is a genuine upstream
  # regression Spotify introduced starting at client version 1.2.86.502
  # (snap revision 94) — "the app's native audio backend stops setting
  # the correct output sample rate," per multiple user reports. nixpkgs
  # was tracking 1.2.90.451 (revision 96), squarely inside the broken
  # range.
  #
  # FIX (layered on top of the pulseaudio flag above): pin Spotify back
  # to snap revision 93 = version 1.2.84.475.ga1a748ff, the newest build
  # still before the regression. Confirmed by downloading and inspecting
  # meta/snap.yaml directly from snapcraft for revisions 90/93/94/95:
  #   rev 93 → 1.2.84.475.ga1a748ff  (last known-good)
  #   rev 94 → 1.2.86.502.g8cd7fb22  (regression introduced — this is the
  #                                   exact version already named in the
  #                                   pulse.rules bug-fix comments over in
  #                                   audio.nix)
  #   rev 95 → 1.2.89.539.gfb3c63a3  (still broken)
  # nixpkgs unstable currently tracks 1.2.95.453 — newer, but still past
  # the regression, so bumping the flake would NOT have fixed this.
  #
  # TRADE-OFF: this is an old, unsupported build. Spotify has been known
  # to server-side block sufficiently old desktop clients from logging in
  # at some point in the future — if that ever happens here, this pin
  # will need to move forward again (past whichever version Spotify
  # eventually fixes the regression in, if they do).
  spotifyPinned = pkgs.spotify.overrideAttrs (old: rec {
    version = "1.2.84.475.ga1a748ff";
    rev = "93";
    src = pkgs.fetchurl {
      name = "spotify-${version}-${rev}.snap";
      url = "https://api.snapcraft.io/api/v1/snaps/download/pOBIoZ2LrCB3rDohMxoYGnbN14EHOgD7_${rev}.snap";
      hash = "sha256-KY2tjbIIlGiHj1maAM7/lk1+3joniYqqJ2NiOYb4bEs=";
    };
  });

  spotify-fixed = pkgs.symlinkJoin {
    name = "spotify-fixed-${spotifyPinned.version}";
    paths = [ spotifyPinned ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/spotify \
        --add-flags "--audio-api=pulseaudio"
    '';
    meta = spotifyPinned.meta // { mainProgram = "spotify"; };
  };
in

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
    spotify-fixed    # Music streaming client, wrapped to use --audio-api=pulseaudio
                     # (unfree; fixes "plays one song then dies" bug — see `let` above)
    telegram-desktop # Telegram messenger desktop client
    vesktop          # Voice/text chat for gaming and communities (unfree)
    discord

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

    # pm2 — process manager for Node apps. Keeps your app running in the
    # background, auto-restarts on crash, and manages logs, instead of
    # running it in a foreground `npm start`/`npm run dev` terminal tab.
    # Common usage:
    #   pm2 start app.js --name myapp   # or: pm2 start npm -- start
    #   pm2 list                        # show running processes
    #   pm2 logs myapp                  # tail logs
    #   pm2 restart myapp / pm2 stop myapp / pm2 delete myapp
    #   pm2 save && pm2 startup         # persist process list across reboots
    pm2

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
    freecad          # Parametric 3D CAD — cad project (housing, chassis, internals)
    blender          # 3D renders of the finished model (optional, large)

    # ----------------------------------------------------------
    # MEDIA PLAYBACK
    # ----------------------------------------------------------
    vlc              # Versatile media player — plays almost any format
    mpv              # Lightweight, scriptable media player (used by ani-cli)
    ani-cli          # CLI tool to stream anime from the terminal via mpv
    pear-desktop     # YT Music Electron client (nixpkgs renamed youtube-music
                     # -> pear-desktop) — has a built-in Discord Rich
                     # Presence plugin (Settings > Plugins > Discord), shows
                     # "Listening to ___" like Spotify. PreMiD has no Linux
                     # build at all, so this is the real alternative.
    mprisence        # Discord Rich Presence daemon built on Linux MPRIS.
                     # Its browser bridge (mprisence web install) covers
                     # plain youtube.com, not just YT Music — PreMiD-style
                     # "Watching ___" for any browser tab.

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
    wireguard-tools  # wg-quick etc. — needed to use ProtonVPN's downloadable WireGuard configs
                     # (free plan's CLI has no location switching; manual configs are the workaround)
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

    # ----------------------------------------------------------
    # NETWORK DIAGNOSTICS
    # ----------------------------------------------------------
    speedtest-cli    # `speedtest-cli` — internet speed test (Cloudflare/speedtest.net backends)
    iw               # `iw dev wlan0 scan` / `iw dev wlan0 link` — WiFi scan & signal in dBm
    wirelesstools    # `iwconfig` — legacy WiFi status/signal tool, still handy for `watch`
    nmap             # `nmap -sn 192.168.1.0/24` — LAN device discovery
    mtr              # `mtr example.com` — live traceroute + ping combined
    bmon             # live bandwidth monitor per interface
    wavemon          # `wavemon` — live ncurses WiFi signal dashboard (dBm graph),
                     # for walking around to check range/coverage
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
  # POSTGRESQL — local dev database server (2026-09-10)
  # ============================================================
  # Enabled for PgAdminHaru (a local Postgres admin UI project) and any
  # future local-dev tools that need a real Postgres instance — kept
  # separate from the n8n block above, which is still disabled and
  # wants its own TCP/trust setup for a non-interactive `n8n` role.
  #
  # AUTH: no override here, so NixOS's module default authentication
  # applies — `local all all peer` for the Unix socket. Peer auth maps
  # your OS user to a same-named Postgres role with no password, which
  # is exactly what ensureUsers.harua below creates. Apps connect via
  # the socket at /run/postgresql (PGHOST=/run/postgresql, PGUSER=harua,
  # no PGPASSWORD) rather than over TCP — nothing is listening on the
  # network by default (enableTCPIP is false), so there's nothing to
  # firewall or expose accidentally.
  #
  # ensureUsers/ensureClauses only apply the FIRST time the role doesn't
  # already exist — safe to leave declared permanently, re-running never
  # touches an existing role's password or privileges.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureUsers = [
      {
        name = "harua";
        ensureClauses.login = true;
        ensureClauses.superuser = true;
      }
    ];
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
