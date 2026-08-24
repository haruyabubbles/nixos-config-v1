# ============================================================
# users/harua/home.nix
#
# Home Manager configuration for the "harua" user.
#
# WHAT'S IN THIS FILE vs SYSTEM FILES:
#   This file manages things that are personal to the harua user:
#   shell config, dotfiles, user-facing tools, theme, keybindings.
#   System-wide tools (compilers, servers, NVIDIA drivers) live in
#   the host or module configs. If a package provides shell integration
#   (zoxide, fzf, starship) it belongs here via `programs.*` options so
#   home-manager can wire up the shell hooks automatically.
# ============================================================
{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  home.stateVersion = "26.05";

  # ============================================================
  # USER PACKAGES
  # ============================================================
  # NOTE: Most system tools (eza, bat, fd, ripgrep, fzf, jq, curl, wget,
  # unzip, zip, fastfetch, btop) are already in environment.systemPackages
  # via modules/development.nix. We only list packages here that either:
  #   a) are user-specific (not needed system-wide), or
  #   b) need home-manager `programs.*` config (listed in programs.* below).
  home.packages = with pkgs; [
    cowsay
    lolcat
    home-manager

    # Wayland clipboard history picker (fuzzel is already in nnn.nix as the launcher)
    # cliphist and wl-clipboard are in nnn.nix; no need to duplicate.

    # Kanshi config generator (optional TUI)
    # wdisplays is in desktop-apps.nix; kanshi itself is there too.

    # Extra shell utilities not already in development.nix
    pv          # pipe viewer — monitor data flowing through a pipe with a progress bar
    glow        # render Markdown beautifully in the terminal (README files, etc.)
    delta       # syntax-highlighted diff viewer (used by git below)
    yazi        # terminal file manager with image preview (Wayland + kitty protocol)
  ];

  # ============================================================
  # GIT
  # ============================================================
  programs.git = {
    enable = true;
    settings = {
      user.name  = "Haru";
      user.email = "haruya.hinata.bubbles@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;

      # delta: syntax-highlighted, side-by-side diff viewer.
      # Makes `git diff` and `git log -p` output beautiful.
      # Requires: delta package (in home.packages above).
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate    = true;   # n/N to jump between diff sections
        side-by-side = true;  # show old and new side by side
        line-numbers = true;
        syntax-theme = "Catppuccin Mocha";
      };
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };

  # ============================================================
  # KITTY — GPU-accelerated terminal (Catppuccin Mocha theme)
  # ============================================================
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    settings = {
      # Noctalia integration: 0.6 opacity with blur for the frosted-glass look.
      # dynamic_background_opacity lets Noctalia adjust opacity on the fly.
      background_opacity         = "0.6";
      dynamic_background_opacity = "yes";
      background_blur            = 1;
      # Hide kitty's own title bar — niri/noctalia handle window decorations.
      hide_window_decorations    = "yes";

      window_padding_width  = 10;
      confirm_os_window_close = 0;
      enable_audio_bell     = false;
      cursor_shape          = "beam";
      cursor_beam_thickness = "1.5";
      cursor_blink_interval = "0.5";
      scrollback_lines      = 10000;
      copy_on_select        = "clipboard";
      tab_bar_style         = "powerline";
      tab_powerline_style   = "slanted";

      # Performance: use the GPU for rendering. Reduces CPU usage for
      # terminals with lots of output (compilation, logs).
      # sync_to_monitor: false reduces input latency (no frame sync wait).
      sync_to_monitor = "no";

      # Shell integration: kitty injects its own shell integration
      # that enables features like scrollback in editor, clone-in-new-tab.
      shell_integration = "enabled";

      # Catppuccin Mocha palette (fallback — overridden by Noctalia include below).
      background           = "#1e1e2e";
      foreground           = "#cdd6f4";
      selection_background = "#313244";
      selection_foreground = "#cdd6f4";
      cursor               = "#f5e0dc";
      cursor_text_color    = "#1e1e2e";
      url_color            = "#89b4fa";

      color0  = "#45475a";  color8  = "#585b70";
      color1  = "#f38ba8";  color9  = "#f38ba8";
      color2  = "#a6e3a1";  color10 = "#a6e3a1";
      color3  = "#f9e2af";  color11 = "#f9e2af";
      color4  = "#89b4fa";  color12 = "#89b4fa";
      color5  = "#f5c2e7";  color13 = "#f5c2e7";
      color6  = "#94e2d5";  color14 = "#94e2d5";
      color7  = "#bac2de";  color15 = "#a6adc8";
    };

    # Noctalia writes its generated color palette to this cache file every
    # time you change wallpaper or theme. Including it at the end lets
    # Noctalia dynamically update kitty's colors without rebuilding HM.
    extraConfig = ''
      include ~/.cache/noctalia/colors-kitty.conf
    '';
  };

  # ============================================================
  # STARSHIP — Fast, Minimal Prompt
  # ============================================================
  # TERMINAL SLOWNESS FIX:
  #   The main cause of slow prompts is starship waiting too long for
  #   git status information on every directory change. Fixes applied:
  #   1. scan_timeout: abort scanning for modules after 10 ms.
  #   2. command_timeout: abort running any command (git, nix-shell check)
  #      after 500 ms. Default is 500 ms but set explicitly here.
  #   3. git_status.ignore_submodules: skip submodule scanning (huge speedup
  #      in repos with many submodules, e.g. kernel, nixpkgs worktrees).
  #   4. Minimal format string: only show the modules we actually use.
  programs.starship = {
    enable = true;
    settings = {
      # How long (ms) to scan the directory tree for module-detection files
      # (e.g. package.json, Cargo.toml). Lower = faster prompt, may miss
      # deep-nested language contexts. 10 ms is enough for most repos.
      scan_timeout = 10;

      # How long (ms) to wait for any shell command to complete before
      # aborting it. Applies to git status, nix-shell detection, etc.
      command_timeout = 500;

      add_newline = false;

      # Minimal format: only show what we actually care about.
      # Removing $package, $nodejs, $python, $rust etc. eliminates their
      # detection file scans on every prompt (big speedup in mixed repos).
      format = "$directory$git_branch$git_status$nix_shell$character";

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol   = "[❯](bold red)";
      };

      directory = {
        style             = "bold blue";
        truncate_to_repo  = true;
        truncation_length = 3;
      };

      git_branch = {
        symbol = " ";
        style  = "bold purple";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        style  = "bold red";
        format = "([$all_status$ahead_behind]($style) )";
        # Don't recurse into submodules for status.
        # Repos with submodules (nixpkgs, kernel, etc.) can add 200–500 ms
        # to every prompt render. This skips submodule status entirely.
        ignore_submodules = true;
        # Only check changed/staged files, skip untracked file count.
        # Untracked scanning in large repos (node_modules etc.) is slow.
        untracked = "";
      };

      nix_shell = {
        symbol = " ";
        style  = "bold blue";
        format = "[$symbol$name]($style) ";
        # Only show when inside `nix develop` or `nix-shell`, not in
        # every directory that has a shell.nix file (that's the default
        # "impure" detection which scans on every prompt).
        impure_msg    = "";
        pure_msg      = "";
        unknown_msg   = "❄️";
      };
    };
  };

  # ============================================================
  # ZOXIDE — Smart Directory Jumper
  # ============================================================
  # zoxide learns which directories you visit frequently and lets you
  # jump to them with partial names: `z nix` → /etc/nixos, `z proj` → ~/Projects/foo.
  # With --cmd cd, it REPLACES the built-in `cd` command.
  # You still get normal `cd` behaviour, plus zoxide fuzzy-jump on partial paths.
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [
      "--cmd cd" # override `cd` to use zoxide (so `cd foo` does a zoxide jump)
    ];
  };

  # ============================================================
  # FZF — Fuzzy Finder with Shell Integration
  # ============================================================
  # Adds three key bindings to bash:
  #   Ctrl+R  — fuzzy search through bash history (replaces default reverse-i-search)
  #   Ctrl+T  — fuzzy search files in current directory, paste path to command line
  #   Alt+C   — fuzzy search directories, cd into the selected one
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;

    # Use ripgrep as the backend when Ctrl+T is pressed (respects .gitignore,
    # much faster than the default `find` for large repos).
    defaultCommand = "rg --files --hidden --follow --glob '!.git'";
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];

    # Catppuccin Mocha colour scheme for fzf
    colors = {
      "bg"      = "#1e1e2e";
      "bg+"     = "#313244";
      "fg"      = "#cdd6f4";
      "fg+"     = "#cdd6f4";
      "hl"      = "#f38ba8";
      "hl+"     = "#f38ba8";
      "info"    = "#cba6f7";
      "prompt"  = "#cba6f7";
      "pointer" = "#f5e0dc";
      "marker"  = "#f5e0dc";
      "spinner" = "#f5e0dc";
      "header"  = "#f38ba8";
    };
  };

  # ============================================================
  # BAT — Syntax-Highlighted Cat Replacement
  # ============================================================
  # Using the built-in "base16" dark theme which is close to Catppuccin.
  # To use Catppuccin Mocha later, find the current commit at:
  #   https://github.com/catppuccin/bat
  # then add a themes block with the correct rev + hash.
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";          # built-in dark theme, no network fetch required
      style = "numbers,changes,header";
      pager = "less -FR";
    };
  };

  # ============================================================
  # BASH
  # ============================================================
  programs.bash = {
    enable = true;

    # Shell aliases
    shellAliases = {
      # ---- File listing (eza) ------------------------------------
      # --icons requires a Nerd Font (JetBrainsMono NF is already configured).
      # --git adds a column showing git status per file (tiny overhead, very useful).
      # --group-directories-first is set via eza env var below to avoid repeating it.
      ll    = "eza -la --icons --git --group-directories-first";
      ls    = "eza --icons --group-directories-first";
      lt    = "eza -la --icons --sort=modified --group-directories-first";
      tree  = "eza --tree --icons --git-ignore";  # respects .gitignore

      # ---- NixOS shortcuts ---------------------------------------
      # These all point to the flake-based rebuild command.
      # `update` first runs `nix flake update` to pull latest nixpkgs,
      # then rebuilds (same as `rebuild` without the update step).
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#victus";
      update  = "sudo nix flake update /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#victus";
      hm      = "rebuild";
      gc      = "sudo nix-collect-garbage -d && nix-collect-garbage -d";
      # Show which packages changed in the last rebuild
      nixdiff = "nvd diff $(ls -d1v /nix/var/nix/profiles/system-* | tail -2)";

      # ---- Git ---------------------------------------------------
      gs   = "git status";
      gl   = "git log --oneline --graph --decorate";
      gla  = "git log --oneline --graph --decorate --all";
      gd   = "git diff";
      gds  = "git diff --staged";
      gco  = "git checkout";
      gcb  = "git checkout -b";
      gp   = "git push";
      gpl  = "git pull";

      # ---- System tools ------------------------------------------
      cat   = "bat --style=plain";   # bat with no decorations (clean drop-in)
      diff  = "delta";               # use delta for diff (syntax-highlighted)
      ff    = "fastfetch";           # system info
      top   = "btop";                # replace old top with btop

      # ---- Misc --------------------------------------------------
      mkdir  = "mkdir -pv";          # always create parent dirs, print what was created
      cp     = "cp -iv";             # interactive (ask before overwriting) + verbose
      mv     = "mv -iv";             # same for move
      rm     = "rm -iv";             # ask before deleting (safety net)
      grep   = "grep --color=auto";
      rg     = "rg --smart-case";    # ripgrep with case-insensitive-unless-uppercase
    };

    # ---- Bash Init Extra ----------------------------------------
    # This block is appended to ~/.bashrc after home-manager's generated
    # content. Put shell functions, environment variable exports, and
    # one-off settings here (NOT aliases — use shellAliases for those).
    initExtra = ''
      # ---- History -----------------------------------------------
      # HISTSIZE: how many commands to keep in memory during a session.
      # HISTFILESIZE: how many lines to keep in ~/.bash_history on disk.
      # Large values let you search far back with Ctrl+R (fzf history).
      HISTSIZE=50000
      HISTFILESIZE=100000

      # HISTCONTROL:
      #   ignoredups   — don't save a command if it's the same as the previous one.
      #   ignorespace  — don't save commands that start with a space (good for secrets:
      #                  ` MY_SECRET=abc echo foo` is not saved to history).
      #   erasedups    — remove ALL previous occurrences of a command before saving.
      HISTCONTROL=ignoreboth:erasedups

      # Append to history file instead of overwriting it.
      # Without this, each new shell overwrites the history file, losing history
      # from other open terminal windows.
      shopt -s histappend

      # Save history after every command (not just when the shell exits).
      # Combined with histappend, this lets multiple terminal windows share history.
      PROMPT_COMMAND="history -a; ''${PROMPT_COMMAND}"

      # ── Terminal Performance ──────────────────────────────────────
      # Disable XON/XOFF flow control (Ctrl+S / Ctrl+Q). These were used
      # by serial terminals to pause output. In modern terminals they just
      # freeze the terminal accidentally when you hit Ctrl+S to save in vim.
      stty -ixon 2>/dev/null

      # ── Eza environment variable ─────────────────────────────────
      # EZA_COLORS: custom colour map for eza. Syntax: "di=34;1:*.rs=33" etc.
      # We just set group-directories-first here via the env var instead of
      # repeating --group-directories-first in every alias.
      export EZA_COLORS="da=32"   # date column in green

      # ── VOLUME / AUDIO CONTROL ───────────────────────────────────
      # All functions use `pactl` which talks to PipeWire's PulseAudio emulation.
      # PipeWire supports volumes above 100 % (up to ~655 %) via pactl.
      # For clean amplification above 100 % use EasyEffects instead of pactl
      # (EasyEffects applies a Limiter to prevent clipping).
      #
      # Usage examples:
      #   vol          → show current volume percentage
      #   vol 75       → set volume to 75 %
      #   boost        → boost to 200 % (2x amplification)
      #   boost 300    → boost to 300 % (3x — use EasyEffects Limiter!)
      #   volup        → increase by 10 %
      #   volup 5      → increase by 5 %
      #   voldown      → decrease by 10 %
      #   mute         → toggle mute on/off

      # Show or set master volume
      vol() {
        if [ -z "''$1" ]; then
          # No argument: print current volume as a plain percentage
          pactl get-sink-volume @DEFAULT_SINK@ \
            | awk '{print "Volume:", $5}' \
            | head -1
        else
          pactl set-sink-volume @DEFAULT_SINK@ "''${1}%"
          echo "Volume → ''${1}%"
        fi
      }

      # Boost volume above 100 % (3x by default)
      # WARNING: values above ~200 % may distort if the source is already loud.
      # For clean boosting, open EasyEffects and add a Gain plugin with a Limiter.
      boost() {
        local pct="''${1:-300}"
        pactl set-sink-volume @DEFAULT_SINK@ "''${pct}%"
        echo "🔊 Boosted to ''${pct}% — use EasyEffects Limiter above 200% to avoid clipping"
      }

      # Restore volume to 100 % (normal level)
      volnorm() {
        pactl set-sink-volume @DEFAULT_SINK@ 100%
        echo "Volume → 100 % (normal)"
      }

      # Increase volume by N % (default: 10)
      volup() {
        local step="''${1:-10}"
        pactl set-sink-volume @DEFAULT_SINK@ "+''${step}%"
        vol
      }

      # Decrease volume by N % (default: 10)
      voldown() {
        local step="''${1:-10}"
        pactl set-sink-volume @DEFAULT_SINK@ "-''${step}%"
        vol
      }

      # Toggle mute on/off
      mute() {
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        local state
        state=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')
        echo "Mute: ''${state}"
      }

      # Show all audio sinks with their volume and mute state
      audio-status() {
        echo "── Sinks (outputs) ──────────────────────────"
        pactl list sinks short
        echo ""
        echo "── Current default sink ─────────────────────"
        pactl info | grep "Default Sink"
        echo ""
        echo "── Volume ───────────────────────────────────"
        vol
        echo ""
        echo "── Mute ─────────────────────────────────────"
        pactl get-sink-mute @DEFAULT_SINK@
      }

      # ── SYSTEM UTILITIES ─────────────────────────────────────────

      # Quick system info (shorter than fastfetch)
      sysinfo() {
        echo "Hostname:  $(hostname)"
        echo "Uptime:    $(uptime -p)"
        echo "CPU:       $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
        echo "RAM:       $(free -h | awk '/^Mem/{print $3 " used / " $2 " total"}')"
        echo "Swap:      $(free -h | awk '/^Swap/{print $3 " used / " $2 " total"}')"
        echo "Disk (/):  $(df -h / | awk 'NR==2{print $3 " used / " $2 " total (" $5 " full)"}')"
        echo "GPU:       $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'N/A')"
      }

      # Show PATH entries one per line (easier to read than the colon-separated blob)
      path() {
        echo "''$PATH" | tr ':' '\n' | nl
      }

      # Make a directory and cd into it in one step
      mkcd() {
        mkdir -p "''$1" && cd "''$1"
      }

      # Extract any archive format by file extension
      extract() {
        if [ -z "''$1" ]; then
          echo "Usage: extract <archive>"
          return 1
        fi
        case "''$1" in
          *.tar.bz2)  tar xjf "''$1"   ;;
          *.tar.gz)   tar xzf "''$1"   ;;
          *.tar.xz)   tar xJf "''$1"   ;;
          *.tar.zst)  tar --zstd -xf "''$1" ;;
          *.tar)      tar xf "''$1"    ;;
          *.bz2)      bunzip2 "''$1"   ;;
          *.gz)       gunzip "''$1"    ;;
          *.zip)      unzip "''$1"     ;;
          *.7z)       7z x "''$1"      ;;
          *.rar)      unrar x "''$1"   ;;
          *.xz)       xz -d "''$1"     ;;
          *.zst)      zstd -d "''$1"   ;;
          *)          echo "Unknown archive format: ''$1"; return 1 ;;
        esac
      }

      # Quick HTTP server in current directory (for local testing)
      serve() {
        local port="''${1:-8000}"
        echo "Serving http://localhost:''${port} from $(pwd)"
        python3 -m http.server "''${port}"
      }

      # Watch a command every N seconds (like watch but with colour)
      every() {
        local interval="''${1:-2}"
        local cmd="''${@:2}"
        while true; do
          clear
          eval "''${cmd}"
          sleep "''${interval}"
        done
      }

      # ── NixOS SHORTCUTS ───────────────────────────────────────────

      # Edit the NixOS config and immediately rebuild
      nixedit() {
        local file="''${1:-/etc/nixos/hosts/victus/configuration.nix}"
        "''${EDITOR:-nvim}" "''${file}" && rebuild
      }

      # Search nixpkgs for a package by name (requires nix flake)
      nixsearch() {
        nix search nixpkgs "''$@"
      }

      # Open a temporary shell with a package (doesn't install permanently)
      # Usage: try cowsay   →   spawns a shell with cowsay available
      try() {
        nix shell "nixpkgs#''$1" --command bash
      }
    '';
  };

  # ============================================================
  # WL-CLIP-PERSIST — Keep Clipboard Alive After Source App Closes
  # ============================================================
  # On Wayland the clipboard is "owned" by the app that copied the text.
  # If you copy from Firefox then close the tab/window, the clipboard
  # content disappears. wl-clip-persist solves this by running a daemon
  # that watches the clipboard and re-offers the content itself when the
  # source app releases ownership.
  # --clipboard both: persist both PRIMARY (mouse selection) and CLIPBOARD
  # (Ctrl+Shift+C) selections.
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Keep Wayland clipboard alive after source app closes";
      PartOf      = [ "graphical-session.target" ];
      After       = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard both";
      Restart   = "on-failure";
    };
  };

  # ============================================================
  # CLIPBOARD HISTORY DAEMON
  # Watches wl-paste and stores every clipboard entry in cliphist.
  # Trigger the picker with Mod+Ctrl+V in niri (fuzzel dmenu).
  # ============================================================
  systemd.user.services.cliphist = {
    Unit = {
      Description = "Clipboard history daemon";
      PartOf      = [ "graphical-session.target" ];
      After       = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart   = "on-failure";
    };
  };

  # ============================================================
  # KANSHI — Automatic Monitor Profile Daemon
  # ============================================================
  # Kanshi watches for monitor connect/disconnect events and automatically
  # applies a pre-configured display layout. Useful for:
  #   - Laptop-only mode (lid open, no external display)
  #   - Docked mode (external monitor(s) connected)
  #   - Presentation mode (TV/projector connected)
  #
  # Configure by editing ~/.config/kanshi/config
  # Example config file (create manually):
  #   profile laptop {
  #     output eDP-1 enable scale 1.5
  #   }
  #   profile docked {
  #     output eDP-1 disable
  #     output DP-1 enable mode 2560x1440@144 position 0,0
  #   }
  #
  # Find your output names with: wlr-randr
  systemd.user.services.kanshi = {
    Unit = {
      Description = "Kanshi automatic display configuration";
      PartOf      = [ "graphical-session.target" ];
      After       = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kanshi}/bin/kanshi";
      Restart   = "on-failure";
      RestartSec = "3s";
    };
  };

  # ============================================================
  # NOCTALIA — Desktop Shell
  # ============================================================
  programs.noctalia = {
    enable = true;

    settings = {
      theme = {
        mode    = "dark";
        source  = "builtin";
        builtin = "Catppuccin";
      };
    };
  };

  # ============================================================
  # FASTFETCH — System Info Display Config
  # ============================================================
  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
      "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      "logo": {
        "source": "nixos_small",
        "color": {
          "1": "blue",
          "2": "cyan"
        },
        "padding": {
          "top": 0,
          "right": 3
        }
      },
      "display": {
        "separator": " ➔ ",
        "key": {
          "width": 3
        },
        "color": {
          "keys": "blue",
          "output": "white",
          "separator": "blue"
        }
      },
      "modules": [
        { "type": "os",      "key": "" },
        { "type": "uptime",  "key": "" },
        { "type": "wm",      "key": "" },
        { "type": "cpu",     "key": "" },
        { "type": "gpu",     "key": "" },
        { "type": "memory",  "key": "" },
        { "type": "battery", "key": "" }
      ]
    }
  '';

  programs.home-manager.enable = true;
}
