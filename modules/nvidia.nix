{ config, pkgs, ... }:

{

  # Enable the GNOME Keyring dark service so libsecret can store your login tokens
  services.gnome.gnome-keyring.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;

    powerManagement.enable = false;

  # note for myself RTX4050 should be open=true because its support open kernal module
    open = false;

    nvidiaSettings = true;

    prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}