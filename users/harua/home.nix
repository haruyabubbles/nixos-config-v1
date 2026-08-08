# ============================================================
# users/harua/home.nix
#
# Home Manager configuration for the "harua" user.
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
  home.packages = with pkgs; [
    cowsay
    lolcat
    home-manager

    # Shell utilities
    eza       # modern ls replacement (used by ll alias below)
    bat       # syntax-highlighted cat replacement
    fd        # fast find replacement
    ripgrep   # fast grep replacement
    fzf       # fuzzy finder
    jq        # JSON query tool
    unzip
    zip
    wget
    curl

    # System info
    fastfetch  # run `ff` in terminal for system info
    btop       # beautiful resource monitor
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
      background_opacity    = "0.95";
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

      # Catppuccin Mocha palette
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
  };

  # ============================================================
  # STARSHIP — minimal, fast prompt
  # ============================================================
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$character";

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol   = "[❯](bold red)";
      };

      directory = {
        style            = "bold blue";
        truncate_to_repo = true;
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
      };

      nix_shell = {
        symbol = " ";
        style  = "bold blue";
        format = "[$symbol$name]($style) ";
      };
    };
  };

  # ============================================================
  # BASH
  # ============================================================
  programs.bash = {
    enable = true;

    shellAliases = {
      # File listing (eza with icons + git status)
      ll   = "eza -la --icons --git";
      ls   = "eza --icons";
      lt   = "eza -la --icons --sort=modified";
      tree = "eza --tree --icons";

      # NixOS rebuild shortcuts
      update  = "sudo nixos-rebuild switch --flake /etc/nixos#victus";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#victus";
      hm      = "home-manager switch --flake /etc/nixos#harua";
      gc      = "sudo nix-collect-garbage -d";

      # Git
      gs = "git status";
      gl = "git log --oneline --graph --decorate";
      gd = "git diff";

      # Utilities
      cat = "bat --style=plain";
      ff  = "fastfetch";
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

  programs.home-manager.enable = true;
}
