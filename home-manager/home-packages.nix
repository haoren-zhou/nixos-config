{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    bibata-cursors

    wget

    github-desktop
    google-chrome
    discord
    gcc
    xclip
    wl-clipboard
    pavucontrol
    dracula-theme
    croc

    pciutils
  ];
}