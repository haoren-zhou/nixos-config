{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    bibata-cursors

    github-desktop
    google-chrome
    discord
    gcc
    xclip
    wl-clipboard
    pavucontrol
    dracula-theme
    croc

    kitty

    pciutils
    # # WM stuff
    # libsForQt5.xwaylandvideobridge
    # libnotify
    # xdg-desktop-portal-gtk
    # xdg-desktop-portal-hyprland
  ];
}