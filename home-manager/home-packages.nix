{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    bibata-cursors
    pavucontrol

    pciutils
    feh # image viewer
    fd
    fzf
    ripgrep
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
