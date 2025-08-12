{pkgs, ...}: let
  mytex = pkgs.texlive.withPackages (ps:
    with ps; [
      scheme-basic
      latexmk

      # fonts
      fira
      fontawesome5
      noto

      # font deps
      xkeyval
      fontaxes

      enumitem
      marvosym
      mathtools
      preprint
      titlesec
    ]);
in {
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    bibata-cursors
    pavucontrol

    fastfetch
    feh # image viewer
    fd
    fzf
    pciutils
    ripgrep
    wget
    wl-clipboard
    xclip

    anki-bin
    croc
    discord
    github-desktop
    obsidian
    zathura

    gcc
    gnumake
    kdePackages.qttools
    kdePackages.qtwayland
    mytex
    nodejs_22
  ];
}
