{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    bibata-cursors
    pavucontrol

    pciutils
    wget

    croc
    discord
    github-desktop
    xclip
    wl-clipboard

    gcc
    kdePackages.qttools
    nodejs_24
  ];
}
