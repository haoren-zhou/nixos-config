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

    anki-bin
    croc
    discord
    github-desktop
    obsidian
    xclip
    wl-clipboard

    gcc
    kdePackages.qttools
    nodejs_22
  ];
}
