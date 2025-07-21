{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    bibata-cursors
    pavucontrol
    ulauncher

    pciutils
    wget

    croc
    discord
    github-desktop
    xclip
    wl-clipboard

    gcc
    nodejs_24
  ];
}
