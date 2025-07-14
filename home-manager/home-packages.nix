{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    github-desktop
    google-chrome
    discord
    gcc
    xclip
    wl-clipboard
    pavucontrol
    dracula-theme
    croc

    # # WM stuff
    # libsForQt5.xwaylandvideobridge
    # libnotify
    # xdg-desktop-portal-gtk
    # xdg-desktop-portal-hyprland
  ];
}