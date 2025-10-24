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

      booktabs
      enumitem
      esdiff
      float
      lastpage
      marvosym
      mathtools
      mdwtools
      preprint
      titlesec
      xcolor
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
    pandoc
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
    jdk
    kdePackages.qttools
    kdePackages.qtwayland
    mytex
    nodejs_22
    ocamlPackages.odoc
    ocamlPackages.utop
    opam
    (python312.withPackages (p: with p; [uv]))
  ];
}
