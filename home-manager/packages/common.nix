{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  mytex = pkgs.texlive.withPackages (ps:
    with ps; [
      scheme-full
      latexmk

      # fonts
      fira
      fontawesome5
      noto

      # font deps
      xkeyval
      fontaxes

      booktabs
      circuitikz
      enumitem
      esdiff
      float
      karnaugh
      lastpage
      marvosym
      mathtools
      mdwtools
      preprint
      preview
      standalone
      titlesec
      varwidth
      xcolor
    ]);
in {
  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    # CLI utils
    croc
    fastfetch
    fd
    file
    fzf
    pandoc
    pciutils
    ripgrep
    unzip
    wget
    zip

    # dev toolchains
    gcc
    gnumake
    jdk
    mytex
    nodejs_22
    ocamlPackages.odoc
    ocamlPackages.utop
    opam
    (python312.withPackages (p: with p; [uv]))

    zathura

    llm-agents.claude-code
    llm-agents.codex
    llm-agents.antigravity-cli
  ];
}
