{ config, pkgs, ... }:

{
  # IMPORTANT
  # Must match your installed release
  home.stateVersion = "26.05";

  # User packages managed by Home Manager
  home.packages = with pkgs; [

    # Terminal tools
    cowsay
    lolcat


    home-manager
  ];

  # Git managed by Home Manager
  programs.git = {
    enable = true;

    settings = {
      user.name = "Haru";
      user.email = "haruya.hinata.bubbles@gmail.com";
    };
  };

  # Bash managed by Home Manager
  programs.bash = {
    enable = true;

    shellAliases = {
      ll = "eza -la";
      update = "sudo nixos-rebuild switch";
      gs = "git status";
    };
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
