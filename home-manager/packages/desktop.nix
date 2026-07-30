{pkgs, ...}: {
  home.packages = with pkgs; [
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
