{pkgs, ...}: {
  home.packages = with pkgs; [
    bibata-cursors
    pavucontrol
    wl-clipboard
    xclip

    feh # image viewer
    file-roller

    anki-bin
    discord
    github-desktop
    obsidian
    telegram-desktop
    thunderbird

    kdePackages.qttools
    kdePackages.qtwayland
  ];
}
