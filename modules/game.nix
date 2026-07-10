{ config, pkgs, ... }:

{
  # Enable Flatpak and manage apps declaratively
  services.flatpak = {
    enable = true;
    
    # Automatically configures the Flathub store
    updateRemotes = true; 
    
    # Installs Sober automatically on rebuild
    packages = [
      "flathub:org.vinegarhq.Sober"
    ];
  };
}