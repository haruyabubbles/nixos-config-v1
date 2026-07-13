{ config, pkgs, ... }:

{
font.packages = with pkgs; [
  
  corefonts

];
}