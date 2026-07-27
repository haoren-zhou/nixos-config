{pkgs, ...}: {
  home.packages = with pkgs; [
    bibata-cursors
    pavucontrol
    wl-clipboard
    xclip

    file-roller

    anki-bin
    discord
    github-desktop
    obsidian
    telegram-desktop

    kdePackages.qttools
    kdePackages.qtwayland
  ];
}
