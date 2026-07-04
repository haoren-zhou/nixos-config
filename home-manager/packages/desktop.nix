{pkgs, ...}: {
  home.packages = with pkgs; [
    bibata-cursors
    pavucontrol
    wl-clipboard
    xclip

    feh # image viewer

    anki-bin
    discord
    github-desktop
    obsidian
    telegram-desktop
    thunderbird
    zathura

    kdePackages.qttools
    kdePackages.qtwayland
  ];
}
