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
      esdiff
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
    wl-clipboard
    xclip

    # CLI utils
    fastfetch
    fd
    feh # image viewer
    file
    fzf
    pciutils
    ripgrep
    unzip
    wget
    zip

    anki-bin
    croc
    discord
    github-desktop
    obsidian
    telegram-desktop
    zathura

    gcc
    gnumake
    kdePackages.qttools
    kdePackages.qtwayland
    mytex
    nodejs_22
    (python312.withPackages (p: with p; [uv]))
  ];
}
