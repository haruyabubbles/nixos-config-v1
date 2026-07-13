#{ ... }:

#{
# Ensure Flatpak paths are exported to your desktop environment
#services.flatpak.enable = true;

#}

{ config, pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}